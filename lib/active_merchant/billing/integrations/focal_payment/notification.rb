require 'net/http'
require 'digest/md5'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module FocalPayment
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(TransId
            TransRef
            Amount
            Currency
            Status
            Merchant
            TransRef
            Product
            AttemptMode
            Test
            TestTrans
            Site
            Key
            PaymentType
            ).each do |param_name|
              define_method(param_name.underscore){ params[param_name] }
            end

          alias_method :account, :merchant
          alias_method :order, :trans_ref

          def secret
            @options[:secret]
          end

          def email
            params['customer']['email']
          end

          def first_name
            params['customer']['first_name']
          end

          def last_name
            params['customer']['last_name']
          end

          def security_key
            params["Key"]
          end

          def item_id
            params['TransRef']
          end

          def status_to_string
            {
              '1' => 'Authed',
              '2' => 'Captured',
              '4' => 'Blocked',
              '5' => 'Cancelled',
              '6' => 'Voided',
              '7' => 'Returned',
              '8' => 'Chargeback',
              '9' => 'Represented',
              '13' => 'Refunded',
              '16' => 'Sale'
            }[status]
          end


          def acknowledge
            security_key == generate_signature && status_to_string == ('Sale' || 'Authed') && test == 'false'
          end

          def generate_signature_string
            string = [
                secret,
                trans_id,
                amount
              ].join
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string)
          end

        end
      end
    end
  end
end
