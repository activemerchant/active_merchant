module ActiveMerchant
  module Billing
    module PaypalExpressCommon
      def self.included(base)
        base.cattr_accessor :test_redirect_url
        base.cattr_accessor :live_redirect_url
        base.live_redirect_url = 'https://www.paypal.com/cgibin/webscr'
      end
      
      def redirect_url
        test? ? test_redirect_url : live_redirect_url
      end
      
      def redirect_url_for(token, options = {})
        options = {:review => true, :mobile => false}.update(options)

        cmd  = options[:mobile] ? '_express-checkout-mobile' : '_express-checkout'
        url  = "#{redirect_url}?cmd=#{cmd}&token=#{token}"
        url += '&useraction=commit' unless options[:review]

        url
      end
    end
  end
end