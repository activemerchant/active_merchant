module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Null Gateway
    class NullGateway < Gateway
      AUTHORIZATION = '00000'

      SUCCESS_MESSAGE = "Null Gateway: Forced success"

      self.supported_countries = []
      self.supported_cardtypes = [:null]
      self.homepage_url = 'http://example.com'
      self.display_name = 'Null'

      def authorize(money, paysource, options = {})
        money = amount(money)
        Response.new(true, SUCCESS_MESSAGE, {:authorized_amount => money}, :test => true, :authorization => AUTHORIZATION )
      end

      def purchase(money, paysource, options = {})
        Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true, :authorization => AUTHORIZATION)
      end

      def credit(money, paysource, options = {})
        if paysource.is_a?(String)
          ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
          return refund(money, paysource, options)
        end

        money = amount(money)
        Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true )
      end

      def refund(money, reference, options = {})
        money = amount(money)
        Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true)
      end

      def capture(money, reference, options = {})
        money = amount(money)
        Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true)
      end

      def void(reference, options = {})
        Response.new(true, SUCCESS_MESSAGE, {:authorization => reference}, :test => true)
      end

      def store(paysource, options = {})
        Response.new(true, SUCCESS_MESSAGE, {:billingid => '1'}, :test => true, :authorization => AUTHORIZATION)
      end

      def unstore(reference, options = {})
        Response.new(true, SUCCESS_MESSAGE, {}, :test => true)
      end

    end
  end
end
