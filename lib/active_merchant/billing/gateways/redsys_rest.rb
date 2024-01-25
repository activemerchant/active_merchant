# coding: utf-8

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    # = Redsys Merchant Gateway
    #
    # Gateway support for the Spanish "Redsys" payment gateway system. This is
    # used by many banks in Spain and is particularly well supported by
    # Catalunya Caixa's ecommerce department.
    #
    # Redsys requires an order_id be provided with each transaction and it must
    # follow a specific format. The rules are as follows:
    #
    #  * First 4 digits must be numerical
    #  * Remaining 8 digits may be alphanumeric
    #  * Max length: 12
    #
    #  If an invalid order_id is provided, we do our best to clean it up.
    #
    # Written by Piers Chambers (Varyonic.com)
    #
    # *** SHA256 Authentication Update ***
    #
    # Redsys has dropped support for the SHA1 authentication method.
    # Developer documentation: https://pagosonline.redsys.es/desarrolladores.html
    class RedsysRestGateway < Gateway
      self.test_url = 'https://sis-t.redsys.es:25443/sis/rest/'
      self.live_url = 'https://sis.redsys.es/sis/rest/'

      self.supported_countries = ['ES']
      self.default_currency    = 'EUR'
      self.money_format        = :cents
      # Not all card types may be activated by the bank!
      self.supported_cardtypes = %i[visa master american_express jcb diners_club unionpay]
      self.homepage_url        = 'http://www.redsys.es/'
      self.display_name        = 'Redsys (REST)'

      CURRENCY_CODES = {
        'AED' => '784',
        'ARS' => '32',
        'AUD' => '36',
        'BRL' => '986',
        'BOB' => '68',
        'CAD' => '124',
        'CHF' => '756',
        'CLP' => '152',
        'CNY' => '156',
        'COP' => '170',
        'CRC' => '188',
        'CZK' => '203',
        'DKK' => '208',
        'DOP' => '214',
        'EUR' => '978',
        'GBP' => '826',
        'GTQ' => '320',
        'HUF' => '348',
        'IDR' => '360',
        'INR' => '356',
        'JPY' => '392',
        'KRW' => '410',
        'MYR' => '458',
        'MXN' => '484',
        'NOK' => '578',
        'NZD' => '554',
        'PEN' => '604',
        'PLN' => '985',
        'RUB' => '643',
        'SAR' => '682',
        'SEK' => '752',
        'SGD' => '702',
        'THB' => '764',
        'TWD' => '901',
        'USD' => '840',
        'UYU' => '858'
      }

      # The set of supported transactions for this gateway.
      # More operations are supported by the gateway itself, but
      # are not supported in this library.
      SUPPORTED_TRANSACTIONS = {
        purchase:   '0',
        authorize:  '1',
        capture:    '2',
        refund:     '3',
        cancel:     '9',
        verify:     '7'
      }

      # These are the text meanings sent back by the acquirer when
      # a card has been rejected. Syntax or general request errors
      # are not covered here.
      RESPONSE_TEXTS = {
        0 => 'Transaction Approved',
        400 => 'Cancellation Accepted',
        481 => 'Cancellation Accepted',
        500 => 'Reconciliation Accepted',
        900 => 'Refund / Confirmation approved',

        101 => 'Card expired',
        102 => 'Card blocked temporarily or under susciption of fraud',
        104 => 'Transaction not permitted',
        107 => 'Contact the card issuer',
        109 => 'Invalid identification by merchant or POS terminal',
        110 => 'Invalid amount',
        114 => 'Card cannot be used to the requested transaction',
        116 => 'Insufficient credit',
        118 => 'Non-registered card',
        125 => 'Card not effective',
        129 => 'CVV2/CVC2 Error',
        167 => 'Contact the card issuer: suspected fraud',
        180 => 'Card out of service',
        181 => 'Card with credit or debit restrictions',
        182 => 'Card with credit or debit restrictions',
        184 => 'Authentication error',
        190 => 'Refusal with no specific reason',
        191 => 'Expiry date incorrect',
        195 => 'Requires SCA authentication',

        201 => 'Card expired',
        202 => 'Card blocked temporarily or under suspicion of fraud',
        204 => 'Transaction not permitted',
        207 => 'Contact the card issuer',
        208 => 'Lost or stolen card',
        209 => 'Lost or stolen card',
        280 => 'CVV2/CVC2 Error',
        290 => 'Declined with no specific reason',

        480 => 'Original transaction not located, or time-out exceeded',
        501 => 'Original transaction not located, or time-out exceeded',
        502 => 'Original transaction not located, or time-out exceeded',
        503 => 'Original transaction not located, or time-out exceeded',

        904 => 'Merchant not registered at FUC',
        909 => 'System error',
        912 => 'Issuer not available',
        913 => 'Duplicate transmission',
        916 => 'Amount too low',
        928 => 'Time-out exceeded',
        940 => 'Transaction cancelled previously',
        941 => 'Authorization operation already cancelled',
        942 => 'Original authorization declined',
        943 => 'Different details from origin transaction',
        944 => 'Session error',
        945 => 'Duplicate transmission',
        946 => 'Cancellation of transaction while in progress',
        947 => 'Duplicate tranmission while in progress',
        949 => 'POS Inoperative',
        950 => 'Refund not possible',
        9064 => 'Card number incorrect',
        9078 => 'No payment method available',
        9093 => 'Non-existent card',
        9218 => 'Recursive transaction in bad gateway',
        9253 => 'Check-digit incorrect',
        9256 => 'Preauth not allowed for merchant',
        9257 => 'Preauth not allowed for card',
        9261 => 'Operating limit exceeded',
        9912 => 'Issuer not available',
        9913 => 'Confirmation error',
        9914 => 'KO Confirmation'
      }

      # Expected values as per documentation
      THREE_DS_V2 = '2.1.0'

      # Creates a new instance
      #
      # Redsys requires a login and secret_key, and optionally also accepts a
      # non-default terminal.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The Redsys Merchant ID (REQUIRED)
      # * <tt>:secret_key</tt> -- The Redsys Secret Key. (REQUIRED)
      # * <tt>:terminal</tt> -- The Redsys Terminal. Defaults to 1. (OPTIONAL)
      # * <tt>:test</tt> -- +true+ or +false+. Defaults to +false+. (OPTIONAL)
      def initialize(options = {})
        requires!(options, :login, :secret_key)
        options[:terminal] ||= 1
        options[:signature_algorithm] = 'sha256'
        super
      end

      def purchase(money, payment, options = {})
        requires!(options, :order_id)

        post = {}
        add_action(post, :purchase, options)
        add_amount(post, money, options)
        add_order(post, options[:order_id])
        add_payment(post, payment)
        add_description(post, options)
        add_direct_payment(post, options)
        add_threeds(post, options)

        commit(post, options)
      end

      def authorize(money, payment, options = {})
        requires!(options, :order_id)

        post = {}
        add_action(post, :authorize, options)
        add_amount(post, money, options)
        add_order(post, options[:order_id])
        add_payment(post, payment)
        add_description(post, options)
        add_direct_payment(post, options)
        add_threeds(post, options)

        commit(post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_action(post, :capture)
        add_amount(post, money, options)
        order_id, = split_authorization(authorization)
        add_order(post, order_id)
        add_description(post, options)

        commit(post, options)
      end

      def void(authorization, options = {})
        requires!(options, :order_id)

        post = {}
        add_action(post, :cancel)
        order_id, amount, currency = split_authorization(authorization)
        add_amount(post, amount, currency: currency)
        add_order(post, order_id)
        add_description(post, options)

        commit(post, options)
      end

      def refund(money, authorization, options = {})
        requires!(options, :order_id)

        post = {}
        add_action(post, :refund)
        add_amount(post, money, options)
        order_id, = split_authorization(authorization)
        add_order(post, order_id)
        add_description(post, options)

        commit(post, options)
      end

      def verify(creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        add_action(post, :verify, options)
        add_amount(post, 0, options)
        add_order(post, options[:order_id])
        add_payment(post, creditcard)
        add_description(post, options)
        add_direct_payment(post, options)
        add_threeds(post, options)

        commit(post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((PAN"=>")(\d+)), '\1[FILTERED]').
          gsub(%r((CVV2"=>")(\d+)), '\1[FILTERED]')
      end

      private

      def add_direct_payment(post, options)
        # Direct payment skips 3DS authentication. We should only apply this if execute_threed is false
        # or authentication data is not present. Authentication data support to be added in the future.
        return if options[:execute_threed] || options[:authentication_data]

        post[:DS_MERCHANT_DIRECTPAYMENT] = true
      end

      def add_threeds(post, options)
        post[:DS_MERCHANT_EMV3DS] = { threeDSInfo: 'CardData' } if options[:execute_threed]
      end

      def add_action(post, action, options = {})
        post[:DS_MERCHANT_TRANSACTIONTYPE] = transaction_code(action)
      end

      def add_amount(post, money, options)
        post[:DS_MERCHANT_AMOUNT] = amount(money).to_s
        post[:DS_MERCHANT_CURRENCY] = currency_code(options[:currency] || currency(money))
      end

      def add_description(post, options)
        post[:DS_MERCHANT_PRODUCTDESCRIPTION] = CGI.escape(options[:description]) if options[:description]
      end

      def add_order(post, order_id)
        post[:DS_MERCHANT_ORDER] = clean_order_id(order_id)
      end

      def add_payment(post, card)
        name = [card.first_name, card.last_name].join(' ').slice(0, 60)
        year = sprintf('%.4i', card.year)
        month = sprintf('%.2i', card.month)
        post['DS_MERCHANT_TITULAR'] = CGI.escape(name)
        post['DS_MERCHANT_PAN'] = card.number
        post['DS_MERCHANT_EXPIRYDATE'] = "#{year[2..3]}#{month}"
        post['DS_MERCHANT_CVV2'] = card.verification_value
      end

      def determine_action(options)
        # If execute_threed is true, we need to use iniciaPeticionREST to set up authentication
        # Otherwise we are skipping 3DS or we should have 3DS authentication results
        options[:execute_threed] ? 'iniciaPeticionREST' : 'trataPeticionREST'
      end

      def commit(post, options)
        url = (test? ? test_url : live_url)
        action = determine_action(options)
        raw_response = parse(ssl_post(url + action, post_data(post, options)))
        payload = raw_response['Ds_MerchantParameters']
        return Response.new(false, "#{raw_response['errorCode']} ERROR") unless payload

        response = JSON.parse(Base64.decode64(payload)).transform_keys!(&:downcase).with_indifferent_access
        return Response.new(false, 'Unable to verify response') unless validate_signature(payload, raw_response['Ds_Signature'], response[:ds_order])

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: success_from(response) ? nil : response[:ds_response]
        )
      end

      def post_data(post, options)
        add_authentication(post, options)
        merchant_parameters = JSON.generate(post)
        encoded_parameters = Base64.strict_encode64(merchant_parameters)
        post_data = PostData.new
        post_data['Ds_SignatureVersion'] = 'HMAC_SHA256_V1'
        post_data['Ds_MerchantParameters'] = encoded_parameters
        post_data['Ds_Signature'] = sign_request(encoded_parameters, post[:DS_MERCHANT_ORDER])
        post_data.to_post_data
      end

      def add_authentication(post, options)
        post[:DS_MERCHANT_TERMINAL] = options[:terminal] || @options[:terminal]
        post[:DS_MERCHANT_MERCHANTCODE] = @options[:login]
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        # Need to get updated for 3DS support
        if code = response[:ds_response]
          (code.to_i < 100) || [400, 481, 500, 900].include?(code.to_i)
        else
          false
        end
      end

      def message_from(response)
        # Need to get updated for 3DS support
        code = response[:ds_response]&.to_i
        code = 0 if code < 100
        RESPONSE_TEXTS[code] || 'Unknown code, please check in manual'
      end

      def validate_signature(data, signature, order_number)
        key = encrypt(@options[:secret_key], order_number)
        Base64.urlsafe_encode64(mac256(key, data)) == signature
      end

      def authorization_from(response)
        # Need to get updated for 3DS support
        [response[:ds_order], response[:ds_amount], response[:ds_currency]].join('|')
      end

      def split_authorization(authorization)
        order_id, amount, currency = authorization.split('|')
        [order_id, amount.to_i, currency]
      end

      def currency_code(currency)
        return currency if currency =~ /^\d+$/
        raise ArgumentError, "Unknown currency #{currency}" unless CURRENCY_CODES[currency]

        CURRENCY_CODES[currency]
      end

      def transaction_code(type)
        SUPPORTED_TRANSACTIONS[type]
      end

      def clean_order_id(order_id)
        cleansed = order_id.gsub(/[^\da-zA-Z]/, '')
        if /^\d{4}/.match?(cleansed)
          cleansed[0..11]
        else
          ('%04d' % [rand(0..9999)]) + cleansed[0...8]
        end
      end

      def sign_request(encoded_parameters, order_id)
        raise(ArgumentError, 'missing order_id') unless order_id

        key = encrypt(@options[:secret_key], order_id)
        Base64.strict_encode64(mac256(key, encoded_parameters))
      end

      def encrypt(key, order_id)
        block_length = 8
        cipher = OpenSSL::Cipher.new('DES3')
        cipher.encrypt

        cipher.key = Base64.urlsafe_decode64(key)
        # The OpenSSL default of an all-zeroes ("\\0") IV is used.
        cipher.padding = 0

        order_id += "\0" until order_id.bytesize % block_length == 0 # Pad with zeros

        cipher.update(order_id) + cipher.final
      end

      def mac256(key, data)
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, data)
      end
    end
  end
end
