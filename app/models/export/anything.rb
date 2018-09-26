module Export
  class Anything
    attr_reader :output_name

    def initialize(relation, output_name = :tmp)
      @relation = relation
      @output_name = (output_name || :tmp).to_sym
    end

    def run
      output_io do |output|
        export_class.new(@relation, output).run
      end
    rescue Errno::EPIPE
      # allow piping to, for example ` | head -n1` without an unexpected stack trace
      true
    end

    private

    def model_classname
      if @relation.klass == SubmissionEntry && @relation.any? && @relation.first.is_a?(SubmissionEntry)
        'Invoice'
      else
        @relation.klass.to_s
      end
    end

    def export_class
      "Export::#{model_classname.to_s.pluralize}".constantize
    end

    def model_plural
      model_classname.to_s.downcase.pluralize
    end

    def output_io
      case output_name
      when :tmp
        STDERR.puts("Exporting #{model_plural} to #{filename}")
        File.open(filename, 'w+') do |file|
          yield file
        end
      when :stdout
        yield STDOUT
      else
        STDERR.puts usage
      end
    end

    def filename
      "/tmp/#{model_plural}_#{Time.zone.today}.csv"
    end

    def usage
      "'#{output_name}' output type not understood. I can output to tmp, stdout"
    end
  end
end
