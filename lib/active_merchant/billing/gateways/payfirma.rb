module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayfirmaGateway < Gateway
      self.default_currency = 'CAD'
      self.display_name = 'Payfirma'
      self.homepage_url = 'https://www.payfirma.com/'
      self.live_url  = 'https://ecom.payfirma.com/'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.supported_countries = ['CA', 'US']

      CURRENCY_TRANSLATOR = {
        'CAD' => 'CA$',
        'USD' => 'US$'
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, credit_card_or_payment_token, options = {})
        params = {}
        add_amount(params, money, options)
        add_credit_card_or_payment_token(params, credit_card_or_payment_token, options)
        commit(:post, 'authorize', params, options)
      end

      def capture(money, authorization, options = {})
        params = {}
        add_amount(params, money, options)
        commit(:post, "capture/#{CGI.escape(authorization)}", params, options)
      end

      def purchase(money, credit_card_or_payment_token, options = {})
        params = {}
        add_amount(params, money, options)
        add_description(params, options)
        add_credit_card_or_payment_token(params, credit_card_or_payment_token, options)
        commit(:post, 'sale', params, options)
      end

      def refund(money, identification, options = {})
        params = {}
        add_amount(params, money, options)
        commit(:post, "refund/#{CGI.escape(identification)}", params, options)
      end

      def store(credit_card, options = {})
        requires!(options, :email)

        params = {}
        add_email(params, options)
        add_credit_card(params, credit_card, options)
        commit(:post, 'vault', params, options)
      end

      def unstore(payment_token, options = {})
        params = {}
        add_payment_token(params, payment_token, options)
        commit(:delete, 'vault', params, options)
      end

      private

      def add_amount(params, money, options, include_currency = false)
        currency = options[:currency] || currency(money)
        params[:amount] = localized_amount(money, currency)
        params[:currency] = CURRENCY_TRANSLATOR[currency] if include_currency
      end

      def add_description(params, options)
        params[:description] = options[:description] if options[:description]
      end

      def add_email(params, options)
        params[:email] = options[:email] if options[:email]
      end

      def add_credit_card_or_payment_token(params, credit_card_or_payment_token, options)
        if credit_card_or_payment_token.is_a?(String)
          add_payment_token(params, credit_card_or_payment_token, options)
        else
          add_credit_card(params, credit_card_or_payment_token, options)
        end
      end

      def add_credit_card(params, credit_card, options)
        params[:card_number] = credit_card.number
        params[:card_expiry_month] = credit_card.month
        params[:card_expiry_year] = credit_card.year
        params[:cvv2] = credit_card.verification_value if credit_card.verification_value?

        if credit_card.name
          first_name, last_name = credit_card.name.split(' ', 2)

          params[:first_name] = first_name if first_name
          params[:last_name] = last_name if last_name
        end
      end

      def add_payment_token(params, payment_token, options)
        lookupid, card_lookup_id = payment_token.split('|')

        params[:lookupid] = lookupid
        params[:card_lookup_id] = card_lookup_id if card_lookup_id
      end

      def post_data(params)
        params.reject { |_, value| value.blank? }.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end

      def headers(options)
        {
          'User-Agent' => user_agent
        }
      end

      def commit(method, endpoint, params, options)
        params[:merchant_id] = @options[:login]
        params[:key] = @options[:password]
        params[:test_mode] = 'true' if test?

        begin
          url = "#{self.live_url}#{endpoint}"
          url = "#{url}/#{params.delete(:lookupid)}" if params[:lookupid]

          case method
          when :delete
            url = url + "?" + post_data(params)
          else
            data = post_data(params)
          end

          raw_response = ssl_request(method, url, data, headers(options))
        rescue ResponseError => e
          raw_response = e.response.body
        end

        response = JSON.parse(raw_response) rescue {}

        Response.new(
          successful?(response),
          message_from(response),
          response,
          test: test?,
          avs_result: { code: response['avs'] },
          cvv_result: response['cvv2'],
          authorization: authorization_from(response)
        )
      end

      def successful?(response)
        !!response['result_bool'] || !!response['lookupid']
      end

      def message_from(response)
        response['message'] || response['error']
      end

      def authorization_from(response)
        if response.key?('lookupid')
          [response['lookupid'], response['cards'].last['card_lookup_id']].reject(&:nil?).join('|')
        else
          response['transaction_id'] || response['id']
        end
      end
    end
  end
end
