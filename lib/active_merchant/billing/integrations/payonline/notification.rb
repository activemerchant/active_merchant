require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Payonline
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(
            OrderId
            PaymentCurrency
            Country
            SecurityKey
            PaymentAmount
            DateTime
            TransactionID
            Amount
            SpecialConditions
            CardHolder
            CardNumber
            Currency
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :item_id, :order_id
          alias_method :received_at, :date_time

          def generate_signature_string
            string = %w(DateTime TransactionID OrderId Amount Currency).map {|k| "#{k}=#{params[k]}"}.join("&")
            string += "&PrivateSecurityKey=" + @options[:secret]
          end

          def generate_signature
            Digest::MD5::hexdigest(generate_signature_string).downcase
          end

          def acknowledge
            generate_signature == security_key
          end

        end
      end
    end
  end
end
