require 'active_merchant/billing/gateways/smart_ps.rb'
require 'active_merchant/billing/gateways/braintree/braintree_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BraintreeOrangeGateway < SmartPs
      include BraintreeCommon

      self.display_name = 'Braintree (Orange Platform)'
      self.supported_countries = ["US"]

      self.live_url = self.test_url = 'https://secure.braintreepaymentgateway.com/api/transact.php'

      def add_processor(post, options)
        post[:processor_id] = options[:processor] unless options[:processor].nil?
      end
    end
  end
end
