require 'base64'
require 'stringio'
require 'zlib'
require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Directebanking
        class Return < ActiveMerchant::Billing::Integrations::Return

          # For this to work you have to set the following url in the admin interface of directebanking
          #
          # Success link: 
          #   http://-USER_VARIABLE_0-?authResult=success&transaction=-TRANSACTION-&sender_holder=-SENDER_HOLDER-
          # 
          # Abort link:
          #   http://-USER_VARIABLE_0-?authResult=abort&transaction=-TRANSACTION-&sender_holder=-SENDER_HOLDER-

          def success?
            params['authResult'] == 'success'
          end

          def message
            params['authResult']
          end
          
          def transaction
            params['transaction']
          end

        end
      end
    end
  end
end

