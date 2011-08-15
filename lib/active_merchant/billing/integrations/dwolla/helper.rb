module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            super
            add_field('name', 'Store Purchase')
          end
          
          # Replace with the real mapping
          mapping :credential1, 'key'
          mapping :credential2, 'secret'
          mapping :notify_url, 'callback'
          mapping :return_url, 'redirect'
          mapping :test_mode, 'test'
          mapping :description, 'description'
          mapping :account, 'destinationid'
          mapping :amount, 'amount'
          mapping :tax, 'tax'
          mapping :shipping, 'shipping'
          mapping :order, 'orderid'          
        end
      end
    end
  end
end
