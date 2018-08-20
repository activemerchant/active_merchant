# frozen_string_literal: true

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Black42Pay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
          end

          mapping :member, 'member'
          mapping :secret, 'secret'
          mapping :action, 'action'
          mapping :buyer, 'buyer'
          mapping :email, 'email'
          mapping :phone, 'phone'
          mapping :product, 'product'
          mapping :currency, 'currency'
          mapping :price, 'price'
          mapping :quantity, 'quantity'
          mapping :ureturn, 'ureturn'
          mapping :unotify, 'unotify'
          mapping :ucancel, 'ucancel'
          
        end
      end
    end
  end
end
