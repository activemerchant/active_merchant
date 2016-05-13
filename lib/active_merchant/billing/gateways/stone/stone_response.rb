module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class StoneResponse
      attr_reader :raw, :info

      def initialize(raw)
        @raw = raw
        begin
          @info = JSON.parse(raw).deep_transform_keys{ |key| key.underscore.to_sym }
        rescue
          @info = empty_response(raw)
        end
      end

      def request_key
        @info[:request_key]
      end

      def transaction_key
        transaction[:transaction_key]
      end

      def transaction_reference
        transaction[:transaction_reference]
      end

      def card_token
        transaction[:credit_card][:instant_buy_key]
      end

      def order_key
        @info[:order_result][:order_key]
      end

      def success?
        !error? && has_transaction? && transaction[:success]
      end

      def message
        error_message || transaction_message || "Erro no processamento."
      end

      def authorization
        success? ? transaction[:transaction_key] : nil
      end

      def error_code
        unless success?
          Gateway::STANDARD_ERROR_CODE[:card_declined]
        end
      end

      def has_transaction?
        @info[:credit_card_transaction_result_collection].any?
      end

      def transaction
        @info[:credit_card_transaction_result_collection][0]
      end

      def transaction_message
        has_transaction? and transaction[:acquirer_message].split('|').last
      end

      def error?
        @info[:error_report].present?
      end

      def error_message
        error? and @info[:error_report][:error_item_collection][0][:description]
      end

      def empty_response(description = nil)
        {
          error_report: {
            error_item_collection:[{
              description: description,
              error_code: Gateway::STANDARD_ERROR_CODE[:processing_error]
            }]
          },
          credit_card_transaction_result_collection: []
        }
      end

      # https://github.com/activemerchant/active_merchant/blob/master/lib/active_merchant/billing/response.rb#L22
      def stringify_keys
        self
      end

      def to_s
        @raw
      end
    end
  end
end