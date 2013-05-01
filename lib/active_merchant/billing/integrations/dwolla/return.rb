# Dwolla ActiveMerchant Integration
# http://www.dwolla.com/
# Authors: Michael Schonfeld <michael@dwolla.com>, Gordon Zheng <gordon@dwolla.com>
# Date: May 1, 2013

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        class Return < ActiveMerchant::Billing::Integrations::Return

          def initialize(data, options)
            if options[:credential3].nil?
              raise ArgumentError, "You need to provide the Application secret as the option :credential3 to verify that the redirect originated from Dwolla"
            end
            
            params  = parse(data)

            # verify signature
            checkoutId = params['checkoutId']
            amount = params['amount']
            secret = options[:credential3]
            notification_signature = params['signature']
            expected_signature = Digest::SHA1.hexdigest(secret + ('%s&%.2f' % [checkoutId, amount]))

            if notification_signature != expected_signature
              raise StandardError, "Callback signature did not verify."
            end

            super
          end

          def success?
            self.error.nil? && self.callback_success?
          end

          def error
            params['error']
          end

          def error_description
            params['error_description']
          end

          def checkout_id
            params['checkoutId']
          end

          def transaction
            params['transaction']
          end

          def test?
            params['test']
          end

          def callback_success?
            params['postback'] != "failure"
          end
	      end
      end
    end
  end
end
