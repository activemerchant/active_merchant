require File.dirname(__FILE__) +  '/smart_ps.rb'
require File.dirname(__FILE__) + '/braintree/braintree_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BraintreeOrangeGateway < SmartPs
      include BraintreeCommon

      self.display_name = 'Braintree (Orange Platform)'
      
      def api_url
        'https://secure.braintreepaymentgateway.com/api/transact.php'
      end
    end
  end
end

