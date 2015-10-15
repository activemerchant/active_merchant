module ActiveMerchant
  module Billing
    module PaypalExpressCommon
      def self.included(base)
        if base.respond_to?(:class_attribute)
          base.class_attribute :test_redirect_url
          base.class_attribute :live_redirect_url
        else
          base.class_inheritable_accessor :test_redirect_url
          base.class_inheritable_accessor :live_redirect_url
        end
        base.live_redirect_url = 'https://www.paypal.com/cgi-bin/webscr'
      end

      def redirect_url
        test? ? test_redirect_url : live_redirect_url
      end

      def redirect_url_for(token, options = {})
        options = {:review => true, :mobile => false, :in_context => :false}.update(options)

        if options[:in_context] 
          url = "https://www.sandbox.paypal.com/checkoutnow?token=#{token}"
        else
          cmd  = options[:mobile]  ? '_express-checkout-mobile' : '_express-checkout'
          url  = "#{redirect_url}?cmd=#{cmd}&token=#{token}"
          url += '&useraction=commit' unless options[:review]
        end
        url
      end
    end
  end
end
