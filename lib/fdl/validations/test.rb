require 'progress_bar'
require 'stringio'
require 'fdl/validations/test/compare'

module FDL
  module Validations
    ##
    # Given a +framework_short_name+ and a +sample_row_count+, build a summary
    # of discrepancies when the test is +run+
    #
    # Example usage:
    #   test = FDL::Validations::Test.new('RM1234',10)
    #   test.run
    #   puts test.formatted_report
    class Test
      attr_reader :framework_short_name, :sample_row_count, :submission_ids

      def initialize(framework_short_name, options = { sample_row_count: 5000 })
        @framework_short_name = framework_short_name
        @sample_row_count     = options[:sample_row_count]
        @submission_ids       = options[:submission_ids]
      end

      def sample_rows
        @sample_rows ||= if submission_ids&.any?
                           by_submission_ids(submission_ids)
                         else
                           limited_by_number
                         end
      end

      def discrepancies
        @discrepancies ||= Hash.new { |h, k| h[k] = [] }
      end

      def run
        bar = ProgressBar.new(sample_rows.count)

        sample_rows.each do |entry|
          compare = Compare.new(entry, framework_short_name, fdl_definition)
          diff = compare.diff
          bar.increment!
          next if diff.empty?

          discrepancies[diff] << {
            submission_id: entry.submission.id,
            created_at: entry.submission.created_at,
            entry_id: entry.id
          }
        end
      end

      def fdl_definition
        @fdl_definition ||= Framework::Definition::Language[framework_short_name]
      end

      def formatted_report
        output = StringIO.new

        discrepancies.each_pair do |diff, entries|
          output.puts "#{diff} affects #{entries.count} entries"
          entries_by_submission = entries.group_by { |entry| "#{entry[:submission_id]}: #{entry[:created_at]}" }
          entries_by_submission.each_pair do |submission_header, entry_hashes|
            output.puts "\t#{submission_header} has #{entry_hashes.count} entries"
          end
        end

        output.string
      end

      private

      def framework_submissions
        SubmissionEntry
          .joins(submission: :framework)
          .where('frameworks.short_name = ?', [framework_short_name])
          .order(created_at: :desc)
      end

      def by_submission_ids(submission_ids)
        framework_submissions.where('submissions.id IN (?)', submission_ids)
      end

      def limited_by_number
        framework_submissions.limit(sample_row_count)
      end
    end
  end
end
