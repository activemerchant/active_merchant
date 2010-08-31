require 'net/http'
require 'uri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MoneybookersResponse
      def initialize response, options
        @params   = response.header.to_hash
        @body     = response.body
        @response = response
        @options  = options
      end

      def token
        cookie = @params["set-cookie"]
        if cookie && cookie[0]
          cookie[0].match(/SESSION_ID=(.+?);/)[1]
        else
          nil
        end
      end

      def body
        @body
      end

      def success?
        @response && @response.header && @response.header.message == "OK" || false
      end

      def test?
        @options['prepare_only'] == "1"
      end
    end

    class MoneybookersRequest
      attr_reader :result

      def initialize options
        @options  = setup_options(options)
      end

      def commit
        @result = MoneybookersResponse.
          new(Net::HTTP.post_form(URI.parse(endpoint_url),@options), @options)
      end

      def endpoint_url
        if @options['prepare_only'] == "1"
          MoneybookersGateway::TEST_URL
        else
          MoneybookersGateway::LIVE_URL
        end
      end

      def redirect_url
        "#{endpoint_url}?sid=#{@result.token}"
      end

      #      private
      def setup_options options
        {
          'status_url'        => options[:return_url],
          'status_url2'       => options[:notification_url],
          'language'          => two_letter_code(options[:language]),
          'confirmation_note' => options[:confirmation_note],
          'logo_url'          => options[:logo_url],
          'prepare_only'      => prepare_only?(options),
          'merchant_fields'   => merchant_fields(options)
        }
      end

      def two_letter_code language
        language
      end

      # API expects 1 or 0.
      def prepare_only? options
        options[:test] ? "1" : "0"
      end

      # API takes only the first 5 paramenters into account
      def merchant_fields options
        if options[:merchant_fields]
          fields = options[:merchant_fields].split(",").map(&:strip)
          warn_for_excessive_custom_parameters if fields.size > 5
          fields.first(5)
        else
          nil
        end
      end

      def warn_for_excessive_custom_parameters
        logger.warn("Moneybookers API takes only 5 custom fields into account")
      end
    end

    class MoneybookersGateway < Gateway
      # TODO support https post request
      TEST_URL = 'http://www.moneybookers.com/app/test_payment.pl'
      LIVE_URL = 'http://www.moneybookers.com/app/payment.pl'
      API_URL  = 'http://www.moneybookers.com/app/query.pl'

      # Moneybookers API version
      # September 03, 2009
      API_VERSION = "6.8"

      class << self
        # TODO check additional supported countries
        supported_countries = ['DE']
        # TODO check additional supported card types
        supported_cardtypes = [:visa, :master, :american_express]
        homepage_url        = LIVE_URL # Gateway homepage URL
        test_redirect_url   = TEST_URL # Gateway test URL
        money_format        = :cents   # 100 is 1.00 Euro
        default_currency    = 'EUR'
        display_name        = 'Moneybookers Payment Gateway'
      end

      attr_reader :request, :response

      # The email address of the Merchant's moneybookers.com account
      # is mandatory. You won't need anything else.
      def initialize(options = {})
        requires!(options, :pay_to_email)
        @options = options
        @request = {}
        super
      end

      def setup_purchase(amount)
        requires!(@options, :return_url, :cancel_url)
        @request = MoneybookersRequest.new(@options)
        @response  = request.commit
      end

      def checkout_url
        @request && @response && @request.redirect_url
      end
    end
  end
end

