module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            super
            add_field('payType', 'N') # normal sale and not just auth
            @secret = options[:credential2]
          end

          def form_fields
            @fields.merge('secureHash' => generate_secure_hash)
          end

          def generate_secure_hash
            fields = [@fields[mappings[:account]],
                      @fields[mappings[:order]],
                      @fields[mappings[:currency]],
                      @fields[mappings[:amount]],
                      @fields['payType']]
            Paydollar.sign(fields, @secret)
          end

          def currency=(currency_code)
            code = CURRENCY_MAP[currency_code]
            raise StandardError, "Invalid currency code #{currency_code} specified" if code.nil?
            add_field(mappings[:currency], code)
          end

          mapping :account, 'merchantId'
          mapping :amount, 'amount'
          mapping :order, 'orderRef'
          mapping :currency, 'currCode'
          mapping :return_url, ['successUrl','failUrl']
          mapping :cancel_return_url, 'cancelUrl'

        end
      end
    end
  end
end
