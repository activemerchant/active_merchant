require 'base64'
require 'stringio'
require 'zlib'
require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Adyen
        class Return < ActiveMerchant::Billing::Integrations::Return

          # for verifying the signature of the URL parameters returned by Adyen after the payment process
          PAYMENT_RESULT_SIGNATURE_FIELDS = [
            :authResult,
            :pspReference,
            :merchantReference,
            :skinCode
          ]

          def generate_signature_string
            ::ActiveMerchant::Billing::Integrations::Adyen::Return::PAYMENT_RESULT_SIGNATURE_FIELDS.map {|key| @params[key.to_s]} * ""
          end

          def generate_signature
            if @shared_secret.nil?
              digest = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, 'secret', generate_signature_string)
            else
              digest = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, @shared_secret, generate_signature_string)
            end
            return Base64.encode64(digest).strip
          end
          
          def signature_is_valid?
            generate_signature.to_s == params['merchantSig'].to_s
          end

          def payment_authorized?
            params['authResult'] == 'AUTHORISED'
          end
  
          def success?
            signature_is_valid? and payment_authorized?
          end

          def message
            params['authResult']
          end

        end
      end
    end
  end
end

