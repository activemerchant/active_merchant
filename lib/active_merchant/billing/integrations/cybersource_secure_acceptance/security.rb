module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CybersourceSecureAcceptance
        module Security
          def generate_signature data
            raise 'secret_key missing' unless @secret_key
            sign(build_data_to_sign(data),@secret_key)
          end

          def valid? data
            signature = generate_signature data
            signature.strip.eql? params['signature'].strip
          end

          private

          def sign data, secret_key
            mac = Digest::HMAC.new secret_key, Digest::SHA256
            mac.update data
            Base64.encode64(mac.digest).gsub "\n", ''
          end

          def build_data_to_sign params
            signed_field_names = params['signed_field_names'].split ','
            data_to_sign = Array.new
            signed_field_names.each { |signed_field_name|
              data_to_sign << signed_field_name + '=' + params[signed_field_name].to_s
            }
            comma_separate data_to_sign
          end

          def comma_separate data_to_sign
            csv = ''
            data_to_sign.length.times do |i|
              csv << data_to_sign[i]
              csv << ',' if i != data_to_sign.length-1
            end
            csv
          end
        end
      end
    end
  end
end
