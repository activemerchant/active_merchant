module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    class Error < ActiveMerchantError #:nodoc:
    end

    class QueryResponse
      attr_reader :message, :test, :entries

      def success?
        @success
      end

      def test?
        @test
      end

      def initialize(success, message, test, entries)
        @success, @message = success, message
        @test = test
        @entries = entries
      end

      def to_s
        "Success: " + success?.to_s + "\n" +
        "Test: " + test?.to_s + "\n" +
        "Message: " + message + "\n" +
        "Entries: " + entries.inspect
      end
    end
  end
end
