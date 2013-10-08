require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Rbkmoney
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(
            eshopId
            paymentId
            orderId
            eshopAccount
            serviceName
            recipientAmount
            recipientCurrency
            paymentStatus
            userName
            userEmail
            paymentData
            secretKey
            hash
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          def complete?
            (payment_status == '5')
          end

          def test?
            false
          end

          def status
            case payment_status
            when '3'
              'pending'
            when '5'
              'completed'
            else 'unknown'
            end
          end

          def user_fields
            params.inject({}) do |fields, (k,v)|
              if /\AuserField_[\d+]\z/.match(k)
                fields[k] = v
              end
              fields
            end
          end

          alias_method :client_id, :eshop_id
          alias_method :item_id, :order_id
          alias_method :transaction_id, :payment_id
          alias_method :received_at, :payment_data
          alias_method :payer_email, :user_email
          alias_method :gross, :recipient_amount
          alias_method :currency, :recipient_currency

          def acknowledge(authcode = nil)
            string = [
              eshop_id,
              order_id,
              service_name,
              eshop_account,
              recipient_amount,
              recipient_currency,
              payment_status,
              user_name,
              user_email,
              payment_data,
              @options[:secret]
            ].join '::'

            signature = case hash.to_s.length
            when 32
              Digest::MD5.hexdigest(string)
            when 128
              Digest::SHA512.hexdigest(string)
            else
              return false
            end

            signature == hash
          end
        end
      end
    end
  end
end
