module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paysera
        module Common

          PUBLIC_KEY_LOCATION = 'https://www.paysera.com/download/public.key'

          def generate_signature_v1(base64_encoded_data, password)
            Digest::MD5.hexdigest(base64_encoded_data + password)
          end

          def validate_signature_v2(expected_signature, base64_encoded_data)
            signature_token = Base64.urlsafe_decode64(expected_signature)
            get_public_key.verify(OpenSSL::Digest::SHA1.new, signature_token, base64_encoded_data)
          end

          def get_public_key
            public_key =  OpenSSL::X509::Certificate.new(open(PUBLIC_KEY_LOCATION).read).public_key
            raise 'Could not download public key to verify signature' if public_key.nil?
            public_key
          end

          private
            def combine_parameters(params)
              URI.escape(
                  params
                    .collect { |k,v| "#{k}=#{v}" }
                    .join('&')
              )
            end
        end
      end
    end
  end
end
