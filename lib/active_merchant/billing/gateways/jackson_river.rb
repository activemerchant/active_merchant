require 'active_support'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class JacksonRiverGateway < Gateway
      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.jacksonriver.com/'
      self.display_name = 'Jackson River'

      def initialize(options={})
        requires!(options, :hostname, :api_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        add_metadata(post, options)

        commit('sale', post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((&?api_key=)([a-zA-Z0-9]+)(&))i, '\1[FILTERED]\3').
          gsub(%r((&?card_number=)(\d+)(&))i, '\1[FILTERED]\3')
      end

      private

      def add_customer_data(post, options)
        post[:first_name] = options[:first_name]
        post[:last_name]  = options[:last_name]
        post[:mail]       = options[:email] if options[:email]
      end

      def add_address(post, options)
        address = options[:billing_address] || options[:address]
        post[:address]        = address[:address1] if address[:address1]
        post[:address_line_2] = address[:address2] if address[:address2]
        post[:city]           = address[:city]     if address[:city]
        post[:state]          = address[:state]    if address[:state]
        post[:zip]            = address[:zip]      if address[:zip]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money).to_s # yup Jackson River wants it as a string :(
        post[:currency] = (options[:currency] || currency(money))
        post[:recurs_monthly] = 'recurs' if options[:recurring]
      end

      def add_payment(post, payment)
        post[:payment_method] = 'credit'
        post[:card_number] = payment.number
        post[:card_expiration_month] = payment.month
        post[:card_expiration_year]  = format(payment.year, :four_digits)
      end

      def add_metadata(post, options = {})
        post[:ms] = options[:market_source] if options[:market_source]
      end

      def parse(body)
        body.blank? ? {} : JSON.parse(body)
      end

      def headers
        {
          'Content-Type' => 'application/x-www-form-urlencoded; charset=utf-8',
          'Accept' => 'application/json',
          'User-Agent' => "Evergiving v2.0/AM #{ActiveMerchant::VERSION}",
          'Authorization' => encoded_credentials,
        }.reject { |_,v| v.blank? }
      end

      def encoded_credentials
        # the basic auth is only applicable to development
        # $*%*&^$ :-(
        return unless test?
        credentials = "#{@options[:test_user]}:#{@options[:test_password]}"
        "Basic " << Base64.strict_encode64(credentials).strip
      end

      def url(options = {})
        params = { form_id: options[:form_id], offline: true, api_key: @options[:api_key] }
        
        "#{@options[:hostname]}?#{params.to_query}"
      end

      def commit(action, parameters, options = {})
        response = begin
          parse(ssl_post(url(options), post_data(action, parameters), headers))
        rescue ResponseError => e
          if e.response.code == "401"
            return Response.new(false, "Invalid Login", test: test?)
          elsif ["406", "500"].include?(e.response.code)
            message = JSON.parse(e.response.body)
            return Response.new(false, message_from(message), test: test?)
          end            
        end

        Response.new(
          success_from(response),
          message_from(response),
          response.first,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response.length == 1 &&
          response.first.is_a?(Hash) &&
          response.first.key?('status') &&
          response.first['status'] == 'Submission successful'
      end

      def message_from(response)
        success_from(response) ? response.first['status'] : response.first
      end

      def authorization_from(response)
        response.first['submission_id'] if success_from(response)
      end

      def post_data(action, parameters = {})
        parameters.to_query
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
