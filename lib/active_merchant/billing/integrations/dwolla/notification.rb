require 'net/http'
require 'digest/sha1'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def initialize(data, options)
            if options[:credential3].nil?
              raise ArgumentError, "You need to provide the Application secret as the option :credential3 to verify that the notification originated from Dwolla"
            end
            super
          end

          def complete?
            status == "Completed"
          end

          def status
            params["Status"]
          end

          def transaction_id
            params['TransactionId']
          end

          def item_id
            params['OrderId']
          end

          def currency
            "USD"
          end

          def gross
            params['Amount']
          end

          def error
            params['Error']
          end

          # Was this a test transaction?
          def test?
            params['TestMode']
          end

          def acknowledge      
            true
          end
        
        private
          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            json_post = JSON.parse(post)

            # generate and check signature here before merging with params
            checkoutId = json_post['CheckoutId']
            amount = format("%05.2f", params['amount'])
            secret = @options[:credential3]
            notification_signature = json_post['Signature']
            expected_signature = Digest::SHA1.hexdigest(secret + ('%s&%.2f' % [checkoutId, amount]))

            if notification_signature != expected_signature
              raise StandardError, "Callback signature did not verify."
            end

            params.merge!(json_post)
          end
        end
      end
    end
  end
end
