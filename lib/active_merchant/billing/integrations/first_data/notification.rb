require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      # First Data payment pages emulates the Authorize.Net SIM API. See
      # ActiveMerchant::Billing::Integrations::FirstData::Notification for
      # more details.
      #
      # # Example:
      # parser = FirstData::Notification.new(request.raw_post)
      # passed = parser.complete?
      #
      # order = Order.find_by_order_number(parser.invoice_num)
      #
      # unless order
      #   @message = 'Error--unable to find your transaction! Please contact us directly.'
      #   return render :partial => 'first_data_payment_response'
      # end
      #
      # if order.total != parser.gross.to_f
      #   logger.error "First Data said they paid for #{parser.gross} and it should have been #{order.total}!"
      #   passed = false
      # end
      #
      # # Theoretically, First Data will *never* pass us the same transaction
      # # ID twice, but we can double check that... by using
      # # parser.transaction_id, and checking against previous orders' transaction
      # # id's (which you can save when the order is completed)....
      # unless parser.acknowledge FIRST_DATA_TRANSACTION_KEY, FIRST_DATA_RESPONSE_KEY
      #  passed = false
      #  logger.error "ALERT POSSIBLE FRAUD ATTEMPT"
      # end
      #
      # unless parser.cavv_matches? and parser.avs_code_matches?
      #   logger.error 'Warning--non matching CC!' + params.inspect
      #   # Could fail them here, as well (recommended)...
      # end
      #
      # if passed
      #  # Set up your session, and render something that will redirect them to
      #  # your site, most likely.
      # else
      #  # Render failure or redirect them to your site where you will render failure
      # end

      module FirstData
        class Notification < ActiveMerchant::Billing::Integrations::AuthorizeNetSim::Notification
          def acknowledge(response_key, payment_page_id)
            Digest::MD5.hexdigest(response_key + payment_page_id + params['x_trans_id'] + sprintf('%.2f', gross)) == params['x_MD5_Hash'].downcase
          end
        end
      end
    end
  end
end
