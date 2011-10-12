require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        class Notification < ActiveMerchant::Billing::Integrations::Notification
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
            params['Message']
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
            params.merge!(json_post)
          end
        end
      end
    end
  end
end
