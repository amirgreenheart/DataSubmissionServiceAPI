module Export
  class CsvRow
    MISSING = '#MISSING'.freeze # fields that are needed for MVP that we don't have yet

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def to_csv_line
      CSV.generate_line(row_values)
    end
  end
end
