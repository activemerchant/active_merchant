module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
  
    class Error < StandardError #:nodoc:
    end
  
    class Response
      attr_reader :params
      attr_reader :message
      attr_reader :test
      attr_reader :authorization
    
      def success?
        @success
      end

      def test?
        @test
      end
        
      def initialize(success, message, params = {}, options = {})
        @success, @message, @params = success, message, params.stringify_keys
        @test = options[:test] || false        
        @authorization = options[:authorization]        
      end
    end
  end
end
