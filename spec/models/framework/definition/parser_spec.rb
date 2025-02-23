require 'rails_helper'

##
# These specs are for Parslet atoms and therefore will be matching the CST,
# not the AST (which is the result of passing the CST through AST::Creator)

RSpec.describe Framework::Definition::Parser do
  subject(:parser) { Framework::Definition::Parser.new }
  let(:framework_definition) do
    <<~FDL
      Framework CM/05/3769 {
        Name 'Laundry Services - Wave 2'
        ManagementCharge 0%

        Lots {
          '1' -> 'Laundry Services'
        }

        InvoiceFields {
          CustomerPostCode from 'Customer Postcode'

          String Additional1 from 'Manufacturers Product Code'
        }
      }
    FDL
  end

  describe '#framework_definition' do
    let(:array) do
      [
        { framework_short_name: { string: 'CM/05/3769' } },
        {
          framework_name: { string: 'Laundry Services - Wave 2' },
          management_charge: { flat_rate: { value: { integer: '0' } } },
          lots: { dictionary: [{ key: { string: '1' }, value: { string: 'Laundry Services' } }] }
        },
        {
          invoice_fields: [
            { field: 'CustomerPostCode', from: { string: 'Customer Postcode' } },
            { type_def: { primitive: 'String' }, field: 'Additional1', from: { string: 'Manufacturers Product Code' } }
          ]
        }
      ]
    end

    let(:hash) do
      {
        framework_short_name: { string: 'CM/05/3769' },
        framework_name: { string: 'Laundry Services - Wave 2' },
        management_charge: { flat_rate: { percentage: { integer: '0' } } },
        lots: { dictionary: [{ key: { string: '1' }, value: { string: 'Laundry Services' } }] },
        invoice_fields: [
          { field: 'CustomerPostCode', from: { string: 'Customer Postcode' } },
          { type_def: { primitive: 'String' }, field: 'Additional1', from: { string: 'Manufacturers Product Code' } }
        ]
      }
    end
    it { is_expected.to parse(framework_definition, trace: true).as(hash) }
  end

  describe '#framework_identifier' do
    subject { parser.framework_identifier }

    it { is_expected.to parse('CM/OSG/05/3565').as(string: 'CM/OSG/05/3565') }
    it { is_expected.to parse('RM3710').as(string: 'RM3710') }
  end

  describe '#framework_name' do
    subject { parser.framework_name }

    it {
      is_expected.to parse("Name 'Laundry Services - Wave 2'").as(
        framework_name: { string: 'Laundry Services - Wave 2' }
      )
    }
  end

  describe '#percentage_exp' do
    subject { parser.percentage_exp }

    it { is_expected.to parse('0%').as(percentage: { integer: '0' }) }
    it { is_expected.to parse('0.0%').as(percentage: { decimal: '0.0' }) }
    it {
      is_expected.to parse("0.0% of 'Other Field'").as(
        percentage:  { decimal: '0.0' },
        column: { string: 'Other Field' }
      )
    }
  end

  describe '#range' do
    subject { parser.range }

    it { is_expected.to parse('5').as(range: { is: { integer: '5' } }) }
    it { is_expected.to parse('1..5').as(range: { min: { integer: '1' }, max: { integer: '5' } }) }
    it { is_expected.to parse('..5').as(range: { min: { integer: [] }, max: { integer: '5' } }) }
    it { is_expected.to parse('1..').as(range: { min: { integer: '1' }, max: { integer: [] } }) }
  end

  describe '#management_charge' do
    subject { parser.management_charge }

    context 'simple flat rate' do
      it {
        is_expected.to parse('ManagementCharge 0.0%').as(
          management_charge: { flat_rate: { percentage: { decimal: '0.0' } } }
        )
      }
    end

    context 'flat rate from a named column' do
      it {
        is_expected.to parse("ManagementCharge 0.0% of 'Supplier Price'").as(
          management_charge: {
            flat_rate: {
              percentage: { decimal: '0.0' },
              column: { string: 'Supplier Price' }
            }
          }
        )
      }
    end

    context 'column based' do
      context 'with one column' do
        let(:source) do
          <<~FDL.strip
            ManagementCharge varies_by 'Spend Code' {
              'Lease Rental' -> 0.5%
              'Damage'       -> 0%
             }
          FDL
        end

        it {
          is_expected.to parse(source).as(
            management_charge: {
              column_based: {
                column_names: {
                  string: 'Spend Code'
                },
                value_to_percentage: {
                  dictionary: [
                    { key: { string: 'Lease Rental' }, value: { percentage: { decimal: '0.5' } } },
                    { key: { string: 'Damage' }, value: { percentage: { integer: '0' } } }
                  ]
                }
              }
            }
          )
        }
      end

      context 'with two columns and a percentage expressed in terms of another column' do
        let(:source) do
          <<~FDL.strip
            ManagementCharge varies_by 'Lot Number', 'Spend Code' {
              '1', 'Lease Rental' -> 0.5%
              '1', 'Damage' -> 0%
              '2', 'Lease Rental' -> 1.5% of 'Other Price'
            }
          FDL
        end

        it {
          is_expected.to parse(source).as(
            management_charge: {
              column_based: {
                column_names: [
                  { string: 'Lot Number' },
                  { string: 'Spend Code' }
                ],
                value_to_percentage: {
                  dictionary: [
                    {
                      key: [
                        { string: '1' },
                        { string: 'Lease Rental' }
                      ],
                      value: { percentage: { decimal: '0.5' } }
                    },
                    {
                      key: [
                        { string: '1' },
                        { string: 'Damage' }
                      ],
                      value: { percentage: { integer: '0' } }
                    },
                    {
                      key: [
                        { string: '2' },
                        { string: 'Lease Rental' }
                      ],
                      value: { percentage: { decimal: '1.5' }, column: { string: 'Other Price' } }
                    }
                  ]
                }
              }
            }
          )
        }

        context 'with wildcards' do
          let(:source) do
            <<~FDL.strip
              ManagementCharge varies_by 'Lot Number', 'Spend Code' {
                '1', * -> 0.5%
                '1', 'Lease Rental' -> 1.5%
                *, * -> 2%
              }
            FDL
          end

          it {
            is_expected.to parse(source).as(
              management_charge: {
                column_based: {
                  column_names: [
                    { string: 'Lot Number' },
                    { string: 'Spend Code' }
                  ],
                  value_to_percentage: {
                    dictionary: [
                      {
                        key: [
                          { string: '1' },
                          { any_operator: '*' }
                        ],
                        value: { percentage: { decimal: '0.5' } }
                      },
                      {
                        key: [
                          { string: '1' },
                          { string: 'Lease Rental' }
                        ],
                        value: { percentage: { decimal: '1.5' } }
                      },
                      {
                        key: [
                          { any_operator: '*' },
                          { any_operator: '*' }
                        ],
                        value: { percentage: { integer: '2' } }
                      }
                    ]
                  }
                }
              }
            )
          }
        end
      end
    end

    context 'sector_based' do
      let(:source) do
        <<~FDL.strip
          ManagementCharge sector_based  {
            CentralGovernment -> 0.5%
            WiderPublicSector -> 0.6%
           }
        FDL
      end

      it {
        is_expected.to parse(source).as(
          management_charge: {
            sector_based: {
              dictionary: [
                { key: 'CentralGovernment', value: { percentage: { decimal: '0.5' } } },
                { key: 'WiderPublicSector', value: { percentage: { decimal: '0.6' } } }
              ]
            }
          }
        )
      }
    end
  end

  describe '#type_def' do
    subject { parser.type_def }

    context 'a lookup type_def' do
      ##
      # Anything that isn't a primitive type_def is considered a lookup type_def
      it {
        is_expected.to parse('PromotionCode').as(
          type_def: { lookup: 'PromotionCode' }
        )
      }
    end

    context 'a date type_def' do
      it {
        is_expected.to parse('Date').as(
          type_def: { primitive: 'Date' }
        )
      }
    end

    context 'a String type_def' do
      context 'simple' do
        it { is_expected.to parse('String').as(type_def: { primitive: 'String' }) }
      end

      context 'with a range' do
        it {
          is_expected.to parse('String(1..5)').as(
            type_def: { primitive: 'String', range: { min: { integer: '1' }, max: { integer: '5' } } }
          )
        }
      end
    end
  end

  describe '#known_field' do
    subject { parser.known_field }

    context 'mandatory field' do
      it {
        is_expected.to parse("InvoiceValue from 'Total Spend'").as(
          field: 'InvoiceValue', from: { string: 'Total Spend' }
        )
      }
    end

    context 'optional field' do
      it {
        is_expected.to parse("optional ProductGroup from 'Service Type'").as(
          optional: 'optional', field: 'ProductGroup', from: { string: 'Service Type' }
        )
      }
    end

    context 'with dependencies' do
      let(:source) do
        <<~FDL
          ProductGroup from 'Vehicle Segment' depends_on 'Lot Number' {
            '1' -> Lot1Segment
            '2' -> Lot2Segment
          }
        FDL
      end
      it {
        is_expected.to parse(source).as(
          field: 'ProductGroup',
          from: { string: 'Vehicle Segment' },
          depends_on: {
            dependent_fields: { string: 'Lot Number' },
            values: {
              dictionary: [
                { key: { string: '1' }, value: { lookup_reference: 'Lot1Segment' } },
                { key: { string: '2' }, value: { lookup_reference: 'Lot2Segment' } }
              ]
            }
          }
        )
      }
    end

    context 'with multi-field dependencies' do
      let(:source) do
        <<~FDL
          ProductGroup from 'Vehicle Segment' depends_on 'Lot Number', 'Category', 'Model' {
            '1', 'Cars', 'Golf' -> Lot1Segment
          }
        FDL
      end
      it {
        is_expected.to parse(source).as(
          field: 'ProductGroup',
          from: { string: 'Vehicle Segment' },
          depends_on: {
            dependent_fields: [
              { string: 'Lot Number' },
              { string: 'Category' },
              { string: 'Model' },
            ],
            values: {
              dictionary: [
                {
                  key: [
                    { string: '1' },
                    { string: 'Cars' },
                    { string: 'Golf' },
                  ],
                  value: { lookup_reference: 'Lot1Segment' }
                },
              ]
            }
          }
        )
      }
    end
  end

  describe '#additional_field' do
    subject { parser.additional_field }

    context 'mandatory field' do
      it {
        is_expected.to parse("String Additional1 from 'Manufacturers Product Code'").as(
          type_def: { primitive: 'String' }, field: 'Additional1', from: { string: 'Manufacturers Product Code' }
        )
      }
    end

    context 'with dependencies' do
      let(:source) do
        <<~FDL
          String Additional1 from 'Somewhere' depends_on 'Something Else' {
            '1' -> SomeValues1
            '2' -> SomeValues2
          }
        FDL
      end

      it {
        is_expected.to parse(source).as(
          type_def: { primitive: 'String' },
          field: 'Additional1',
          from: { string: 'Somewhere' },
          depends_on: {
            dependent_fields: { string: 'Something Else' },
            values: {
              dictionary: [
                { key: { string: '1' }, value: { lookup_reference: 'SomeValues1' } },
                { key: { string: '2' }, value: { lookup_reference: 'SomeValues2' } }
              ]
            }
          }
        )
      }
    end

    context 'optional field' do
      it {
        is_expected.to parse("optional String Additional1 from 'Manufacturers Product Code'").as(
          optional: 'optional',
          type_def: { primitive: 'String' },
          field: 'Additional1',
          from: { string: 'Manufacturers Product Code' }
        )
      }
    end
  end

  describe '#unknown_field' do
    subject { parser.unknown_field }

    context 'mandatory field' do
      it {
        is_expected.to parse("String from 'Cost Centre'").as(
          type_def: { primitive: 'String' }, from: { string: 'Cost Centre' }
        )
      }
    end

    context 'optional field' do
      it {
        is_expected.to parse("optional String from 'Cost Centre'").as(
          optional: 'optional', type_def: { primitive: 'String' }, from: { string: 'Cost Centre' }
        )
      }
    end

    context 'field with String length' do
      it {
        is_expected.to parse("String(5) from 'Somewhere'", trace: true).as(
          type_def: { primitive: 'String', range: { is: { integer: '5' } } }, from: { string: 'Somewhere' }
        )
      }

      example { expect(parser.range).not_to parse('1..10   ') }
    end
  end

  describe '#invoice_fields' do
    subject(:rule) { parser.invoice_fields }

    let(:fields) do
      <<~FDL.strip
        InvoiceFields {
          String Additional1 from 'Manufacturers Product Code'
        }
      FDL
    end

    it 'has whatever fields are in the block' do
      expect(rule).to parse(fields).as(
        invoice_fields: [
          { type_def: { primitive: 'String' }, field: 'Additional1', from: { string: 'Manufacturers Product Code' } },
        ]
      )
    end
  end

  describe '#contract_fields' do
    subject(:rule) { parser.contract_fields }

    let(:fields) do
      <<~FDL.strip
        ContractFields {
          String Additional1 from 'Somewhere'
        }
      FDL
    end

    it 'has whatever fields are in the block' do
      expect(rule).to parse(fields).as(
        contract_fields: [
          { type_def: { primitive: 'String' }, field: 'Additional1', from: { string: 'Somewhere' } },
        ]
      )
    end
  end

  describe '#other_fields' do
    subject(:rule) { parser.other_fields }

    let(:fields) do
      <<~FDL.strip
        OtherFields {
          String Additional1 from 'Somewhere'
        }
      FDL
    end

    it 'has whatever fields are in the block' do
      expect(rule).to parse(fields).as(
        other_fields: [
          { type_def: { primitive: 'String' }, field: 'Additional1', from: { string: 'Somewhere' } },
        ]
      )
    end
  end

  describe '#fields_blocks' do
    subject(:rule) { parser.fields_blocks }

    context 'an InvoiceFields on its own' do
      let(:blocks) do
        <<~FDL.strip
          InvoiceFields {
            String Additional1 from 'Somewhere'
          }
        FDL
      end

      it { is_expected.to parse(blocks) }
    end

    context 'a ContractFields on its own' do
      let(:blocks) do
        <<~FDL.strip
          ContractFields {
            String Additional1 from 'Somewhere'
          }
        FDL
      end

      it { is_expected.to parse(blocks) }
    end

    context 'an OtherFields with one of the other blocks' do
      let(:blocks) do
        <<~FDL.strip
          InvoiceFields {
            String Additional1 from 'Somewhere'
          }

          OtherFields {
            String Additional1 from 'Somewhere'
          }
        FDL
      end

      it do
        is_expected.to parse(blocks).as(
          invoice_fields: [{ type_def: { primitive: 'String'  }, field: 'Additional1', from: { string: 'Somewhere' } }],
          other_fields: [{ type_def: { primitive: 'String' }, field: 'Additional1', from: { string: 'Somewhere' } }]
        )
      end
    end

    context 'an OtherFields on its own' do
      let(:blocks) do
        <<~FDL.strip
          OtherFields {
            String Additional1 from 'Somewhere'
          }
        FDL
      end

      it { is_expected.not_to parse(blocks) }
    end
  end

  describe '#lookups_block' do
    subject(:rule) { parser.lookups_block }

    let(:source) do
      <<~FDL.strip
        Lookups {
          PaymentProfile [
            'Monthly'
            'Quarterly'
          ]

          ServiceType [
            'Type1'
            'Type2'
          ]

          SomeRandomComposition [
            PaymentProfile
            ServiceType
            'Foo'
          ]
        }
      FDL
    end

    it 'parses the lookup fields' do
      expect(rule).to parse(source, trace: true).as(
        lookups: [
          {
            lookup_name: 'PaymentProfile',
            list: [
              { string: 'Monthly' },
              { string: 'Quarterly' }
            ]
          },
          {
            lookup_name: 'ServiceType',
            list: [
              { string: 'Type1' },
              { string: 'Type2' }
            ]
          },
          {
            lookup_name: 'SomeRandomComposition',
            list: [
              { lookup_reference: 'PaymentProfile' },
              { lookup_reference: 'ServiceType' },
              { string: 'Foo' },
            ]
          }
        ]
      )
    end
  end

  describe '#lots_block' do
    subject(:rule) { parser.lots_block }
    let(:source) do
      <<~FDL
        Lots {
          '1' -> 'Lot 1'
          '2a' -> 'Lot the second'
        }
      FDL
    end

    it {
      is_expected.to parse(source, trace: true).as(
        lots: {
          dictionary: [
            { key: { string: '1' }, value: { string: 'Lot 1' } },
            { key: { string: '2a' }, value: { string: 'Lot the second' } }
          ]
        }
      )
    }
  end
end
