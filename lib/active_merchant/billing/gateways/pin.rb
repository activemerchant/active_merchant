module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PinGateway < Gateway
      self.test_url = 'https://test-api.pin.net.au/1'
      self.live_url = 'https://api.pin.net.au/1'

      self.default_currency = 'AUD'
      self.money_format = :cents
      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master]
      self.homepage_url = 'http://www.pin.net.au/'
      self.display_name = 'Pin'

      def initialize(options = {})
        requires!(options, :api_key)
        super
      end

      # Create a charge using a credit card, card token or customer token
      #
      # To charge a credit card: purchase([money], [creditcard hash], ...)
      # To charge a customer: purchase([money], [token], ...)
      def purchase(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_customer_data(post, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)

        commit('charges', post, options)
      end

      # Create a customer and associated credit card. The token that is returned
      # can be used instead of a credit card parameter in the purchase method
      def store(creditcard, options = {})
        post = {}

        add_creditcard(post, creditcard)
        add_customer_data(post, options)
        add_address(post, creditcard, options)
        commit('customers', post, options)
      end

      # Refund a transaction, note that the money attribute is ignored at the
      # moment as the API does not support partial refunds. The parameter is
      # kept for compatibility reasons
      def refund(money, token, options = {})
        commit("charges/#{CGI.escape(token)}/refunds", { :amount => amount(money) }, options)
      end

      private
      def add_amount(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:currency] = post[:currency].upcase if post[:currency]
      end

      def add_customer_data(post, options)
        post[:email] = options[:email]
        post[:ip_address] = options[:ip]
      end

      def add_address(post, creditcard, options)
        return if creditcard.kind_of?(String)
        address = (options[:billing_address] || options[:address])
        return unless address

        post[:card] ||= {}
        post[:card].merge!(
          :address_line1 => address[:address1],
          :address_city => address[:city],
          :address_postcode => address[:zip],
          :address_state => address[:state],
          :address_country => address[:country]
        )
      end

      def add_invoice(post, options)
        post[:description] = options[:description] || "Active Merchant Purchase"
      end

      def add_creditcard(post, creditcard)
        if creditcard.respond_to?(:number)
          post[:card] ||= {}

          post[:card].merge!(
            :number => creditcard.number,
            :expiry_month => creditcard.month,
            :expiry_year => creditcard.year,
            :cvc => creditcard.verification_value,
            :name => "#{creditcard.first_name} #{creditcard.last_name}"
          )
        elsif creditcard.kind_of?(String)
          if creditcard =~ /^card_/
            post[:card_token] = creditcard
          else
            post[:customer_token] = creditcard
          end
        end
      end

      def headers(params = {})
        result = {
          "Content-Type" => "application/json",
          "Authorization" => "Basic #{Base64.strict_encode64(options[:api_key] + ':').strip}"
        }

        result['X-Partner-Key'] = params[:partner_key] if params[:partner_key]
        result['X-Safe-Card'] = params[:safe_card] if params[:safe_card]
        result
      end

      def commit(action, params, options)
        url = "#{test? ? test_url : live_url}/#{action}"

        begin
          body = parse(ssl_post(url, post_data(params), headers(options)))
        rescue ResponseError => e
          body = parse(e.response.body)
        end

        if body["response"]
          success_response(body)
        elsif body["error"]
          error_response(body)
        end
      end

      def success_response(body)
        response = body["response"]
        Response.new(
          true,
          response['status_message'],
          body,
          :authorization => token(response),
          :test => test?
        )
      end

      def error_response(body)
        Response.new(
          false,
          body['error_description'],
          body,
          :authorization => nil,
          :test => test?
        )
      end

      def token(response)
        response['token']
      end

      def parse(body)
        JSON.parse(body)
      end

      def post_data(parameters = {})
        parameters.to_json
      end
    end
  end
end
