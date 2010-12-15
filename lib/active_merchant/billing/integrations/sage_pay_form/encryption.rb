module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module SagePayForm
        module Encryption
          def sage_encrypt(plaintext, key)
            ActiveSupport::Base64.encode64s(sage_encrypt_xor(plaintext, key))
          end

          def sage_decrypt(ciphertext, key)
            sage_encrypt_xor(ActiveSupport::Base64.decode64(ciphertext), key)
          end
          
          def sage_encrypt_salt(min, max)
            length = rand(max - min + 1) + min
            SecureRandom.base64(length + 4)[0, length]
          end

          private

          def sage_encrypt_xor(data, key)
            raise 'No key provided' if key.blank?
            
            key *= (data.length.to_f / key.length.to_f).ceil
            key = key[0, data.length]

            data.bytes.zip(key.bytes).map { |b1, b2| (b1 ^ b2).chr }.join
          end
        end
      end
    end
  end
end
