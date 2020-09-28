module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Error < ActiveMerchantError #:nodoc:
    end

    class Response
      attr_reader :params, :message, :test, :authorization, :avs_result, :cvv_result, :error_code, :emv_authorization

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
        @error_code = options[:error_code]
        @emv_authorization = options[:emv_authorization]

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
      def self.run(use_first_response = false, &block)
        new(use_first_response).tap(&block)
      end

      attr_reader :responses, :primary_response

      def initialize(use_first_response = false)
        @responses = []
        @use_first_response = use_first_response
        @primary_response = nil
      end

      def process(ignore_result=false)
        return unless success?

        response = yield
        self << response

        unless ignore_result
          if(@use_first_response && response.success?)
            @primary_response ||= response
          else
            @primary_response = response
          end
        end
      end

      def <<(response)
        if response.is_a?(MultiResponse)
          response.responses.each{|r| @responses << r}
        else
          @responses << response
        end
      end

      def success?
        (primary_response ? primary_response.success? : true)
      end

      %w(params message test authorization avs_result cvv_result error_code emv_authorization test? fraud_review?).each do |m|
        class_eval %(
          def #{m}
            (@responses.empty? ? nil : primary_response.#{m})
          end
        )
      end
    end
  end
end
