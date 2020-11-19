require 'active_merchant/billing/gateways/payfort/payfort_codes'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PayfortHelper #:nodoc:
      include ActiveMerchant::Billing::PayfortCodes

      def process_response(response)
        Response.new(
          success_from(response),
          message_from(response),
          response,
          error_code: response['response_code'],
          fraud_review: valid_signature?(response),
          authorization: authorization_from(response),
          test: test?
        )
      end

      private

      def logger
        @options[:logger] || Logger.new(STDOUT)
      end

      def url(action = :api)
        api_url = (test? ? test_url : live_url)
        uri = if action == :page
                "#{api_url}/paymentPage"
              else
                "#{api_url}/paymentApi"
              end
        uri
      end

      def commit(parameters)
        parameters = build_request_params(parameters)
        post = ssl_post(url, parameters.to_json, headers)
        response = parse(post)
        process_response(response)
      end

      def headers
        {
          'Content-Type' => 'application/json;charset=UTF-8'
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      # Build PayFort request parameters
      def build_request_params(parameters)
        parameters = add_common_parameters(parameters)
        parameters[:signature] = sign(parameters.except(:signature))
        # Stringify all keys and values
        parameters = Hash[parameters.map { |k, v| [k.to_s, v.to_s] }]
        parameters
      end

      # Add common parameters to requests to PayFort
      #
      # ==== Common parameters
      #
      # * <tt>:merchant_identifier</tt>
      # * <tt>:access_code</tt>
      # * <tt>:language</tt>
      # * <tt>:signature</tt>
      def add_common_parameters(parameters)
        common = {
          merchant_identifier: @options[:identifier],
          access_code: @options[:access_code],
          language: 'en'
        }
        parameters.merge!(common)
      end

      # Generate SHA signature for request parameters
      #
      # ==== Steps
      # * Sort parameters alphabetically
      # * Concatenate all parameters into a string
      # * Surround string from previous step with signature_phrase
      # * Generate SHA256 digest for string from previous step
      def sign(parameters)
        phrase = []
        parameters.to_unsafe_h.sort.to_h.each do |k, v|
          phrase << [k, v].join('=')
        end
        phrase.push(@options[:signature_phrase])
        phrase.unshift(@options[:signature_phrase])
        Digest::SHA256.hexdigest(phrase.join)
      end

      def success_from(response)
        SUCCESS_CODES.include?(response['response_code'][0..1])
      end

      def valid_signature?(response)
        sign(response.except('signature')) == response['signature']
      end

      def message_from(response)
        response['response_message']
      end

      def authorization_from(response)
        response['fort_id']
      end
    end
  end
end
