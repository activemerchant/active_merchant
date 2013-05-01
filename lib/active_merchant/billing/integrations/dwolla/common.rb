module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        module Common
          def verify_signature(checkoutId, amount, notification_signature)
            if options[:credential2].nil?
              raise ArgumentError, "You need to provide the Application secret as the option :credential2 to verify that the notification originated from Dwolla"
            end

            secret = options[:credential2]
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
