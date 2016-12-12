module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MidtransResponse < Response
      attr_reader :params, :message, :test, :authorization, :avs_result, :cvv_result, :error_code, :emv_authorization, :status_code, :transaction_status, :transaction_id

      def initialize(success, message, params = {}, options = {})
        @success, @message, @params = success, message, params
        @test = options[:test] || false
        @authorization = options[:authorization]
        @fraud_review = options[:fraud_review]
        @error_code = options[:error_code]
        @emv_authorization = options[:emv_authorization]
        @status_code = options[:status_code]
        @transaction_status = options[:transaction_status]
        @transaction_id = options[:transaction_id]

        @avs_result = if options[:avs_result].kind_of?(AVSResult)
          options[:avs_result].to_hash
        else
          AVSResult.new(options[:avs_result]).to_hash
        end

        @cvv_result = if options[:cvv_result].kind_of?(CVVResult)
          options[:cvv_result].to_hash
        else
          CVVResult.new(options[:cvv_result]).to_hash
        end
      end
    end
  end
end
