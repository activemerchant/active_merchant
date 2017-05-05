require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Skrill
        class Notification < ActiveMerchant::Billing::Integrations::Notification
        
          %w(
            pay_to_email
            pay_from_email
            merchant_id
            customer_id
            transaction_id
            mb_amount
            mb_currency
            failed_reason_code
            md5sig
            sha2sig
            amount
            currency
            merchant_fields
            payment_type
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          # alias_method :new_one, :old_one

          def status
            case params['status'].to_i
              when 2 then 'completed'
              when 0 then 'pending'
              when -1 then 'canceled'
              when -2 then 'failed'
              when -3 then 'chargeback'      
              else 'unknown'
            end
          end

          def generate_signature
            secret_in_md5 = Digest::MD5.hexdigest(@options[:secret]).upcase
            string = [merchant_id, transaction_id, secret_in_md5, mb_amount, mb_currency, params['status']].join('')
            Digest::MD5.hexdigest(string).upcase
          end

          def acknowledge
            generate_signature == md5sig
          end

        end
      end
    end
  end
end