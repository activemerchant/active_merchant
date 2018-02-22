module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaylaneGateway < Gateway
      self.test_url = self.live_url = 'https://direct.paylane.com/rest/'
      class_attribute :token_url
      self.token_url = 'https://direct.paylane.com/rest.js/'

      # here is the list of supported countries: http://paylane.com/support/faq/offer/do-you-accept-merchants-from-my-country/
      # but it can be extended anytime (you just need to contact paylane at http://paylane.com/contact/)
      # the same is for supported currencies
      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :maestro]

      self.homepage_url = 'http://paylane.com/'
      self.display_name = 'PayLane Gateway'

      STANDARD_ERROR_CODE_MAPPING = {
          411 => :invalid_number,
          412 => :invalid_expiry_date,
          413 => :invalid_expiry_date,
          414 => :invalid_expiry_date,
          416 => :invalid_cvc,
          415 => :expired_card,
          479 => :expired_card,
          317 => :incorrect_zip,
          422 => :incorrect_zip,
          420 => :incorrect_address,
          303 => :card_declined,
          502 => :processing_error,
          402 => :processing_error,
          503 => :config_error,
          505 => :config_error,
          404 => :unsupported_feature,
          405 => :unsupported_feature,
          406 => :unsupported_feature,
          407 => :unsupported_feature,
          408 => :unsupported_feature,
          409 => :unsupported_feature
      }.freeze

      def initialize(options={})
        requires!(options, :login, :password, :apikey)
        @login = options[:login]
        @password = options[:password]
        @apikey = options[:apikey]
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_customer_data(post, options)
        add_payment(post, payment)
        paymentPath = get_payment_path(payment)

        commit(paymentPath, post)
      end

      def authorize(money, payment, options={})
        # only authorization happens, no amount is actually captured
        # after authorization transaction can be voided (closed)
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit('cards/authorization', post)
      end

      def capture(money, authorization, _options={})
        # actually captures given amount from authorized card
        post = {}
        post[:id_authorization] = authorization
        post[:amount] = amount(money)
        commit('authorizations/capture', post)
      end

      def refund(money, authorization, options={})
        post = {}
        post[:id_sale] = authorization
        post[:amount] = amount(money)
        post[:reason] = options[:reason]
        commit('refunds', post)
      end

      def void(authorization, _options={})
        # closes transaction which is authorized but not yet captured
        post = {}
        post[:id_authorization] = authorization
        commit('authorizations/close', post)
      end

      def verify(credit_card, options={})
        amount = options[:amount] ? options[:amount] : 100
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
            gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
            gsub(%r(("card_number\\?":\\?")\d+), '\1[FILTERED]').
            gsub(%r(("card_code\\?":\\?")\d+), '\1[FILTERED]')
      end

      def get_token(credit_card, options={})
        #returned token is valid for 15 minutes
        post = {}
        fill_card_data(post, credit_card)
        post[:public_api_key] = @apikey
        commit('cards/generateToken', post)
      end

      private

      def add_customer_data(post, options)
        post[:customer] = {}
        post[:customer][:ip] = options[:ip]
        post[:customer][:email] = options[:email]
        billing_address = options[:billing_address] || options[:address]
        post[:customer][:address] = {}
        post[:customer][:address][:street_house] = billing_address[:address1]
        post[:customer][:address][:city] = billing_address[:city]
        post[:customer][:address][:state] = billing_address[:state]
        post[:customer][:address][:zip] = billing_address[:zip]
        post[:customer][:address][:country_code] = billing_address[:country]
      end

      def add_invoice(post, money, options)
        post[:sale] = {}
        post[:sale][:amount] = amount(money)
        post[:sale][:currency] = (options[:currency] || currency(money))
        post[:sale][:description] = options[:description]
        if options[:fraud_check_on]
          post[:sale][:fraud_check_on] = options[:fraud_check_on]
        end
        if options[:avs_check_level]
          post[:sale][:avs_check_level] = options[:avs_check_level]
        end
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          # card token obtained via get_token method
          post[:card] = {}
          post[:card][:token] =  payment
        elsif payment.is_a?(Hash)
          # Paylane calls it "Direct Debit" payment
          post[:account] = {}
          post[:account][:account_holder] = payment[:account][:account_holder]
          post[:account][:account_country] =  payment[:account][:account_country]
          post[:account][:iban] = payment[:account][:iban]
          post[:account][:bic] = payment[:account][:bic]
          post[:account][:mandate_id] = payment[:account][:mandate_id]
        else
          post[:card] = {}
          fill_card_data(post[:card], payment)
        end
      end

      def get_payment_path(payment)
        if payment.is_a?(String) # payment via token
          "cards/saleByToken"
        elsif payment.is_a?(Hash) # Direct Debit (account)
          "directdebits/sale"
        else
          "cards/sale" # normal sale with standard card data
        end
      end

      def fill_card_data(card_obj, payment)
        card_obj[:card_number] = payment.number
        card_obj[:expiration_month] = sprintf('%02d', payment.month)
        card_obj[:expiration_year] = payment.year.to_s
        card_obj[:name_on_card] = "#{payment.first_name} #{payment.last_name}"
        card_obj[:card_code] = payment.verification_value
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        json_error()
      end

      def basic_auth
        Base64.strict_encode64("#{@login}:#{@password}")
      end

      def request_headers
        {
            "Content-Type" => "application/json",
            "Authorization" => "Basic #{basic_auth}"
        }
      end

      def commit(action, parameters)
        # for some non-obvious reason Paylane has different API url for token generation (and only for it)...
        if action.include? "generateToken"
          url = "#{token_url}#{action}"
        else
          url = "#{(test? ? test_url : live_url)}#{action}"
        end

        begin
          raw_response = ssl_post(url, post_data(parameters), request_headers)
        rescue ResponseError => e
          raw_response = response_error(e.response.code, e.response.message)
        end

        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["avs_result"]),
          cvv_result: CVVResult.new(nil), # paylane does not support CVV results, so always nil
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['success']
      end

      def message_from(response)
        if success_from(response)
          "success"
        else
          response['error']['error_description']
        end
      end

      def authorization_from(response)
        return response['id_authorization'] if response['id_authorization']
        return response['id_sale'] if response['id_sale']
        nil
      end

      def post_data(parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          code = response['error']['error_number']
          if STANDARD_ERROR_CODE_MAPPING.include?(code)
            return STANDARD_ERROR_CODE[STANDARD_ERROR_CODE_MAPPING[code]]
          else
            return code
          end
        end
      end

      def error_obj(err_no, err_msg)
        {
            "success" => false,
            "error" => {
                "error_number" => err_no,
                "error_description" => err_msg
            }
        }
      end

      def response_error(code, msg)
        JSON.dump(error_obj(code, msg))
      end

      def json_error()
        error_obj(-1, "Cannot parse JSON")
      end

    end
  end
end
