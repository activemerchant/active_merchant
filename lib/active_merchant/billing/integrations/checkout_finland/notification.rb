require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CheckoutFinland
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          # Payment can be market complete with the following status codes
          def complete?
            ["2", "5", "6", "8", "9", "10"].include? params["STATUS"]
          end

          # Did the customer choose delayed payment method
          def delayed?
            params['STATUS'] == "3"
          end

          # Did the customer cancel the payment
          def cancelled?
            params['STATUS'] == "-1"
          end

          # Payment requires manual activation (fraud check etc)
          def activation?
            params['STATUS'] == "7"
          end

          # Reference specified by the client when sending payment
          def reference
            params['REFERENCE']
          end

          # Unique ID assigned by Checkout
          def transaction_id
            params['PAYMENT']
          end

          # Unique ID assigned by customer
          def stamp
            params['STAMP']
          end

          # Returned Message Authentication Code
          def mac
            params['MAC']
          end

          def status
            params['STATUS']
          end

          # Verify authenticity of returned data
          def acknowledge(authcode = nil)
            return_authcode = [params["VERSION"], params["STAMP"], params["REFERENCE"], params["PAYMENT"], params["STATUS"], params["ALGORITHM"]].join("&")
            OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha256'), authcode, return_authcode).upcase == params["MAC"]
          end

          private
          # Take the posted data and move the data into params
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
