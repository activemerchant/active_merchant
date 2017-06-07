module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Webmoney
        module Common
          def generate_signature_string
            "#{params['LMI_PAYEE_PURSE']}#{params['LMI_PAYMENT_AMOUNT']}#{params['LMI_PAYMENT_NO']}#{params['LMI_MODE']}#{params['LMI_SYS_INVS_NO']}#{params['LMI_SYS_TRANS_NO']}#{params['LMI_SYS_TRANS_DATE']}#{secret}#{params['LMI_PAYER_PURSE']}#{params['LMI_PAYER_WM']}"
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string).upcase
          end
        end
      end
    end
  end
end
