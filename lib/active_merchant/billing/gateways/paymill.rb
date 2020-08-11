module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymillGateway < Gateway
      self.supported_countries = %w(AD AT BE BG CH CY CZ DE DK EE ES FI FO FR GB
                                    GI GR HR HU IE IL IM IS IT LI LT LU LV MC MT
                                    NL NO PL PT RO SE SI SK TR VA)

      self.supported_cardtypes = %i[visa master american_express diners_club discover union_pay jcb]
      self.homepage_url = 'https://paymill.com'
      self.display_name = 'PAYMILL'
      self.money_format = :cents
      self.default_currency = 'EUR'
      self.live_url = 'https://api.paymill.com/v2/'

      def initialize(options = {})
        requires!(options, :public_key, :private_key)
        super
      end

      def purchase(money, payment_method, options={})
        action_with_token(:purchase, money, payment_method, options)
      end

      def authorize(money, payment_method, options = {})
        action_with_token(:authorize, money, payment_method, options)
      end

      def capture(money, authorization, options = {})
        post = {}

        add_amount(post, money, options)
        post[:preauthorization] = preauth(authorization)
        post[:description] = options[:order_id]
        post[:source] = 'active_merchant'
        commit(:post, 'transactions', post)
      end

      def refund(money, authorization, options={})
        post = {}

        post[:amount] = amount(money)
        post[:description] = options[:order_id]
        commit(:post, "refunds/#{transaction_id(authorization)}", post)
      end

      def void(authorization, options={})
        commit(:delete, "preauthorizations/#{preauth(authorization)}")
      end

      def store(credit_card, options={})
        # The store request requires a currency and amount of at least $1 USD.
        # This is used for an authorization that is handled internally by Paymill.
        options[:currency] = 'USD'
        options[:money] = 100

        save_card(credit_card, options)
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(/(account.number=)(\d*)/, '\1[FILTERED]').
          gsub(/(account.verification=)(\d*)/, '\1[FILTERED]')
      end

      def verify_credentials
        begin
          ssl_get(live_url + 'transactions/nonexistent', headers)
        rescue ResponseError => e
          return false if e.response.code.to_i == 401
        end

        true
      end

      private

      def add_credit_card(post, credit_card, options)
        post['account.holder'] = (credit_card.try(:name) || '')
        post['account.number'] = credit_card.number
        post['account.expiry.month'] = sprintf('%.2i', credit_card.month)
        post['account.expiry.year'] = sprintf('%.4i', credit_card.year)
        post['account.verification'] = credit_card.verification_value
        post['account.email'] = (options[:email] || nil)
        post['presentation.amount3D'] = (options[:money] || nil)
        post['presentation.currency3D'] = (options[:currency] || currency(options[:money]))
      end

      def headers
        { 'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:private_key]}:X").chomp) }
      end

      def commit(method, action, parameters=nil)
        begin
          raw_response = ssl_request(method, live_url + action, post_data(parameters), headers)
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
          authorization: authorization_from(parsed),
          test: (parsed['mode'] == 'test')
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
        ].join(';')
      end

      def action_with_token(action, money, payment_method, options)
        options[:money] = money
        case payment_method
        when String
          self.send("#{action}_with_token", money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { save_card(payment_method, options) }
            r.process { self.send("#{action}_with_token", money, r.authorization, options) }
          end
        end
      end

      def purchase_with_token(money, card_token, options)
        post = {}

        add_amount(post, money, options)
        post[:token] = card_token
        post[:description] = options[:order_id]
        post[:source] = 'active_merchant'
        commit(:post, 'transactions', post)
      end

      def authorize_with_token(money, card_token, options)
        post = {}

        add_amount(post, money, options)
        post[:token] = card_token
        post[:description] = options[:order_id]
        post[:source] = 'active_merchant'
        commit(:post, 'preauthorizations', post)
      end

      def save_card(credit_card, options)
        post = {}

        add_credit_card(post, credit_card, options)
        post['channel.id'] = @options[:public_key]
        post['jsonPFunction'] = 'jsonPFunction'
        post['transaction.mode'] = (test? ? 'CONNECTOR_TEST' : 'LIVE')

        begin
          raw_response = ssl_request(:get, "#{save_card_url}?#{post_data(post)}", nil, {})
        rescue ResponseError => e
          return Response.new(false, e.response.body)
        end

        response_for_save_from(raw_response)
      end

      def response_for_save_from(raw_response)
        options = { test: test? }

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
        no_blanks.map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end

      def add_amount(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def preauth(authorization)
        authorization.split(';').last
      end

      def transaction_id(authorization)
        authorization.split(';').first
      end

      RESPONSE_CODES = {
        10001 => 'Undefined response',
        10002 => 'Waiting for something',
        11000 => 'Retry request at a later time',

        20000 => 'Operation successful',
        20100 => 'Funds held by acquirer',
        20101 => 'Funds held by acquirer because merchant is new',
        20200 => 'Transaction reversed',
        20201 => 'Reversed due to chargeback',
        20202 => 'Reversed due to money-back guarantee',
        20203 => 'Reversed due to complaint by buyer',
        20204 => 'Payment has been refunded',
        20300 => 'Reversal has been canceled',
        22000 => 'Initiation of transaction successful',

        30000 => 'Transaction still in progress',
        30100 => 'Transaction has been accepted',
        31000 => 'Transaction pending',
        31100 => 'Pending due to address',
        31101 => 'Pending due to uncleared eCheck',
        31102 => 'Pending due to risk review',
        31103 => 'Pending due regulatory review',
        31104 => 'Pending due to unregistered/unconfirmed receiver',
        31200 => 'Pending due to unverified account',
        31201 => 'Pending due to non-captured funds',
        31202 => 'Pending due to international account (accept manually)',
        31203 => 'Pending due to currency conflict (accept manually)',
        31204 => 'Pending due to fraud filters (accept manually)',

        40000 => 'Problem with transaction data',
        40001 => 'Problem with payment data',
        40002 => 'Invalid checksum',
        40100 => 'Problem with credit card data',
        40101 => 'Problem with CVV',
        40102 => 'Card expired or not yet valid',
        40103 => 'Card limit exceeded',
        40104 => 'Card is not valid',
        40105 => 'Expiry date not valid',
        40106 => 'Credit card brand required',
        40200 => 'Problem with bank account data',
        40201 => 'Bank account data combination mismatch',
        40202 => 'User authentication failed',
        40300 => 'Problem with 3-D Secure data',
        40301 => 'Currency/amount mismatch',
        40400 => 'Problem with input data',
        40401 => 'Amount too low or zero',
        40402 => 'Usage field too long',
        40403 => 'Currency not allowed',
        40410 => 'Problem with shopping cart data',
        40420 => 'Problem with address data',
        40500 => 'Permission error with acquirer API',
        40510 => 'Rate limit reached for acquirer API',
        42000 => 'Initiation of transaction failed',
        42410 => 'Initiation of transaction expired',

        50000 => 'Problem with back end',
        50001 => 'Country blacklisted',
        50002 => 'IP address blacklisted',
        50004 => 'Live mode not allowed',
        50005 => 'Insufficient permissions (API key)',
        50100 => 'Technical error with credit card',
        50101 => 'Error limit exceeded',
        50102 => 'Card declined',
        50103 => 'Manipulation or stolen card',
        50104 => 'Card restricted',
        50105 => 'Invalid configuration data',
        50200 => 'Technical error with bank account',
        50201 => 'Account blacklisted',
        50300 => 'Technical error with 3-D Secure',
        50400 => 'Declined because of risk issues',
        50401 => 'Checksum was wrong',
        50402 => 'Bank account number was invalid (formal check)',
        50403 => 'Technical error with risk check',
        50404 => 'Unknown error with risk check',
        50405 => 'Unknown bank code',
        50406 => 'Open chargeback',
        50407 => 'Historical chargeback',
        50408 => 'Institution / public bank account (NCA)',
        50409 => 'KUNO/Fraud',
        50410 => 'Personal Account Protection (PAP)',
        50420 => 'Rejected due to acquirer fraud settings',
        50430 => 'Rejected due to acquirer risk settings',
        50440 => 'Failed due to restrictions with acquirer account',
        50450 => 'Failed due to restrictions with user account',
        50500 => 'General timeout',
        50501 => 'Timeout on side of the acquirer',
        50502 => 'Risk management transaction timeout',
        50600 => 'Duplicate operation',
        50700 => 'Cancelled by user',
        50710 => 'Failed due to funding source',
        50711 => 'Payment method not usable, use other payment method',
        50712 => 'Limit of funding source was exceeded',
        50713 => 'Means of payment not reusable (canceled by user)',
        50714 => 'Means of payment not reusable (expired)',
        50720 => 'Rejected by acquirer',
        50730 => 'Transaction denied by merchant',
        50800 => 'Preauthorisation failed',
        50810 => 'Authorisation has been voided',
        50820 => 'Authorisation period expired'
      }

      def response_message(parsed_response)
        return parsed_response['error'] if parsed_response['error']
        return 'Transaction approved.' if parsed_response['data'] == []

        code = parsed_response['data']['response_code'].to_i
        RESPONSE_CODES[code] || code.to_s
      end

      class ResponseParser
        attr_reader :raw_response, :parsed, :succeeded, :message, :options

        def initialize(raw_response='', options={})
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
          @options[:authorization] = parsed['transaction']['identification']['uniqueId'] if @succeeded = ack?
        end

        def ack?
          parsed['transaction']['processing']['result'] == 'ACK'
        end
      end
    end
  end
end
