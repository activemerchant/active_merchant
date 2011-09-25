module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            super
            add_field('name', 'Store Purchase')

            if ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
              add_field('test', 'true')
            end 
          end
          
          # Replace with the real mapping
          mapping :account, 'destinationid'
          mapping :credential2, 'key'
          mapping :credential3, 'secret'
          mapping :notify_url, 'callback'
          mapping :return_url, 'redirect'
          mapping :description, 'description'
          mapping :amount, 'amount'
          mapping :tax, 'tax'
          mapping :shipping, 'shipping'
          mapping :order, 'orderid'          
        end
      end
    end
  end
end
