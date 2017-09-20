require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Fatpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(
            data
            sign
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :encoded_params, :data
          alias_method :signature, :sign

          def status
            case decoded_params['status']
            when '0'
              'pending'
            when '99'
              'failed'
            when '3'
              'completed'
            else 'unknown'
            end
          end

          def decoded_params
            JSON.parse(Base64.decode64(encoded_params))
          end

          def payment_id
            decoded_params['reference'].to_i
          end

          def amount
            decoded_params['amount'].to_f
          end

          def card_number
            decoded_params['card_number'].to_f
          end

          def pay_token
            decoded_params['pay_token']
          end

          def generate_signature
            OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('md5'), @options[:secret], encoded_params)
          end

          def acknowledge
            generate_signature.strip == signature.strip
          end

        end
      end
    end
  end
end
