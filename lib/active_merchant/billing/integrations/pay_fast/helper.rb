module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayFast
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common

          def initialize(order, account, options = {})
            super
            add_field('merchant_id', account)
            add_field('merchant_key', options.delete(:credential2))
            add_field('m_payment_id', order)
          end

          def form_fields
            @fields
          end

          def params
            @fields
          end

          mapping :merchant_id, 'merchant_id'
          mapping :merchant_key, 'merchant_key'
          mapping :return_url, 'return_url'
          mapping :cancel_return_url, 'cancel_url'
          mapping :notify_url, 'notify_url'
          mapping :name_first, 'name_first'
          mapping :name_last, 'name_last'
          mapping :email_address, 'email_address'
          mapping :payment_id, 'm_payment_id'
          mapping :amount, 'amount'
          mapping :item_name, 'item_name'
          mapping :description, 'item_name'
          
          mapping :customer, :first_name => 'name_first',
                             :last_name  => 'name_last',
                             :email      => 'email_address',
                             :phone      => 'phone'

          5.times { |i| mapping :"custom_str#{i}", "custom_str#{i}" }
          5.times { |i| mapping :"custom_int#{i}", "custom_int#{i}" }

          mapping :email_confirmation, 'email_confirmation'
          mapping :confirmation_address, 'confirmation_address'
        end
      end
    end
  end
end
