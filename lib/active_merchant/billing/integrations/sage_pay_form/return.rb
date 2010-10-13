module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module SagePayForm
        class Return < ActiveMerchant::Billing::Integrations::Return
          class ReturnError < StandardError; end
          class MissingCryptKey  < ReturnError; end
          class MissingCryptData < ReturnError; end
          class InvalidCryptData < ReturnError; end

          include Encryption

          def success?
            begin
              crypt_params['Status'] == 'OK'
            rescue ReturnError
              false
            end
          end
          
          def message
            begin
              crypt_params['StatusDetail']
            rescue MissingCryptData
              'No data received from SagePay'
            rescue MissingCryptKey
              'No merchant decryption key supplied'
            rescue InvalidCryptData
              'Invalid data received from SagePay'
            end
          end

          private
          
          def crypt_params
            crypt = @params['crypt']
            key   = @options[:credential2]
            
            raise MissingCryptData if crypt.blank?
            raise MissingCryptKey  if key.blank?
            
            @crypt_params ||= parse(sage_decrypt(crypt, key))
            raise InvalidCryptData unless @crypt_params.has_key?('Status')
            
            @crypt_params
          end
        end
      end
    end
  end
end
