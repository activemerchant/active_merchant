module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WhiteGateway < Gateway
      self.live_url = 'https://api.whitepayments.com'
      self.supported_countries = %w(AE)
      self.default_currency = 'AED'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'https://whitepayments.com'
      self.display_name = 'White'

      def initialize(options = {})
        requires!(options, :login)

        super
      end

      def purchase(money, payment_method, options = {})
        post = create_post_for_auth_or_purchase(money, payment_method, options)
        post[:capture] = 'true'
        commit(:post, '/charges', post, options)
      end

      def authorize(money, payment_method, options = {})
        post = create_post_for_auth_or_purchase(money, payment_method, options)
        post[:capture] = 'false'
        commit(:post, '/charges', post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_amount(post, money, options, false)
        commit(:post, "/charges/#{CGI.escape(authorization)}/capture", post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_amount(post, money, options, false)
        post[:reason] = options[:reason]
        commit(:post, "/charges/#{CGI.escape(authorization)}/refunds", post)
      end

      def store(payment_method, options = {})
        post = {}

        add_payment_method(post, payment_method, options)
        add_customer(post, options)

        commit(:post, "/customers/", post)
      end

      private

      def create_post_for_auth_or_purchase(money, payment_method, options)
        post = {}

        add_amount(post, money, options, true)
        add_payment_method(post, payment_method, options)

        post[:email] = options[:email]
        post[:ip] = options[:ip]
        post[:description] = options[:description]
        post[:statement_descriptor] = options[:statement_descriptor]

        post
      end

      def add_amount(post, money, options, include_currency = true)
        currency = options[:currency] || currency(money)
        post[:amount] = localized_amount(money, currency)
        post[:currency] = currency if include_currency
      end

      def add_payment_method(post, payment_method, options)
        case payment_method
        when /\Atok_/ then add_card_token(post, payment_method)
        when /\Acus_/ then add_customer_card(post, payment_method, options)
        else
          add_card_params(post, payment_method)
        end
      end

      def add_card_params(post, credit_card)
        post[:card] = {
          number: credit_card.number,
          exp_month: credit_card.month,
          exp_year: credit_card.year,
          name: credit_card.name,
          cvc: credit_card.verification_value
        }
      end

      def add_card_token(post, token)
        post[:card] = token
      end

      def add_customer_card(post, customer_id, options)
        post[:customer_id] = customer_id
        post[:card] = options[:card_id] if options[:card_id]
      end

      def add_customer(post, options)
        post.update({
          email:       options[:email],
          ip:          options[:ip],
          description: options[:description]
        })
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers()
        key     = options[:login]

        headers = {
          "Content-Type"  => "application/json",
          "Authorization" => "Basic " + Base64.encode64(key.to_s + ":").strip,
          "User-Agent" => "White ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "X-Client-User-Agent" => user_agent
        }

        headers
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, self.live_url + endpoint, parameters.to_json, headers)
          response = parse(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def commit(method, url, parameters = nil, options = {})
        begin
          response = api_request(method, url, parameters, options)
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        success = !response.key?("error")

        Response.new(
          success,
          message_from(response),
          response,
          test: test?,
          authorization: authorization_from(response),
          error_code: error_code_from(response)
        )
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the White API.  Please contact support@whitepayments.com if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end

      def message_from(response)
        !response["error"] ? "Transaction processed" : error_message(response)
      end

      def authorization_from(response)
        response["error"] ? response["error"]["extras"]["charge"] : response["id"]
      end

      def error_code_from(response)
        response["error"] && response["error"]["code"]
      end

      def error_message(response)
        response["error"]["message"].tap do |message|
          return message unless response["error"]["code"] == "unprocessable_entity"

          error_messages = []

          response["error"]["extras"].each do |attr, errors|
            case errors
            when Hash  then error_messages += messages_for_hash(errors)
            when Array then error_messages << message_for_array(attr, errors)
            end
          end

          message << " #{error_messages.map(&:capitalize).join(". ")}" if error_messages.any?
        end
      end

      def message_for_array(attr, errors)
        "#{attr}: #{errors.join(", ")}"
      end

      def messages_for_hash(errors_hash)
        [].tap do |messages|
          errors_hash.each do |attr, errors|
            messages << message_for_array(attr, errors)
          end
        end
      end
    end
  end
end
