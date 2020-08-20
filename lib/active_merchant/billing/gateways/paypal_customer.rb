module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCustomer < PaypalExpressRest

      def register_partner(options)
        post('customer/partner-referrals', options)
      end
    end
  end
end
## Calling Mechanism
# paypal_customer = ActiveMerchant::Billing::PaypalCustomer.new(paypal_options)
# paypal_customer.register_partner({})
