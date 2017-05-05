module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Robokassa
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          def self.recognizes?(params)
            params.has_key?('InvId') && params.has_key?('OutSum')
          end

          def complete?
            true
          end

          def amount
            BigDecimal.new(gross)
          end

          def item_id
            params['InvId']
          end

          def security_key
            params[ActiveMerchant::Billing::Integrations::Robokassa.signature_parameter_name].to_s.downcase
          end

          def gross
            params['OutSum']
          end

          def status
            'success'
          end

          def secret
            @options[:secret]
          end

          def main_params
            [gross, item_id]
          end

          def acknowledge(authcode = nil)
            security_key == generate_signature
          end

          def success_response(*args)
            "OK#{item_id}"
          end
        end
      end
    end
  end
end
