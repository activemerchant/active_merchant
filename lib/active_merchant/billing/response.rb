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

    class MultiResponse < Response
      def self.run(primary_response = :last, &block)
        response = new.tap(&block)
        response.primary_response = primary_response
        response
      end

      attr_reader :responses
      attr_writer :primary_response

      def initialize
        @responses = []
        @primary_response = :last
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

      def primary_response
        success? && @primary_response == :first ? @responses.first : @responses.last
      end

      %w(params message test authorization avs_result cvv_result test? fraud_review?).each do |m|
        class_eval %(
          def #{m}
            (@responses.empty? ? nil : primary_response.#{m})
          end
        )
      end
    end
  end
end
