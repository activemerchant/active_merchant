module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Webmoney
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          def recognizes?
            (params.has_key?('LMI_PAYMENT_NO') && params.has_key?('LMI_PAYMENT_AMOUNT'))
          end

          def amount
            BigDecimal.new(gross)
          end

          def key_present?
            params["LMI_HASH"].present?
          end

          def item_id
            params['LMI_PAYMENT_NO']
          end

          def gross
            params['LMI_PAYMENT_AMOUNT']
          end

          def security_key
            params["LMI_HASH"]
          end

          def secret
            @options[:secret]
          end

          def acknowledge(authcode = nil)
            (security_key == generate_signature)
          end

          def success_response(*args)
            {:nothing => true}
          end
        end
      end
    end
  end
end
