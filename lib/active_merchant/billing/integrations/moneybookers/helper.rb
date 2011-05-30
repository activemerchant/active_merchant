module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybookers
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'pay_to_email'
          mapping :order, 'transaction_id'
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          
          mapping :customer,
            :first_name => 'firstname',
            :last_name  => 'lastname',
            :email      => 'pay_from_email',
            :phone      => 'phone_number'

          mapping :billing_address,
            :city     => 'city',
            :address1 => 'address',
            :address2 => 'address2',
            :state    => 'state',
            :zip      => 'postal_code',
            :country  => 'country'

          mapping :notify_url, 'status_url'
          mapping :return_url, 'return_url'
          mapping :cancel_return_url, 'cancel_url'
          mapping :description, 'detail1_text'
          
          def initialize(order, account, options = {})
            super
            add_tracking_token
          end


          private
          
          def add_tracking_token
            return if application_id.blank? || application_id == 'ActiveMerchant'

            add_field('merchant_fields', 'platform')
            add_field('platform', application_id)
          end
        end
      end
    end
  end
end
