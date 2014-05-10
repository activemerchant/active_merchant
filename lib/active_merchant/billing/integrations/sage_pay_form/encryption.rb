module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module SagePayForm
        module Encryption
          def sage_encrypt(plaintext, key)
            encrypted = cipher(:encrypt, key, plaintext)
            "@#{encrypted.upcase}"
          end

          def sage_decrypt(ciphertext, key)
            ciphertext = ciphertext[1..-1] # remove @ symbol at the beginning of a string
            cipher(:decrypt, key, ciphertext)
          rescue OpenSSL::Cipher::CipherError => e
            return '' if e.message == 'wrong final block length'
            raise
          end

          def sage_encrypt_salt(min, max)
            length = rand(max - min + 1) + min
            SecureRandom.base64(length + 4)[0, length]
          end

          private

          def cipher(action, key, payload)
            if action == :decrypt
              payload = [payload].pack('H*')
            end

            cipher = OpenSSL::Cipher::AES128.new(:CBC)
            cipher.public_send(action)
            cipher.key = key
            cipher.iv = key
            result = cipher.update(payload) + cipher.final

            if action == :encrypt
              result = result.unpack('H*')[0]
            end

            result
          end
        end
      end
    end
  end
end
