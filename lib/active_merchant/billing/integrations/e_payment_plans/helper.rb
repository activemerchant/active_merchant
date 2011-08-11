module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module EPaymentPlans
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'order[account]'
          mapping :amount, 'order[amount]'

          mapping :order, 'order[num]'

          mapping :customer, :first_name => 'order[first_name]',
                             :last_name  => 'order[last_name]',
                             :email      => 'order[email]',
                             :phone      => 'order[phone]'

          mapping :billing_address, :city     => 'order[city]',
                                    :address1 => 'order[address1]',
                                    :address2 => 'order[address2]',
                                    :company  => 'order[company]',
                                    :state    => 'order[state]',
                                    :zip      => 'order[zip]',
                                    :country  => 'order[country]'

          mapping :notify_url, 'order[notify_url]'
          mapping :return_url, 'order[return_url]'
          mapping :cancel_return_url, 'order[cancel_return_url]'
          mapping :description, 'order[description]'
          mapping :tax, 'order[tax]'
          mapping :shipping, 'order[shipping]'
        end
      end
    end
  end
end
