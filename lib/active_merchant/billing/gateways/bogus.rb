module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Bogus Gateway
    class BogusGateway < Gateway
      SUCCESS_MESSAGE = "Bogus Gateway: Forced success"
      FAILURE_MESSAGE = "Bogus Gateway: Forced failure"
      ERROR_MESSAGE = "Bogus Gateway: Use CreditCard number ending in 1 for success, 2 for exception and anything else for error"
      CREDIT_ERROR_MESSAGE = "Bogus Gateway: Use CreditCard number ending in 1 for success, 2 for exception and anything else for error"
      UNSTORE_ERROR_MESSAGE = "Bogus Gateway: Use trans_id ending in 1 for success, 2 for exception and anything else for error"
      CAPTURE_ERROR_MESSAGE = "Bogus Gateway: Use authorization number ending in 1 for exception, 2 for error and anything else for success"
      VOID_ERROR_MESSAGE = "Bogus Gateway: Use authorization number ending in 1 for exception, 2 for error and anything else for success"
      REFUND_ERROR_MESSAGE = "Bogus Gateway: Use trans_id number ending in 1 for exception, 2 for error and anything else for success"

      self.supported_countries = ['US']
      self.supported_cardtypes = [:bogus]
      self.homepage_url = 'http://example.com'
      self.display_name = 'Bogus'

      def authorize(money, credit_card_or_reference, options = {})
        money = amount(money)
        case nth_last(credit_card_or_reference, 1)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:authorized_amount => money}, :test => true, :authorization => authorization(credit_card_or_reference) )
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:authorized_amount => money, :error => FAILURE_MESSAGE }, :test => true)
        else
          raise Error, ERROR_MESSAGE
        end
      end

      def purchase(money, credit_card_or_reference, options = {})
        money = amount(money)
        case nth_last(credit_card_or_reference, 2)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true, :authorization => authorization(credit_card_or_reference))
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE },:test => true)
        else
          raise Error, ERROR_MESSAGE
        end
      end

      def recurring(money, credit_card_or_reference, options = {})
        money = amount(money)
        case nth_last(credit_card_or_reference, 3)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true)
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE },:test => true)
        else
          raise Error, ERROR_MESSAGE
        end
      end

      def credit(money, credit_card_or_reference, options = {})
        if credit_card_or_reference.is_a?(String)
          deprecated CREDIT_DEPRECATION_MESSAGE
          return refund(money, credit_card_or_reference, options)
        end

        money = amount(money)
        case nth_last(credit_card_or_reference, 4)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true )
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE }, :test => true)
        else
          raise Error, CREDIT_ERROR_MESSAGE
        end
      end

      def refund(money, reference, options = {})
        money = amount(money)
        case nth_last(reference, 5)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true)
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE }, :test => true)
        else
          raise Error, REFUND_ERROR_MESSAGE
        end
      end

      def capture(money, reference, options = {})
        money = amount(money)
        case nth_last(reference, 6)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true)
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE }, :test => true)
        else
          raise Error, CAPTURE_ERROR_MESSAGE
        end
      end

      def void(reference, options = {})
        case nth_last(reference, 7)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:authorization => reference}, :test => true)
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:authorization => reference, :error => FAILURE_MESSAGE }, :test => true)
        else
          raise Error, VOID_ERROR_MESSAGE
        end
      end

      def store(credit_card_or_reference, options = {})
        case nth_last(credit_card_or_reference, 8)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:billingid => '1'}, :test => true, :authorization => authorization(credit_card_or_reference))
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:billingid => nil, :error => FAILURE_MESSAGE }, :test => true)
        else
          raise Error, ERROR_MESSAGE
        end
      end

      def unstore(reference, options = {})
        case nth_last(reference, 9)
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {}, :test => true)
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:error => FAILURE_MESSAGE },:test => true)
        else
          raise Error, UNSTORE_ERROR_MESSAGE
        end
      end

      private

      def authorization(credit_card_or_reference)
        return normalize(credit_card_or_reference)[-9,9]
      end

      def normalize(credit_card_or_reference)
        if credit_card_or_reference.respond_to?(:number)
          credit_card_or_reference.number
        else
          credit_card_or_reference.to_s
        end
      end

      def nth_last(credit_card_or_reference, n)
        c = normalize(credit_card_or_reference)
        c[-n] || c[0]
      end
    end
  end
end
