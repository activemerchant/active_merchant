require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Verkkomaksut
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          # Is the payment complete or not. Verkkomaksut only has two statuses: random string or 0000000000 which means pending
          def complete?
            params['PAID'] != "0000000000"
          end 
          
          # Order id
          def order_id
            params['ORDER_NUMBER']
          end
          
          # Payment method used
          def method
            params['METHOD']
          end
          
          # When was this payment received by the client. 
          def received_at
            params['TIMESTAMP']
          end
          
          # Security key got from Verkkomaksut
          def security_key
            params['RETURN_AUTHCODE']
          end
          
          # Another way of asking the payment status
          def status
            if complete?
              "PAID"
            else
              "PENDING"
            end
          end
          
          # Acknowledges the payment. If the authcodes match, returns true.
          def acknowledge(authcode = nil)
            return_authcode = [params["ORDER_NUMBER"], params["TIMESTAMP"], params["PAID"], params["METHOD"], authcode].join("|")
            Digest::MD5.hexdigest(return_authcode).upcase == params["RETURN_AUTHCODE"]
          end
 private
 
          def parse(post)
            post.each do |key, value|
              params[key] = value
            end
          end
        end
      end
    end
  end
end
