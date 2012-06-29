module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module EasyPay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          def self.recognizes?(params)
            params.has_key?('order_mer_code') && params.has_key?('sum')
          end

          def complete?
            true
          end

          def amount
            BigDecimal.new(gross)
          end

          def item_id
            params['order_mer_code']
          end

          def security_key
            params[ActiveMerchant::Billing::Integrations::EasyPay.notify_signature_parameter_name]
          end

          def gross
            params['sum']
          end

          def status
            'success'
          end

          def secret
            @options[:secret]
          end

          def acknowledge
            security_key == generate_signature(:notify)
          end

          def success_response(*args)
            { :nothing => true }
          end
        end
      end
    end
  end
end
