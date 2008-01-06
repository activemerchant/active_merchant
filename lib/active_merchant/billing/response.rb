module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
  
    class Error < ActiveMerchantError #:nodoc:
    end
  
    class Response
      attr_reader :params, :message, :test, :authorization, :avs_result, :ccv_result, :card_data
      
      def success?
        @success
      end

      def test?
        @test
      end
      
      def fraud_review?
        @fraud_review
      end
      
      def merchant_data
        {
          'avs_result' => avs_result,
          'ccv_result' => ccv_result,
          'card_data' => card_data
        }
      end
      
      def initialize(success, message, params = {}, options = {})
        @success, @message, @params = success, message, params.stringify_keys
        @test = options[:test] || false        
        @authorization = options[:authorization]
        @fraud_review = options[:fraud_review]
        @avs_result = AVSResult.new(options[:avs_code]).to_hash
        @ccv_result = CCVResult.new(options[:ccv_code]).to_hash
        @card_data = format_card_data(options[:card_number])
      end
      
      private
      def format_card_data(number)
        {
          'type' => CreditCard.type?(number),
          'number' => CreditCard.mask(number)
        }
      end
    end
  end
end
