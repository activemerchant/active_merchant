module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        module Common
          def verify_signature(checkoutId, amount, notification_signature)
            secret = options[:credential3]
            expected_signature = Digest::SHA1.hexdigest(secret + ('%s&%.2f' % [checkoutId, amount]))

            if notification_signature != expected_signature
              raise StandardError, "Dwolla signature verification failed."
            end
          end
        end
      end
    end
  end
end
