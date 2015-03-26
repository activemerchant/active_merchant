module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymillGateway < Gateway
      self.supported_countries = %w(AD AT BE BG CH CY CZ DE DK EE ES FI FO FR GB
                                    GI GR HR HU IE IL IM IS IT LI LT LU LV MC MT
                                    NL NO PL PT RO SE SI SK TR VA)

      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover, :union_pay, :jcb]
      self.homepage_url = 'https://paymill.com'
      self.display_name = 'PAYMILL'
      self.money_format = :cents
      self.default_currency = 'EUR'

      def initialize(options = {})
        requires!(options, :public_key, :private_key)
        super
      end

      def purchase(money, payment_method, options = {})
        action_with_token(:purchase, money, payment_method, options)
      end

      def authorize(money, payment_method, options = {})
        action_with_token(:authorize, money, payment_method, options)
      end

      def capture(money, authorization, options = {})
        post = {}

        add_amount(post, money, options)
        post[:preauthorization] = preauth(authorization)
        post[:description] = options[:description]
        post[:source] = 'active_merchant'
        commit(:post, 'transactions', post)
      end

      def refund(money, authorization, options={})
        post = {}

        post[:amount] = amount(money)
        post[:description] = options[:description]
        commit(:post, "refunds/#{transaction_id(authorization)}", post)
      end

      def void(authorization, options={})
        commit(:delete, "preauthorizations/#{preauth(authorization)}")
      end

      def store(credit_card, options={})
        save_card(credit_card)
      end

      private

      def add_credit_card(post, credit_card)
        post['account.number'] = credit_card.number
        post['account.expiry.month'] = sprintf("%.2i", credit_card.month)
        post['account.expiry.year'] = sprintf("%.4i", credit_card.year)
        post['account.verification'] = credit_card.verification_value
      end

      def headers
        { 'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:private_key]}:X").chomp) }
      end

      def commit(method, url, parameters=nil)
        begin
          raw_response = ssl_request(method, "https://api.paymill.com/v2/#{url}", post_data(parameters), headers)
        rescue ResponseError => e
          begin
            parsed = JSON.parse(e.response.body)
          rescue JSON::ParserError
            return Response.new(false, "Unable to parse error response: '#{e.response.body}'")
          end
          return Response.new(false, response_message(parsed), parsed, {})
        end

        response_from(raw_response)
      end

      def response_from(raw_response)
        parsed = JSON.parse(raw_response)
        options = {
          :authorization => authorization_from(parsed),
          :test => (parsed['mode'] == 'test'),
        }

        succeeded = (parsed['data'] == []) || (parsed['data']['response_code'].to_i == 20000)
        Response.new(succeeded, response_message(parsed), parsed, options)
      end

      def authorization_from(parsed_response)
        parsed_data = parsed_response['data']
        return '' unless parsed_data.kind_of?(Hash)

        [
          parsed_data['id'],
          parsed_data['preauthorization'].try(:[], 'id')
        ].join(";")
      end

      def action_with_token(action, money, payment_method, options)
        case payment_method
        when String
          self.send("#{action}_with_token", money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { save_card(payment_method) }
            r.process { self.send("#{action}_with_token", money, r.authorization, options) }
          end
        end
      end

      def purchase_with_token(money, card_token, options)
        post = {}

        add_amount(post, money, options)
        post[:token] = card_token
        post[:description] = options[:description]
        post[:source] = 'active_merchant'
        commit(:post, 'transactions', post)
      end

      def authorize_with_token(money, card_token, options)
        post = {}

        add_amount(post, money, options)
        post[:token] = card_token
        post[:description] = options[:description]
        post[:source] = 'active_merchant'
        commit(:post, 'preauthorizations', post)
      end

      def save_card(credit_card)
        post = {}

        add_credit_card(post, credit_card)
        post['channel.id'] = @options[:public_key]
        post['jsonPFunction'] = 'jsonPFunction'
        post['transaction.mode'] = (test? ? 'CONNECTOR_TEST' : 'LIVE')

        begin
          raw_response = ssl_request(:get, "#{save_card_url}?#{post_data(post)}", nil, {})
        rescue ResponseError => e
          return Response.new(false, e.response.body, e.response.body, {})
        end

        response_for_save_from(raw_response)
      end

      def response_for_save_from(raw_response)
        options = { :test => test? }

        parser = ResponseParser.new(raw_response, options)
        parser.generate_response
      end

      def parse_reponse(response)
        JSON.parse(response.sub(/jsonPFunction\(/, '').sub(/\)\z/, ''))
      end

      def save_card_url
        (test? ? 'https://test-token.paymill.com' : 'https://token-v2.paymill.de')
      end

      def post_data(params)
        return nil unless params

        no_blanks = params.reject { |key, value| value.blank? }
        no_blanks.map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_amount(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def preauth(authorization)
        authorization.split(";").last
      end

      def transaction_id(authorization)
        authorization.split(';').first
      end

      RESPONSE_CODES = {
        10001 => "General undefined response.",
        10002 => "Still waiting on something.",

        20000 => "General success response.",

        40000 => "General problem with data.",
        40001 => "General problem with payment data.",
        40100 => "Problem with credit card data.",
        40101 => "Problem with cvv.",
        40102 => "Card expired or not yet valid.",
        40103 => "Limit exceeded.",
        40104 => "Card invalid.",
        40105 => "Expiry date not valid.",
        40106 => "Credit card brand required.",
        40200 => "Problem with bank account data.",
        40201 => "Bank account data combination mismatch.",
        40202 => "User authentication failed.",
        40300 => "Problem with 3d secure data.",
        40301 => "Currency / amount mismatch",
        40400 => "Problem with input data.",
        40401 => "Amount too low or zero.",
        40402 => "Usage field too long.",
        40403 => "Currency not allowed.",

        50000 => "General problem with backend.",
        50001 => "Country blacklisted.",
        50100 => "Technical error with credit card.",
        50101 => "Error limit exceeded.",
        50102 => "Card declined by authorization system.",
        50103 => "Manipulation or stolen card.",
        50104 => "Card restricted.",
        50105 => "Invalid card configuration data.",
        50200 => "Technical error with bank account.",
        50201 => "Card blacklisted.",
        50300 => "Technical error with 3D secure.",
        50400 => "Decline because of risk issues.",
        50500 => "General timeout.",
        50501 => "Timeout on side of the acquirer.",
        50502 => "Risk management transaction timeout.",
        50600 => "Duplicate transaction."
      }

      def response_message(parsed_response)
        return parsed_response["error"] if parsed_response["error"]
        return "Transaction approved." if (parsed_response['data'] == [])

        code = parsed_response["data"]["response_code"].to_i
        RESPONSE_CODES[code] || code.to_s
      end


      class ResponseParser
        attr_reader :raw_response, :parsed, :succeeded, :message, :options

        def initialize(raw_response="", options={})
          @raw_response = raw_response
          @options = options
        end

        def generate_response
          parse_response
          if parsed['error']
            handle_response_parse_error
          else
            handle_response_correct_parsing
          end

          Response.new(succeeded, message, parsed, options)
        end

        private

        def parse_response
          @parsed = JSON.parse(raw_response.sub(/jsonPFunction\(/, '').sub(/\)\z/, ''))
        end

        def handle_response_parse_error
          @succeeded = false
          @message = parsed['error']['message']
        end

        def handle_response_correct_parsing
          @message = parsed['transaction']['processing']['return']['message']
          if @succeeded = is_ack?
            @options[:authorization] = parsed['transaction']['identification']['uniqueId']
          end
        end

        def is_ack?
          parsed['transaction']['processing']['result'] == 'ACK'
        end
      end
    end
  end
end
