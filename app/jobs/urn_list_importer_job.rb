require 'tempfile'
require 'csv'
require 'aws-sdk-s3'

class UrnListImporterJob < ApplicationJob
  class AlreadyImported < StandardError; end
  class InvalidFormat < StandardError; end

  REQUIRED_COLUMNS = ['URN', 'CustomerName', 'PostCode', 'Sector'].freeze

  discard_on ActiveJob::DeserializationError
  discard_on AlreadyImported

  discard_on InvalidFormat do |job, _error|
    job.arguments.first.update!(aasm_state: :failed)
  end

  retry_on Aws::S3::Errors::ServiceError

  def perform(urn_list)
    raise AlreadyImported unless urn_list.pending?

    downloader = AttachedFileDownloader.new(urn_list.excel_file)
    downloader.download!

    convert_to_csv(downloader.temp_file.path)

    customers = customers_from_csv

    soft_delete!(customers)
    upsert!(customers)

    urn_list.update!(aasm_state: :processed)

    downloader.temp_file.close
    downloader.temp_file.unlink
  end

  private

  def convert_to_csv(path)
    command = "in2csv --sheet=\"Customers\" --locale=en_GB --blanks --skipinitialspace #{path}"
    command += " | csvcut -c 'URN,CustomerName,PostCode,Sector'"
    command += " > \"#{csv_temp_file.path}\""

    result = Ingest::CommandRunner.new(command).run!
    raise InvalidFormat unless result.successful?
  end

  def csv_temp_file
    @csv_temp_file ||= Tempfile.new('customer')
  end

  def customers_from_csv
    customers = []

    CSV.foreach(csv_temp_file, headers: true) do |row|
      raise InvalidFormat unless (row.headers & REQUIRED_COLUMNS) == REQUIRED_COLUMNS

      customers << Customer.new(
        name: row['CustomerName'],
        urn: row['URN'].to_i,
        postcode: row['PostCode'],
        sector: (row['Sector'] == 'Central Government' ? :central_government : :wider_public_sector),
        deleted: false
      )
    end

    csv_temp_file.close
    csv_temp_file.unlink

    customers
  end

  def upsert!(customers)
    Customer.transaction do
      Customer.import(
        customers,
        batch_size: 100,
        on_duplicate_key_update: {
          conflict_target: [:urn],
          columns: %i[name postcode sector deleted]
        }
      )
    end
  end

  def soft_delete!(customers)
    existing_urns = Customer.pluck(:urn)
    importing_urns = customers.map(&:urn)

    urns_to_be_deleted = existing_urns - importing_urns

    Customer.where(urn: urns_to_be_deleted).update(deleted: true)
  end
end
