module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymillGateway < Gateway
      self.supported_countries = %w(AD AT BE BG CH CY CZ DE DK EE ES FI FO FR GB
                                    GI GR HU IE IL IS IT LI LT LU LV MT NL NO PL
                                    PT RO SE SI SK TR VA)

      self.supported_cardtypes = [:visa, :master]
      self.homepage_url = 'https://paymill.com'
      self.display_name = 'PAYMILL'
      self.money_format = :cents
      self.default_currency = 'EUR'

      def initialize(options = {})
        requires!(options, :public_key, :private_key)
        super
      end

      def purchase(money, payment_method, options = {})
        case payment_method
        when String
          purchase_with_token(money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { save_card(payment_method) }
            r.process { purchase_with_token(money, r.authorization, options) }
          end
        end
      end

      def authorize(money, payment_method, options = {})
        case payment_method
        when String
          authorize_with_token(money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { save_card(payment_method) }
            r.process { authorize_with_token(money, r.authorization, options) }
          end
        end
      end

      def capture(money, authorization, options = {})
        post = {}

        add_amount(post, money, options)
        post[:preauthorization] = preauth(authorization)
        post[:description] = options[:description]
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
          parsed = JSON.parse(e.response.body)
          return Response.new(false, parsed['error'], parsed, {})
        end

        response_from(raw_response)
      end

      def response_from(raw_response)
        parsed = JSON.parse(raw_response)

        options = {
          :authorization => authorization_from(parsed),
          :test => (parsed['mode'] == 'test'),
        }

        Response.new(true, 'Transaction approved', parsed, options)
      end

      def authorization_from(parsed_response)
        parsed_data = parsed_response['data']
        return '' unless parsed_data.kind_of?(Hash)

        [
          parsed_data['id'],
          parsed_data['preauthorization'].try(:[], 'id')
        ].join(";")
      end

      def purchase_with_token(money, card_token, options)
        post = {}

        add_amount(post, money, options)
        post[:token] = card_token
        post[:description] = options[:description]
        post[:client] = options[:customer]
        commit(:post, 'transactions', post)
      end

      def authorize_with_token(money, card_token, options)
        post = {}

        add_amount(post, money, options)
        post[:token] = card_token
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

        parsed = JSON.parse(raw_response.sub(/jsonPFunction\(/, '').sub(/\)\z/, ''))
        if parsed['error']
          succeeded = false
          message = parsed['error']['message']
        else
          succeeded = parsed['transaction']['processing']['result'] == 'ACK'
          message = parsed['transaction']['processing']['return']['message']
          options[:authorization] = parsed['transaction']['identification']['uniqueId'] if succeeded
        end

        Response.new(succeeded, message, parsed, options)
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
    end
  end
end
