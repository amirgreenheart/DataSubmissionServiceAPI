module Export
  class Invoices
    class Row < Export::CsvRow
      alias_method :invoice, :model

      def row_values
        [
          invoice.submission_id,
          customer_urn,
          customer_name,
          customer_postcode,
          invoice_date,
          invoice_number,
          supplier_reference_number,
          customer_reference_number,
          lot_number
        ]
      end

      def customer_urn
        value_for('CustomerURN')
      end

      def customer_name
        value_for('CustomerName')
      end

      def customer_postcode
        value_for('CustomerPostCode')
      end

      def invoice_date
        value_for('InvoiceDate')
      end

      def invoice_number
        value_for('InvoiceNumber')
      end

      def supplier_reference_number
        value_for('SupplierReferenceNumber')
      end

      def customer_reference_number
        nil
      end

      def lot_number
        value_for('LotNumber')
      end

      private

      def value_for(destination_field, default: NOT_IN_DATA)
        source_field = Export::Template.source_field_for(
          destination_field,
          invoice._framework_short_name
        )
        invoice.data.fetch(source_field, default)
      end
    end
  end
end
