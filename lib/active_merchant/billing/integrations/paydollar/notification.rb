require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar
        class Notification < ActiveMerchant::Billing::Integrations::Notification
	  include PostsData

          def initialize(post, options = {})
            super
	    @payment_status = "PAID"
          end

	  #Order Reference Number
          def item_id
            params['Ref']
          end
	 
	  def set_payment_status(result)
	    @payment_status = result
	  end

	  #The PayDollar server returns only one parameter
	  #the "order reference". However, it is mandatory to
	  #implement this method and hence using a variable
	  #with default value as "PAID". The value can be 
	  #updated by calling set_payment_status method
	  def status
	    @payment_status
          end

	  #The PayDollar server returns only one parameter
	  #the "order reference". However, it is mandatory to
	  #implement this method and hence just returning 0
          def gross
	    0
          end

	  def acknowledge(order_number)
	    order_number == item_id
	  end
        end
      end
    end
  end
end

