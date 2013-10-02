module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Liqpay
        class Return < ActiveMerchant::Billing::Integrations::Return
          def self.recognizes?(params)
            params.has_key?('amount') && params.has_key?('order_id')
          end

          def initialize(post)
            super
            xml = Base64.decode64(@params["operation_xml"])
            @params.merge!(Hash.from_xml(xml)["response"])
          end

          def complete?
            status == 'success'
          end

          def account
            params['merchant_id']
          end

          def amount
            BigDecimal.new(gross)
          end

          def item_id
            params['order_id']
          end

          def transaction_id
            params['transaction_id']
          end

          def action_name
            params['action_name'] # either 'result_url' or 'server_url'
          end

          def version
            params['version']
          end

          def sender_phone
            params['sender_phone']
          end

          def security_key
            params[ActiveMerchant::Billing::Integrations::Liqpay.signature_parameter_name]
          end

          def gross
            params['amount']
          end

          def currency
            params['currency']
          end

          def status
            params['status'] # 'success', 'failure' or 'wait_secure'
          end

          def code
            params['code']
          end

          def generate_signature_string
            ['', version, @options[:secret], action_name, sender_phone, account, gross, currency, item_id, transaction_id, status, code, ''].flatten.compact.join('|')
          end

          def generate_signature
            Base64.encode64(Digest::SHA1.digest(generate_signature_string)).gsub(/\n/, '')
          end

          def acknowledge(authcode = nil)
            security_key == generate_signature
          end
        end
      end
    end
  end
end
