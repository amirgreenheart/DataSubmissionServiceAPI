require 'csv'

class Task
  # Used to generate CSV for all users that are expected to have
  # monthly tasks in the given year/month period. The CSV is
  # expected to be fed into GOV.UK Notify so emails can be
  # scheduled to go out the day the tasks are generated.
  #
  # Outputs via +puts+ objects that respond_to? it (+STDOUT+ or
  # +File+ being usual)
  class AnticipatedUserNotificationList
    HEADER = ['email address', 'due_date', 'person_name', 'supplier_name', 'reporting_month'].freeze

    attr_reader :logger, :output, :month, :year

    def initialize(month:, year:, output: STDOUT, logger: Rails.logger)
      @month = month
      @year = year
      @output = output
      @logger = logger
    end

    delegate :info, :warn, to: :logger

    def generate
      logger.info "Generating late contacts for #{year}, #{month}"

      output.puts(CSV.generate_line(header))

      suppliers.find_each do |supplier|
        next if supplier.active_frameworks.empty?

        supplier.active_users.each do |user|
          output.puts csv_line_for(user, supplier)
        end
      end
    end

    def csv_line_for(user, supplier)
      CSV.generate_line(
        [user.email, due_date, user.name, supplier.name, reporting_month] + framework_csv_columns_for(supplier)
      )
    end

    private

    def header
      HEADER + frameworks_header
    end

    def reporting_month
      @reporting_month ||= [Date::MONTHNAMES[month], year].join(' ')
    end

    def due_date
      @due_date ||= SubmissionWindow.new(year, month).due_date.to_s(:day_month_year)
    end

    def frameworks
      @frameworks ||= Framework.order(:short_name)
    end

    def frameworks_header
      Array.new(framework_column_count, 'framework')
    end

    def framework_column_count
      @framework_column_count ||= suppliers.map { |supplier| supplier.active_frameworks.ids.uniq.size }.max || 0
    end

    def framework_csv_columns_for(supplier)
      framework_names = supplier.active_frameworks
                                .map { |framework| "#{framework.short_name} - #{framework.name}" }
                                .sort

      framework_names.fill(nil, framework_names.size...framework_column_count)
    end

    def suppliers
      Supplier.includes(:active_users, :active_frameworks)
    end
  end
end
