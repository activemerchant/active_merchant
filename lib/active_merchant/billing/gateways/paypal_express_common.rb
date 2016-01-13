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

      def build_redirect_url_for(token, options: {}, cmd: nil)
        options = {review: true}.update(options)
        url = "#{redirect_url}?token=#{token}"
        url += '&useraction=commit' unless options[:review]
        url += "&cmd=#{cmd}" if cmd
        url
      end
    end
  end
end
