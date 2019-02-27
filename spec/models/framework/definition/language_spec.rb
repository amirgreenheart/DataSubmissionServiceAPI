require 'rails_helper'

RSpec.describe Framework::Definition::Language do
  describe '.generate_framework_definition' do
    let(:logger)         { spy('Logger') }
    subject(:definition) { Framework::Definition::Language.generate_framework_definition(source, logger) }

    context 'we have some valid FDL' do
      let(:source) do
        <<~FDL.strip
          Framework CM/05/3769 {
            Name 'Laundry Services - Wave 2'
            ManagementCharge 0.0%

            InvoiceFields {
              TotalValue from 'Total Spend'
              CustomerPostCode from 'Customer Postcode'
              CustomerName from 'Customer Organisation'
              CustomerURN from 'Customer URN'
            }
          }
        FDL
      end

      it 'is a Framework::Definition::Base' do
        expect(definition).to be < Framework::Definition::Base
      end

      it 'has the expected framework_short_name' do
        expect(definition.framework_short_name).to eq('CM/05/3769')
      end

      it 'has the expected framework name' do
        expect(definition.framework_name).to eq('Laundry Services - Wave 2')
      end

      it 'has the expected management charge percentage' do
        expect(definition.management_charge.percentage).to eq(BigDecimal(0))
      end

      describe 'the Invoice fields class' do
        subject(:invoice_class) { definition::Invoice }

        it 'is a Framework::EntryData' do
          expect(invoice_class).to be < Framework::EntryData
        end

        describe 'Total Value – a known numeric field' do
          it 'tells the class where the total_value_field is' do
            expect(invoice_class.total_value_field).to eql('Total Spend')
          end

          it 'knows where the data is coming from in the spreadsheet' do
            expect(invoice_class.export_mappings['TotalValue']).to eq('Total Spend')
          end

          it 'validates numericality and presence' do
            expect(invoice_class).to have_field('Total Spend').validated_by(:presence, :ingested_numericality)
          end

          it 'is a string at present but should be a decimal when' \
             'IngestedNumericalityValidator is removed' do
            expect(invoice_class.attribute_types['Total Spend']).to be_kind_of(
              ActiveModel::Type::String
            )
          end
        end

        describe 'Customer Postcode – a known string field' do
          it 'knows where it’s coming from/going to in the data warehouse' do
            expect(invoice_class.export_mappings['CustomerPostCode']).to eq('Customer Postcode')
          end

          it 'is assumed present but not numeric' do
            expect(invoice_class).to have_field('Customer Postcode')
              .validated_by(:presence)
              .not_validated_by(:ingested_numericality)
          end
        end

        describe 'Customer Name - a known string field' do
          it 'knows where it’s coming from/going to in the data warehouse' do
            expect(invoice_class.export_mappings['CustomerName']).to eq('Customer Organisation')
          end

          it 'is assumed present but not numeric' do
            expect(invoice_class).to have_field('Customer Organisation')
              .validated_by(:presence)
              .not_validated_by(:ingested_numericality)
          end
        end

        describe 'CustomerURN - a known field with a custom validator' do
          it 'knows where it’s coming from/going to in the data warehouse' do
            expect(invoice_class.export_mappings['CustomerURN']).to eq('Customer URN')
          end

          it 'is assumed to be present and a valid URN' do
            expect(invoice_class).to have_field('Customer URN')
              .validated_by(:presence, :urn)
          end
        end
      end
    end

    context 'our FDL isn\'t valid' do
      let(:source) { 'any old rubbish' }

      it 'logs the error and re-raises' do
        expect { definition }.to raise_error(Parslet::ParseFailed)
        expect(logger).to have_received(:error).with(/Expected "Framework"/)
      end
    end
  end
end
