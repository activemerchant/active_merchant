module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class StoneResponse
      attr_reader :raw, :info

      def initialize(raw)
        @raw = raw
        begin
          @info = JSON.parse(raw)
        rescue JSON::ParserError
          @info = empty_response(raw)
        end
      end

      def request_key
        @info['RequestKey']
      end

      def transaction_key
        transaction['TransactionKey']
      end

      def transaction_reference
        transaction['TransactionReference']
      end

      def card_token
        transaction['CreditCard']['InstantBuyKey']
      end

      def order_key
        @info['OrderResult']['OrderKey']
      end

      def success?
        !error? && has_transaction? && transaction['Success']
      end

      def message
        error_message || transaction_message || "Ocorreu um erro ao tentar processar seu pagamento, tente novamente."
      end

      def authorization
        success? ? transaction['TransactionKey'] : nil
      end

      def error_code
        unless success?
          Gateway::STANDARD_ERROR_CODE[:card_declined]
        end
      end

      def has_transaction?
        @info['CreditCardTransactionResultCollection'].any?
      end

      def transaction
        @info['CreditCardTransactionResultCollection'][0]
      end

      def transaction_message
        has_transaction? and transaction['AcquirerMessage'].split('|').last
      end

      def error?
        @info['ErrorReport'].present?
      end

      def error_message
        error? and @info['ErrorReport']['ErrorItemCollection'][0]['Description']
      end

      def empty_response(description = nil)
        {
          'ErrorReport' => {
            'ErrorItemCollection' => [{
              'Description' => description,
              'ErrorCode' => Gateway::STANDARD_ERROR_CODE[:processing_error]
            }]
          },
          'CreditCardTransactionResultCollection' => []
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