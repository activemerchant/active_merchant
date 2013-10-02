require 'net/http'
require 'digest/sha1'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          def initialize(data, options)
            super
          end

          def complete?
            (status == "Completed")
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

          def test?
            params['TestMode'] != "false"
          end

          def acknowledge(authcode = nil)
            true
          end
        
        private

          def parse(post)
            @raw = post.to_s
            json_post = JSON.parse(post)
            verify_signature(json_post['CheckoutId'], json_post['Amount'], json_post['Signature'], @options[:credential3])

            params.merge!(json_post)
          end
        end
      end
    end
  end
end
