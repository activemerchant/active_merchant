require File.dirname(__FILE__) + '/paypal/paypal_common_api'
require File.dirname(__FILE__) + '/paypal/paypal_express_response'
require File.dirname(__FILE__) + '/paypal_express_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalDigitalGoodsGateway < PaypalExpressGateway
      self.test_redirect_url = 'https://www.sandbox.paypal.com/incontext'
      self.live_redirect_url = 'https://www.paypal.com/incontext'

      self.supported_countries = %w(AU CA CN FI GB ID IN IT MY NO NZ PH PL SE SG TH VN)
      self.homepage_url = 'https://www.x.com/community/ppx/xspaces/digital_goods'
      self.display_name = 'PayPal Express Checkout for Digital Goods'

      def redirect_url_for(token, options = {})
        options[:review] ||= false
        super
      end

      # GATEWAY.setup_purchase(100,
      #  :ip                => "127.0.0.1",
      #  :description       => "Test Title",
      #  :return_url        => "http://return.url",
      #  :cancel_return_url => "http://cancel.url",
      #  :items             => [ { :name => "Charge",
      #                            :number => "1",
      #                            :quantity => "1",
      #                            :amount   => 100,
      #                            :description => "Description",
      #                            :category => "Digital" } ] )
      def build_setup_request(action, money, options)
        requires!(options, :items)
        raise ArgumentError, "Must include at least 1 Item" unless options[:items].length > 0
        options[:items].each do |item|
          requires!(item, :name, :number, :quantity, :amount, :description, :category)
          raise ArgumentError, "Each of the items must have the category 'Digital'" unless item[:category] == 'Digital'
        end

        super
      end

    end
  end
end
