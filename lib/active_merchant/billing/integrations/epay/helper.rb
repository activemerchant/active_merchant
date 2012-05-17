module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Epay
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, merchantnumber, options = {})
            super
						add_field('windowstate', 3)
            add_field('language', '0')
            add_field('orderid', format_order_number(order))
						@fields = Hash[@fields.sort]
          end
              
          def md5secret(value)
            @md5secret = value
          end
          
          def form_fields
            @fields.merge('hash' => generate_md5hash)
          end
            
          def generate_md5string
						@fields.sort.each.map { |key, value| key != 'hash' ? value.to_s : ''} * "" + @md5secret
          end
          
          def generate_md5hash
            Digest::MD5.hexdigest(generate_md5string)
          end

          # Limited to 20 digits max
          def format_order_number(number)
            number.to_s.gsub(/[^\w_]/, '').rjust(4, "0")[0...20]
          end

          mapping :account, 'merchantnumber'
          mapping :language, 'language'
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          mapping :return_url, 'accepturl'
          mapping :cancel_return_url, 'cancelurl'
          mapping :notify_url, 'callbackurl'
					mapping :autocapture, 'instantcapture'
          mapping :description, 'description'
					mapping :credential3, 'md5secret'
          mapping :customer, ''
          mapping :billing_address, {}
          mapping :tax, ''
          mapping :shipping, ''
        
				end
      end
    end
  end
end
