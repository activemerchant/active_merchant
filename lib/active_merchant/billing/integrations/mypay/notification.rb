require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Mypay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(
            id
            orderId
            account
            clientID
            currency
            date
            error
            errorMessage
            parameters
            paymentType
            price
            revenue
            serviceID
            status
            timestamp
            unitName
            hash
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :amount, :price

          def acknowledge(authcode = nil)
            string = [
              account,
              client_id,
              currency,
              date,
              id,
              order_id,
              error,
              error_message,
              parameters,
              payment_type,
              price,
              revenue,
              service_id,
              status,
              timestamp,
              unit_name,
              @options[:secret]
            ].join('')
            signature = Digest::SHA1.hexdigest(string)
            signature.upcase == hash.upcase
          end

        end
      end
    end
  end
end