module ActiveMerchant
  module Billing
    module Integrations
      module PayuInPaisa
        class Notification < PayuIn::Notification
          def item_id
            params['udf2']
          end

          def checksum_ok?
            fields = user_defined.reverse.push( customer_email, customer_first_name, product_info, gross, invoice, :reverse => true )
            fields.unshift( transaction_status )
            unless PayuIn.checksum(@merchant_id, @secret_key, *fields ) == checksum
              @message = 'Return checksum not matching the data provided'
              return false
            end
            true
          end
        end
      end
    end
  end
end
