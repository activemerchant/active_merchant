module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Webmoney
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          def initialize(attrs, options = {})
            super
          end

          def recognizes?
            (params.has_key?('LMI_PAYMENT_NO') && params.has_key?('LMI_PAYMENT_AMOUNT'))
          end

          def key_present?
            params["LMI_HASH"].present?
          end

          def security_key
            params["LMI_HASH"]
          end

          def secret
            @options[:secret]
          end

          def acknowledge
            (security_key == generate_signature)
          end
        end
      end
    end
  end
end
