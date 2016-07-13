module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IuguGateway < Gateway
      self.live_url = 'https://api.iugu.com/v1/'

      self.supported_countries = %w(BR)
      self.default_currency = 'BRL'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'https://iugu.com/'
      self.display_name = 'Iugu'

      def initialize(options = {})
        requires!(options, :login)
        @api_key = options[:login]

        super
      end

      def authorize(money, payment, options = {})
        token = request_payment_token(payment, options)
        post = create_post_for_auth(money, token, options)
        commit(:post, 'charge', post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        commit(:post, "invoices/#{authorization}/capture", post, options)
      end

      # To create a charge on a card or a token, call
      #
      #   purchase(money, card_or_token, { ... })
      #
      # To create a bank_slip (boleto) on a customer, call
      #
      #   purchase(money, nil, { :customer => id, ... })
      def purchase(money, payment, options = {})
        response = authorize(money, payment, options)
        return response unless response.success?
        capture(money, response.authorization, options)
      end

      def store(payment, options = {})
        response = store_client(options)
        customer_id = response.params['id']

        post = { description: options[:description],
                 token: request_payment_token(payment, options) }

        add_optional(post, options, :set_as_default)
        commit(:post, "customers/#{customer_id}/payment_methods", post)
      end

      def unstore(options = {})
        commit(:delete, "customers/#{options[:customer_id]}/payment_methods/#{options[:id]}")
      end

      def store_client(options = {})
        post = {}
        add_customer(post, options)

        commit(:post, "customers", post)
      end

      def unstore_client(options = {})
        commit(:delete, "customers/#{options[:id]}")
      end

      def request_payment_token(payment, options = {})
        if payment.is_a?(CreditCard)
          post = { test: test?(options), method: 'credit_card' }
          add_creditcard(post, payment)
          response = commit(:post, "payment_token", post, options)
          response.params['id']
        else
          payment
        end
      end

      private
      def create_post_for_auth(money, payment, options)
        post = {}

        add_address(post, options)
        add_payer(post, options)

        if payment.present?
          post['token'] = payment
        else
          post['method'] = 'bank_slip'
        end

        unless post.has_key?(:invoice_id)
          post['email'] = options[:email]
          add_amount(post, options)
        end

        add_optional(post, options, :invoice_id, :customer_id, :months,
                     :discount_cents, :bank_slip_extra_days)

        post
      end

      def add_amount(post, options)
        items = Array.wrap(options[:items])
        post["items"] = items
      end

      def add_customer(post, options)
        post['email'] = options[:email]
        add_optional(post, options, :name, :cpf_cnpj, :cc_emails, :notes)
      end

      def add_payer(post, options)
        payer = options[:payer]
        post['payer[cpf_cnpj]'] = payer[:cpf_cnpj]
        post['payer[name]'] = payer[:name]
        post['payer[phone_prefix]'] = payer[:phone_prefix]
        post['payer[phone]'] = payer[:phone]
        post['payer[email]'] = payer[:email]
      end

      def add_address(post, options)
        address = options[:billing_address] || options[:address] || {}
        post["payer[address][street]"] = address[:street]
        post["payer[address][number]"] = address[:number]
        post["payer[address][city]"] = address[:city]
        post["payer[address][state]"] = address[:state]
        post["payer[address][country]"] = address[:country]
        post["payer[address][zip_code]"] = address[:zip_code]
      end

      def add_optional(post, options, *params)
        params.each do |param|
          param = String(param)
          post[param] =  options[param.to_sym] if options.has_key?(param.to_sym)
        end
      end

      def add_creditcard(post, creditcard)
        if creditcard.respond_to?(:number)
          post['data[number]'] = creditcard.number
          post['data[month]'] = creditcard.month
          post['data[year]'] = creditcard.year
          post['data[verification_value]'] = creditcard.verification_value
          post['data[first_name]'] = creditcard.first_name
          post['data[last_name]'] = creditcard.last_name
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers(options = {})
        key = options[:key] || @api_key
        {
          'authorization' => 'Basic ' + Base64.encode64(key.to_s + ":"),
          'accept' => 'application/json',
          'accept_charset' => 'utf-8',
          'user_agent' => 'Iugu ActiveMerchant',
          'accept_language' => 'pt-br;q=0.9,pt-BR',
          'content_type' => 'application/json; charset=utf-8'
        }
      end

      def api_version(options)
        options[:version] || @options[:version] || "V1"
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        parameters = parameters.to_query if parameters.present?
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, self.live_url + endpoint, parameters, headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def commit(method, url, parameters = nil, options = {})
        response = api_request(method, url, parameters, options)

        success = success_from_response(response)
        message = message_from_response(response)

        Response.new(success, message, response,
          :test => test?(options),
          :authorization => authorization_from(success, url, method, response)
        )
      end

      def authorization_from(success, url, method, response)
        return humanize_errors(response['errors']) unless success
        response['id'] || response['invoice_id']
      end

      def humanize_errors(errors)
        return errors if errors.is_a?(String)
        errors = errors.map do |key, value|
          key = String(key)
          "#{key.humanize}: #{value.join(', ')}"
        end
        errors.join(', ')
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Iugu API.'
        msg += " (The raw response returned by the API was #{raw_response.inspect})"
        {
          "errors" => {
            "message" => msg
          }
        }
      end

      def test?(options)
        options[:test]
      end

      def success_from_response(response)
        if response.key?("success")
          response["success"]
        elsif response['message'] == "Transação negada"
          false
        else
          !(response["errors"] && response["errors"].present?)
        end
      end

      def message_from_response(response)
        if response['message']
          response['message']
        elsif response['errors']
          humanize_errors(response['errors'])
        else
          ''
        end
      end

      def parse_date(date_or_string)
        date = date_or_string.is_a?(String) ? Date.parse(date_or_string) : date_or_string.to_date
        date.strftime('%d/%m/%Y')
      end
    end
  end
end

