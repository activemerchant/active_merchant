module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module RemoteTestHelper

        private

        def credit_card_mpi_params
          {
            payment_cryptogram: 'AAACA1BHADYJkIASQkcAAAAAAAA=',
            eci:                '05',
            transaction_id:     '0pv62FIrT5qQODB7DCewKgEBAQI='
          }
        end

        def add_credit_card_options
          @visa_options = {
            first_name: 'Active',
            last_name:  'Merchant'
          }

          @mastercard_options = @visa_options.merge(brand: 'mastercard')
        end

        def add_credit_cards(card_brand = nil)
          add_credit_card_options

          add_default_credit_cards    unless card_brand
          add_visa_credit_cards       if card_brand == :visa
          add_mastercard_credit_cards if card_brand == :mastercard
        end

        def add_default_credit_cards
          add_visa_credit_cards
          add_mastercard_credit_cards
        end

        def add_visa_credit_cards
          @approved_visa = credit_card('4200000000000000', @visa_options)
          @declined_visa = credit_card('4111111111111111', @visa_options)
        end

        def add_mastercard_credit_cards
          @mastercard          = credit_card('5555555555554444', @mastercard_options)
          @declined_mastercard = credit_card('5105105105105100', @mastercard_options)
        end

        def add_3d_credit_cards
          add_credit_card_options

          @visa_3d_enrolled               = build_credit_card_with_mpi('4711100000000000')
          @visa_3d_enrolled_fail_auth     = build_credit_card_with_mpi('4012001037461114')
          @visa_3d_not_participating      = build_credit_card_with_mpi('4012001036853337')
          @visa_3d_error_first_step_auth  = build_credit_card_with_mpi('4012001037484447')
          @visa_3d_error_second_step_auth = build_credit_card_with_mpi('4012001036273338')
        end

        def build_credit_card_with_mpi(number)
          card_options = @visa_options.merge(credit_card_mpi_params)

          network_tokenization_credit_card(number, card_options)
        end

        def generate_order_amount
          rand(100..200)
        end

        def build_base_order_details
          {
            order_id:        generate_unique_id,
            ip:              '127.0.0.1',
            customer:        'Active Merchant',
            invoice:         generate_unique_id,
            merchant:        'Merchant Name',
            description:     'Test Active Merchant Purchase',
            email:           'active.merchant@example.com',
            currency:        'USD'
          }
        end

        def build_order_address_details
          {
            name:     'Travis Pastrana',
            phone:    '+1987987987988',
            address1: 'Muster Str. 14',
            address2: '',
            city:     'Los Angeles',
            state:    'CA',
            country:  'US',
            zip:      '10178'
          }
        end
      end
    end
  end
end
