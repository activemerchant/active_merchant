module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    class Error < ActiveMerchantError #:nodoc:
    end

    class TransactionResponse
      attr_reader :message, :test, :transactions

      def success?
        @success
      end

      def test?
        @test
      end

      def initialize(success, message, test, transactions)
        @success, @message = success, message
        @test = test
        @transactions = transactions
      end
    end
  end
end
