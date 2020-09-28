module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Bogus Gateway
    class BogusGateway < Gateway
      AUTHORIZATION = '53433'

      AUTHORIZATION_EMV_SUCCESS = '8A023030'
      AUTHORIZATION_EMV_DECLINE = '8A023035'

      SUCCESS_MESSAGE = "Bogus Gateway: Forced success"
      FAILURE_MESSAGE = "Bogus Gateway: Forced failure"
      NUMBER_ERROR_MESSAGE = "Bogus Gateway: Use CreditCard number ending in 1 for success, 2 for exception and anything else for error"
      AMOUNT_ERROR_MESSAGE = "Bogus Gateway: Use amount ending in 00 for success, 05 for failure and anything else for exception"
      UNSTORE_ERROR_MESSAGE = "Bogus Gateway: Use trans_id ending in 1 for success, 2 for exception and anything else for error"
      CAPTURE_ERROR_MESSAGE = "Bogus Gateway: Use authorization number ending in 1 for exception, 2 for error and anything else for success"
      VOID_ERROR_MESSAGE = "Bogus Gateway: Use authorization number ending in 1 for exception, 2 for error and anything else for success"
      REFUND_ERROR_MESSAGE = "Bogus Gateway: Use trans_id number ending in 1 for exception, 2 for error and anything else for success"
      CHECK_ERROR_MESSAGE = "Bogus Gateway: Use bank account number ending in 1 for success, 2 for exception and anything else for error"

      self.supported_countries = []
      self.supported_cardtypes = [:bogus]
      self.homepage_url = 'http://example.com'
      self.display_name = 'Bogus'

      def authorize(money, paysource, options = {})
        if paysource.respond_to?(:emv?) && paysource.emv?
          authorize_emv(money, paysource, options)
        else
          authorize_swipe(money, paysource, options)
        end
      end

      def purchase(money, paysource, options = {})
        if paysource.respond_to?(:emv?) && paysource.emv?
          purchase_emv(money, paysource, options)
        else
          purchase_swipe(money, paysource, options)
        end
      end

      def credit(money, paysource, options = {})
        if paysource.is_a?(String)
          ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
          return refund(money, paysource, options)
        end

        money = amount(money)
        case normalize(paysource)
        when /1$/
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true )
        when /2$/
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error])
        else
          raise Error, error_message(paysource)
        end
      end

      def refund(money, reference, options = {})
        money = amount(money)
        case reference
        when /1$/
          raise Error, REFUND_ERROR_MESSAGE
        when /2$/
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error])
        else
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true)
        end
      end

      def capture(money, reference, options = {})
        money = amount(money)
        case reference
        when /1$/
          raise Error, CAPTURE_ERROR_MESSAGE
        when /2$/
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error])
        else
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true)
        end
      end

      def void(reference, options = {})
        case reference
        when /1$/
          raise Error, VOID_ERROR_MESSAGE
        when /2$/
          Response.new(false, FAILURE_MESSAGE, {:authorization => reference, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error])
        else
          Response.new(true, SUCCESS_MESSAGE, {:authorization => reference}, :test => true)
        end
      end

      def store(paysource, options = {})
        case normalize(paysource)
        when /1$/
          Response.new(true, SUCCESS_MESSAGE, {:billingid => '1'}, :test => true, :authorization => AUTHORIZATION)
        when /2$/
          Response.new(false, FAILURE_MESSAGE, {:billingid => nil, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error])
        else
          raise Error, error_message(paysource)
        end
      end

      def unstore(reference, options = {})
        case reference
        when /1$/
          Response.new(true, SUCCESS_MESSAGE, {}, :test => true)
        when /2$/
          Response.new(false, FAILURE_MESSAGE, {:error => FAILURE_MESSAGE },:test => true, :error_code => STANDARD_ERROR_CODE[:processing_error])
        else
          raise Error, UNSTORE_ERROR_MESSAGE
        end
      end

      private

      def authorize_emv(money, paysource, options = {})
        money = amount(money)
        case money
        when /00$/
          Response.new(true, SUCCESS_MESSAGE, {:authorized_amount => money}, :test => true, :authorization => AUTHORIZATION, :emv_authorization => AUTHORIZATION_EMV_SUCCESS)
        when /05$/
          Response.new(false, FAILURE_MESSAGE, {:authorized_amount => money, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error], :emv_authorization => AUTHORIZATION_EMV_DECLINE)
        else
          raise Error, error_message(paysource)
        end
      end

      def authorize_swipe(money, paysource, options = {})
        money = amount(money)
        case normalize(paysource)
        when /1$/
          Response.new(true, SUCCESS_MESSAGE, {:authorized_amount => money}, :test => true, :authorization => AUTHORIZATION )
        when /2$/
          Response.new(false, FAILURE_MESSAGE, {:authorized_amount => money, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error])
        else
          raise Error, error_message(paysource)
        end
      end

      def purchase_emv(money, paysource, options = {})
        money = amount(money)
        case money
        when /00$/
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true, :authorization => AUTHORIZATION, :emv_authorization => AUTHORIZATION_EMV_SUCCESS)
        when /05$/
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error], :emv_authorization => AUTHORIZATION_EMV_DECLINE)
        else
          raise Error, error_message(paysource)
        end
      end

      def purchase_swipe(money, paysource, options = {})
        money = amount(money)
        case normalize(paysource)
        when /1$/, AUTHORIZATION
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money}, :test => true, :authorization => AUTHORIZATION)
        when /2$/
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money, :error => FAILURE_MESSAGE }, :test => true, :error_code => STANDARD_ERROR_CODE[:processing_error])
        else
          raise Error, error_message(paysource)
        end
      end

      def normalize(paysource)
        if paysource.respond_to?(:account_number) && (paysource.try(:number).blank? || paysource.number.blank?)
          paysource.account_number
        elsif paysource.respond_to?(:number)
          paysource.number
        else
          paysource.to_s
        end
      end

      def error_message(paysource)
        if paysource.respond_to?(:emv?) && paysource.emv?
          AMOUNT_ERROR_MESSAGE
        elsif paysource.respond_to?(:account_number)
          CHECK_ERROR_MESSAGE
        elsif paysource.respond_to?(:number)
          NUMBER_ERROR_MESSAGE
        end
      end
    end
  end
end
