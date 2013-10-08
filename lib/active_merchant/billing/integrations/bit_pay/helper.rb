module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order_id, account, options)
            super
            add_field('account', account)
            add_field('orderID', order_id)
            add_field('posData', options[:authcode])
            add_field('currency', options[:currency])
            add_field('fullNotifications', 'true')
            add_field('transactionSpeed', options[:transactionSpeed] || "high")
            add_field('address1', options[:address1])
          end

          # Replace with the real mapping
          mapping :account, 'key'
          mapping :amount, 'price'

          mapping :order, 'orderID'        
          mapping :currency, 'currency'

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
