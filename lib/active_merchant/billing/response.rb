module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    class Error < ActiveMerchantError #:nodoc:
    end

    class Response
      attr_reader :params, :message, :test, :authorization, :avs_result, :cvv_result

      def success?
        @success
      end

      def test?
        @test
      end

      def fraud_review?
        @fraud_review
      end

      def initialize(success, message, params = {}, options = {})
        @success, @message, @params = success, message, params.stringify_keys
        @test = options[:test] || false
        @authorization = options[:authorization]
        @fraud_review = options[:fraud_review]
        @avs_result = AVSResult.new(options[:avs_result]).to_hash
        @cvv_result = CVVResult.new(options[:cvv_result]).to_hash
      end
    end

    class MultiResponse < Response
      attr_reader :responses

      def initialize
        @responses = []
      end

      def process
        self << yield if(responses.empty? || success?)
      end

      def <<(response)
        if response.is_a?(MultiResponse)
          response.responses.each{|r| @responses << r}
        else
          @responses << response
        end
      end

      def success?
        @responses.all?{|r| r.success?}
      end

      %w(params message test authorization avs_result cvv_result test? fraud_review?).each do |m|
        class_eval %(
          def #{m}
            @responses.last.#{m}
          end
        )
      end
    end
  end
end
