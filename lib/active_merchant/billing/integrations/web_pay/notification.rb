module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WebPay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          def self.recognizes?(params)
            params.has_key?('site_order_id') && params.has_key?('amount')
          end

          def complete?
            true
          end

          def amount
            BigDecimal.new(gross)
          end

          def item_id
            params['site_order_id']
          end

          def security_key
            params[ActiveMerchant::Billing::Integrations::WebPay.signature_parameter_name]
          end

          def gross
            params['amount']
          end

          def status
            'success'
          end

          def secret
            @options[:secret]
          end

          def acknowledge(authcode = nil)
            (security_key == generate_signature(:notify))
          end

          def success_response(*args)
            {:nothing => true}
          end
        end
      end
    end
  end
end
