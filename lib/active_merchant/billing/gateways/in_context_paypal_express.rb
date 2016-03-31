module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class InContextPaypalExpressGateway < PaypalExpressGateway
      self.test_redirect_url = 'https://www.sandbox.paypal.com/checkoutnow'
      self.live_redirect_url = 'https://www.paypal.com/checkoutnow'

      def redirect_url_for(token, options = {})
        options = {review: true}.update(options)
        url  = "#{redirect_url}?token=#{token}"
        url += '&useraction=commit' unless options[:review]
        url
      end
    end
  end
end
