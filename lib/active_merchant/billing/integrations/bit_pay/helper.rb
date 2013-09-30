module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          # Replace with the real mapping
          mapping :account, ''
          mapping :amount, 'price'
        
          mapping :order, 'posData'

          mapping :customer, :first_name => 'buyerName',
                             :email      => 'buyerEmail',
                             :phone      => 'buyerPhone'

          mapping :billing_address, :city     => 'buyerCity',
                                    :address1 => 'buyerAddress1',
                                    :address2 => 'buyerAddress2',
                                    :state    => 'buyerState',
                                    :zip      => 'buyerZip',
                                    :country  => 'buyerCountry'

          mapping :notify_url, 'notificationURL'
          mapping :return_url, 'returnURL'
        end
      end
    end
  end
end
