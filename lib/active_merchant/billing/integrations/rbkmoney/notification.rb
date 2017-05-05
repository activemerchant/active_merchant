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
            language
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
            when '4'
              'canceled'
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

          alias_method :shop_id, :eshop_id
          alias_method :payment_id, :order_id
          alias_method :operation, :service_name
          alias_method :shop_wallet, :eshop_account
          alias_method :amount, :recipient_amount
          alias_method :currency, :recipient_currency
          alias_method :operation_status, :payment_status
          alias_method :payer_name, :user_name
          alias_method :payer_email, :user_email
          alias_method :received_at, :payment_data

          def acknowledge(authcode = nil)
            string = [
              shop_id,
              payment_id,
              operation,
              shop_wallet,
              amount,
              currency,
              operation_status,
              payer_name,
              payer_email,
              received_at,
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

            signature == hash && status == 'completed'
          end
        end
      end
    end
  end
end
