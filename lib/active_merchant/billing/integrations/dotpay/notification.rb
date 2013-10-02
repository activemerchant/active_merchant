require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dotpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == 'OK' && %w(2 4 5).include?(t_status)
          end

          def currency
            orginal_amount.split(' ')[1]
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['amount']
          end

          def pin=(value)
            @options[:pin] = value
          end

          def status
            params['status']
          end

          def test?
            params['t_id'].match('.*-TST\d+') ? true : false
          end

          PAYMENT_HOOK_FIELDS = [
            :id,
            :control,
            :t_id,
            :orginal_amount,
            :email,
            :service,
            :code,
            :username,
            :password,
            :t_status,
            :description,
            :md5,
            :p_info,
            :p_email,
            :t_date
          ]

          PAYMENT_HOOK_SIGNATURE_FIELDS = [
            :id,
            :control,
            :t_id,
            :amount,
            :email,
            :service,
            :code,
            :username,
            :password,
            :t_status
          ]

          # Provide access to raw fields
          PAYMENT_HOOK_FIELDS.each do |key|
            define_method(key.to_s) do
               params[key.to_s]
            end
          end

          def generate_signature_string
            "#{@options[:pin]}:" + PAYMENT_HOOK_SIGNATURE_FIELDS.map {|key| params[key.to_s]} * ":"
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string)
          end

          def acknowledge(authcode = nil)      
            generate_signature.to_s == md5.to_s
          end
        end
      end
    end
  end
end
