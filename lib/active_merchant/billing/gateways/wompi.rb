module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WompiGateway < Gateway
      self.test_url = 'https://sandbox.wompi.co/v1'
      self.live_url = 'https://production.wompi.co/v1'

      self.supported_countries = ['CO']
      self.default_currency = 'COP'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://wompi.co/'
      self.display_name = 'Wompi'

      self.money_format = :cents

      PAYMENT_SOURCE_TYPES = %w[CARD NEQUI]

      def initialize(options = {})
        requires!(options, :public_key, :private_key)

        super
      end

      def query_acceptance_token
        action = "/merchants/#{@options[:public_key]}"

        commit(:get, action)
      end

      def store(payment_method, options = {})
        post = {}

        post[:number] = payment_method.number
        post[:cvc] = payment_method.verification_value
        post[:exp_month] = format(payment_method.month, :two_digits)
        post[:exp_year] = format(payment_method.year, :two_digits)
        post[:card_holder] = payment_method.name

        commit(:post, '/tokens/cards', post)
      end

      def payment_sources(options = {})
        post = {}

        post[:type] = 'CARD'
        post[:token] = options[:token]
        post[:customer_email] = options.dig(:customer, :email)
        post[:acceptance_token] = query_acceptance_token.authorization

        commit(:post, '/payment_sources', post)
      end

      def capture(money, payment, options = {})
        post = {}
        post[:acceptance_token] = query_acceptance_token.authorization

        add_invoice(post, money, options)
        add_address(post, payment, options)
        add_customer_data(post, options)
        add_payment(post, payment, options.merge(token: options[:token]))

        commit(:post, '/transactions', post)
      end

      def purchase(money, payment, options = {})
        MultiResponse.run do |r|
          r.process { store(payment, options) }

          r.process do
            capture(money, payment, options.merge(token: r.authorization))
          end
        end
      end

      # Lookup transaction using reference or using transaction id path parans
      #
      def query_transaction(reference, options = {})
        if options[:path_params] && reference.present?
          commit(:get, "/transactions/#{reference}")
        else
          commit(:get, "/transactions?reference=#{reference}")
        end
      end

      def pse_financial_institutions
        commit(:get, '/pse/financial_institutions')
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/\b(Authorization:\s+Bearer\s+)\S+/, '\1[FILTERED]')
          .gsub(/(\\?\\?\\?"number\\?\\?\\?":\\?\\?\\?")\d+/, '\1[FILTERED]')
          .gsub(/(\\?\\?\\?"cvc\\?\\?\\?":\\?\\?\\?"?)\d+/, '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:customer_data] = {}
        post[:customer_data][:phone_number] = options.dig(:customer, :mob_phone)
        post[:customer_data][:full_name] = options.dig(:customer, :full_name)
        post[:customer_email] = options.dig(:customer, :email)
        post[:redirect_url] = options[:redirect_url]
      end

      def add_address(post, creditcard, options)
        post[:shipping_address] = add_address_data(options)
      end

      def add_address_data(options)
        address = {}

        if options[:address].present?
          address[:address_line_1] = options[:address][:address1]
          address[:address_line_2] = options[:address][:address2]
          address[:city] = options[:address][:city]
          address[:region] = options[:address][:state]
          address[:name] = options[:customer]&.[](:full_name)
          address[:phone_number] = options[:customer]&.[](:mob_phone)
          address[:postal_code] = options[:address][:postal_code]
          address[:country] = options[:address][:country]
        end

        address
      end

      def add_invoice(post, money, options)
        post[:amount_in_cents] = amount(money).to_i
        post[:currency] = (options[:currency] || currency(money))
        post[:reference] = options[:reference]
      end

      def add_payment(post, payment, options)
        post[:payment_method] = {}
        post[:type] = 'CARD'
        post[:payment_method][:type] = 'CARD'
        post[:payment_method][:token] = options[:token]
        post[:payment_method][:installments] = options[:installments] || 1
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers(action)
        key = reference_in_params?(action) ? :private_key : :public_key
        token = @options.send(:[], key)

        {
          'accept' => '*/*',
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{token}",
        }
      end

      def commit(verb, action, parameters = {})
        endpoint = url + action

        begin
          params = post_data(action, parameters)
          response = parse(ssl_request(verb, endpoint, params, headers(action)))
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        success = success_from(action, response)

        Response.new(
          success,
          message_from(success, action, response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(success, response),
        )
      end

      def success_from(action, response)
        case action
        when '/tokens/cards'
          response['status'] == 'CREATED'
        when %r{\/merchants\/pub_(test|prod)_.+}
          response.dig('data', 'presigned_acceptance', 'acceptance_token')
        when '/transactions'
          data = response['data']
          response_data = data.is_a?(Array) ? data.first : data
          # PENDING transactions returns as not success
          ['APPROVED'].include?(response_data&.[]('status'))

        when '/pse/financial_institutions'
          response['data'].is_a?(Array) && !response['data'].empty?
        end
      end

      def message_from(success, endpoint, response)
        case endpoint
        when '/tokens/cards'
          if success
            response.fetch('status')
          else
            response.dig('error', 'messages').map do |k, v|
              "#{k}: #{v.join}"
            end.join
          end
        when %r{\/merchants\/pub_(test|prod)_\w+}
          response.dig('data', 'presigned_acceptance', 'acceptance_token')
        when '/pse/financial_institutions'
          if response['data'].is_a?(Array) && !response['data'].empty?
            'APPROVED'
          end
        else
          data = response['data']
          response_data = data.is_a?(Array) ? data.first : data

          response_data&.[]('status')
        end
      end

      def authorization_from(endpoint, response)
        case endpoint
        when %r{\/merchants\/pub_(test|prod)_.+}
          response['data']['presigned_acceptance']['acceptance_token']
        else
          data = response['data']
          response_data = data.is_a?(Array) ? data.first : data

          response_data&.[]('id')
        end
      end

      def post_data(action, parameters = {})
        parameters.empty? ? nil : parameters.to_json
      end

      def error_code_from(success, response)
        unless success
          error_type = response['error']&.[]('type')

          data = response['data']
          response_data = data.is_a?(Array) ? data.first : data

          error_type || response_data&.[]('status')
        end
      end

      def url
        test? ? test_url : live_url
      end

      def reference_in_params?(action)
        action_uri = URI(action)
        path_params_ref?(action_uri.path) || query_string_ref?(action_uri.query)
      end

      def path_params_ref?(action)
        action =~ %r{\/transactions\/[^\s]+}
      end

      def query_string_ref?(query)
        query && CGI.parse(query).has_key?('reference')
      end
    end
  end
end
