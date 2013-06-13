module ActiveMerchant # Primary active_merchant module
  module Billing # Primary active_merchant billing module
    module Integrations # Primary active_merchant integrations module
      module Paydollar # The active_merchant's Paydollar module
        # Paydollar Helper class
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          @hash_key = nil

          def initialize(order, account, options = {})
            super
            add_field("charset", "utf-8")
          end

          # Set the secret hash for generating the secure hash to be sent in the
          # request to Paydollar
          def secret_hash(value)
            @hash_key = value
          end

          # Adds the secure hash to the form
          def form_fields
            @fields.merge("secureHash" => generate_secure_hash)
          end

          # Mappings - Mandatory parameters
          mapping :merchant_id, 'merchantId'
          mapping :amount, 'amount'
          mapping :currency, 'currCode'
          mapping :order, 'orderRef'
          mapping :return_url, 'successUrl'
          mapping :cancel_return_url, 'cancelUrl'
          mapping :fail_url, 'failUrl'
          mapping :pay_type, 'payType'
          mapping :language, 'lang'
          mapping :pay_method, 'payMethod'
          mapping :mps_mode, 'mpsMode'

          #Optional parameters - If required add parameters as
          #described in PayDollar documenation
          mapping :secure_hash, 'secureHash' #see comments for generate_secure_hash
          #mapping :description, 'remark'
          mapping :tax, ''
          mapping :shipping, ''

          #Secure hash is used to authenticate the integrity of the
          #transaction information and the identity of the merchant.
          #It is calculated by hashing the combination of various
          #transaction parameters (merchantId, orderRef, currCode,
          #amount, payType and the Secure Hash Secret.
          #    NOTE:
          #    - Applies to merchants who registered this function only.
          #    - For more information, please refer to PayDollar documentation.
          # @return [String] The generated secure hash
          def generate_secure_hash
            if (@hash_key != nil) then
              fields = [@fields['merchantId'], @fields['orderRef'], @fields['currCode'], 
                  @fields['amount'], @fields['payType'], @hash_key]
            else 
              fields = [@fields['merchantId'], @fields['orderRef'], @fields['currCode'], 
              @fields['amount'], @fields['payType']]
            end
              
            fields = fields.join("|")
            return Digest::SHA1.hexdigest(fields)
          end
        end
      end
    end
  end
end
