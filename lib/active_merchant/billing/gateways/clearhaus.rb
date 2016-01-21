require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ClearhausGateway < Gateway
      self.test_url = 'https://gateway.test.clearhaus.com'
      self.live_url = 'https://gateway.clearhaus.com'

      self.supported_countries = ['DK', 'NO', 'SE', 'FI', 'DE', 'CH', 'NL', 'AD', 'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'FO', 'GL', 'EE', 'FR', 'GR',
                                  'HU', 'IS', 'IE', 'IT', 'LV', 'LI', 'LT', 'LU', 'MT', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'GB']

      self.default_currency    = 'EUR'
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'https://www.clearhaus.com'
      self.display_name = 'Clearhaus'
      self.money_format = :cents

      ACTION_CODE_MESSAGES = {
        20000 => 'Approved',
        40000 => 'General input error',
        40110 => 'Invalid card number',
        40120 => 'Invalid CSC',
        40130 => 'Invalid expire date',
        40135 => 'Card expired',
        40140 => 'Invalid currency',
        40200 => 'Clearhaus rule violation',
        40300 => '3-D Secure problem',
        40310 => '3-D Secure authentication failure',
        40400 => 'Backend problem',
        40410 => 'Declined by issuer or card scheme',
        40411 => 'Card restricted',
        40412 => 'Card lost or stolen',
        40413 => 'Insufficient funds',
        40414 => 'Suspected fraud',
        40415 => 'Amount limit exceeded',
        50000 => 'Clearhaus error'
      }

      # Create gateway
      #
      # options:
      #       :api_key - merchant's Clearhaus API Key
      #       :signing_key - merchant's private key for optionally signing request
      def initialize(options={})
        requires!(options, :api_key)
        super
      end

      # Make a purchase (authorize and capture)
      #
      # amount         - The monetary amount of the transaction in cents.
      # payment        - The CreditCard or the Clearhaus card token.
      # options        - A standard ActiveMerchant options hash
      def purchase(amount, payment, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, payment, options) }
          r.process { capture(amount, r.authorization, options) }
        end
      end

      # Authorize a transaction.
      #
      # amount         - The monetary amount of the transaction in cents.
      # payment        - The CreditCard or the Clearhaus card token.
      # options        - A standard ActiveMerchant options hash  with optional pares
      def authorize(amount, payment, options={})
        post = {}
        add_invoice(post, amount, options)

        action = if payment.respond_to?(:number)
           add_payment(post, payment)
          "/authorizations"
        elsif payment.kind_of?(String)
          "/cards/#{payment}/authorizations"
        else
          raise ArgumentError.new("Unknown payment type #{payment.inspect}")
        end

        post[:recurring] = options[:recurring] if options[:recurring]
        post[:threed_secure] = {pares: options[:pares]} if options[:pares]

        commit(action, post)
      end

      # Capture a pre-authorized transaction.
      #
      # amount         - The monetary amount of the transaction in cents.
      # authorization  - The Clearhaus authorization id string.
      # options        - A standard ActiveMerchant options hash
      def capture(amount, authorization, options={})
        post = {}
        add_amount(post, amount, options)

        commit("/authorizations/#{authorization}/captures", post)
      end

      # Refund a captured transaction (fully or partial).
      #
      # amount         - The monetary amount of the transaction in cents.
      # authorization  - The Clearhaus authorization id string.
      # options        - A standard ActiveMerchant options hash
      def refund(amount, authorization, options={})
        post = {}
        add_amount(post, amount, options)

        commit("/authorizations/#{authorization}/refunds", post)
      end

      def void(authorization, options = {})
        commit("/authorizations/#{authorization}/voids", options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # Tokenize credit card with Clearhaus.
      #
      # credit_card    - The CreditCard.
      # options        - A standard ActiveMerchant options hash
      def store(credit_card, options={})
        post = {}
        add_payment(post, credit_card)

        commit("/cards", post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )[\w=]+), '\1[FILTERED]').
          gsub(%r((&?card(?:\[|%5B)csc(?:\]|%5D)=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?card(?:\[|%5B)number(?:\]|%5D)=)[^&]*)i, '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        add_amount(post, money, options)
        post[:reference] = options[:order_id] if options[:order_id]
        post[:text_on_statement] = options[:description] if options[:description]
      end

      def add_amount(post, amount, options)
        post[:amount]   = amount(amount)
        post[:currency] = (options[:currency] || default_currency)
      end

      def add_payment(post, payment)
        card = {}
        card[:number]       = payment.number
        card[:expire_month] = '%02d'% payment.month
        card[:expire_year]  = payment.year

        if payment.verification_value?
          card[:csc]  = payment.verification_value
        end

        post[:card] = card if card.any?
      end

      def headers(api_key)
        {
          "Authorization"  => "Basic " + Base64.strict_encode64("#{api_key}:"),
          "User-Agent"     => "Clearhaus ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end

      def parse(body)
        JSON.parse(body) rescue body
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url) + action
        headers = headers(@options[:api_key])
        body = parameters.to_query

        if signing_key = @options[:signing_key]
          headers["Signature"] = generate_signature(@options[:api_key], signing_key, body)
        end

        response = begin
          parse(ssl_post(url, body, headers))
        rescue ResponseError => e
          raise unless(e.response.code.to_s =~ /400/)
          parse(e.response.body)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        (response && (response['status']['code'] == 20000))
      end

      def message_from(response)
        default_message = ACTION_CODE_MESSAGES[response['status']['code']]

        if success_from(response)
          default_message
        else
          (response['status']['message'] || default_message)
        end
      end

      def authorization_from(response)
        response['id']
      end

      def generate_signature(api_key, signing_key, body)
        key = OpenSSL::PKey::RSA.new(signing_key)
        hex = key.sign(OpenSSL::Digest.new('sha256'), body).unpack('H*').first

        "#{api_key} RS256-hex #{hex}"
      end

      def error_code_from(response)
        unless success_from(response)
          response['status']['code']
        end
      end
    end
  end
end
