class Framework
  module Definition
    module AST
      # This transform exists for the express purpose of creating an AST for generating
      # an ActiveModel class with validations for a Framework
      class Creator < Parslet::Transform
        rule(string: simple(:s)) { String(s) }
        rule(decimal: simple(:d)) { BigDecimal(d) }
        rule(field: simple(:field), from: simple(:from)) { { field: field.to_s, from: from.to_s } } # match known fields only
        rule(type: simple(:type), field: simple(:field), from: subtree(:from)) { { type: type.to_s, field: field.to_s, from: from } }
      end
    end
  end
end
