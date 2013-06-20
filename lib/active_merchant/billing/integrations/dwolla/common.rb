require "openssl"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        module Common
          def verify_signature(checkoutId, amount, notification_signature, secret)
            if secret.nil?
              raise ArgumentError, "You need to provide the Application secret as the option :credential3 to verify that the notification originated from Dwolla"
            end

            expected_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, secret, "%s&%.2f" % [checkoutId, amount])

            if notification_signature != expected_signature
              raise StandardError, "Dwolla signature verification failed."
            end
          end
        end
      end
    end
  end
end
