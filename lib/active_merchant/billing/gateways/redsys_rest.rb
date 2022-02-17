# coding: utf-8

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
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
    class RedsysRestGateway < Gateway
      self.test_url = 'https://sis-t.redsys.es:25443/sis/rest/%sREST'
      self.live_url = 'https://sis.redsys.es/sis/rest/%sREST'

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
        cancel:     '9'
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
      THREE_DS_V1 = '1.0.2'
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

        data = {}
        add_action(data, :purchase, options)
        add_amount(data, money, options)
        add_order(data, options[:order_id])
        add_payment(data, payment)
        add_external_mpi_fields(data, options)
        add_threeds(data, options)
        add_stored_credential_options(data, options)
        data[:description] = options[:description]
        data[:store_in_vault] = options[:store]
        data[:sca_exemption] = options[:sca_exemption]
        data[:sca_exemption_direct_payment_enabled] = options[:sca_exemption_direct_payment_enabled]

        commit data, options
      end

      def authorize(money, payment, options = {})
        requires!(options, :order_id)

        data = {}
        add_action(data, :authorize, options)
        add_amount(data, money, options)
        add_order(data, options[:order_id])
        add_payment(data, payment)
        add_external_mpi_fields(data, options)
        add_threeds(data, options)
        add_stored_credential_options(data, options)
        data[:description] = options[:description]
        data[:store_in_vault] = options[:store]
        data[:sca_exemption] = options[:sca_exemption]
        data[:sca_exemption_direct_payment_enabled] = options[:sca_exemption_direct_payment_enabled]

        commit data, options
      end

      def capture(money, authorization, options = {})
        requires!(options, :order_id)

        data = {}
        add_action(data, :capture)
        add_amount(data, money, options)
        order_id, = split_authorization(authorization)
        add_order(data, order_id)
        data[:description] = options[:description]

        commit data, options
      end

      def void(authorization, options = {})
        requires!(options, :order_id)

        data = {}
        add_action(data, :cancel)
        order_id, amount, currency = split_authorization(authorization)
        add_amount(data, amount, currency: currency)
        add_order(data, order_id)
        data[:description] = options[:description]

        commit data, options
      end

      def refund(money, authorization, options = {})
        requires!(options, :order_id)

        data = {}
        add_action(data, :refund)
        add_amount(data, money, options)
        order_id, = split_authorization(authorization)
        add_order(data, order_id)
        data[:description] = options[:description]

        commit data, options
      end

      def verify(creditcard, options = {})
        requires!(options, :order_id)

        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((PAN\"=>\")(\d+)), '\1[FILTERED]').
          gsub(%r((CVV2\"=>\")(\d+)), '\1[FILTERED]')
      end

      private

      def add_action(data, action, options = {})
        data[:action] = transaction_code(action)
      end

      def add_amount(data, money, options)
        data[:amount] = amount(money).to_s
        data[:currency] = currency_code(options[:currency] || currency(money))
      end

      def add_order(data, order_id)
        data[:order_id] = clean_order_id(order_id)
      end

      def add_payment(data, card)
        if card.is_a?(String)
          data[:credit_card_token] = card
        else
          name  = [card.first_name, card.last_name].join(' ').slice(0, 60)
          year  = sprintf('%.4i', card.year)
          month = sprintf('%.2i', card.month)
          data[:card] = {
            name: name,
            pan: card.number,
            date: "#{year[2..3]}#{month}",
            cvv: card.verification_value
          }
        end
      end

      def add_external_mpi_fields(data, options)
        return unless options[:three_d_secure]

        if options[:three_d_secure][:version] == THREE_DS_V2
          data[:threeDSServerTransID] = options[:three_d_secure][:three_ds_server_trans_id] if options[:three_d_secure][:three_ds_server_trans_id]
          data[:dsTransID] = options[:three_d_secure][:ds_transaction_id] if options[:three_d_secure][:ds_transaction_id]
          data[:authenticacionValue] = options[:three_d_secure][:cavv] if options[:three_d_secure][:cavv]
          data[:protocolVersion] = options[:three_d_secure][:version] if options[:three_d_secure][:version]
          data[:authenticacionMethod] = options[:authentication_method] if options[:authentication_method]
          data[:authenticacionType] = options[:authentication_type] if options[:authentication_type]
          data[:authenticacionFlow] = options[:authentication_flow] if options[:authentication_flow]
          data[:eci_v2] = options[:three_d_secure][:eci] if options[:three_d_secure][:eci]
        elsif options[:three_d_secure][:version] == THREE_DS_V1
          data[:txid] = options[:three_d_secure][:xid] if options[:three_d_secure][:xid]
          data[:cavv] = options[:three_d_secure][:cavv] if options[:three_d_secure][:cavv]
          data[:eci_v1] = options[:three_d_secure][:eci] if options[:three_d_secure][:eci]
        end
      end

      def add_stored_credential_options(data, options)
        return unless options[:stored_credential]

        case options[:stored_credential][:initial_transaction]
        when true
          data[:DS_MERCHANT_COF_INI] = 'S'
        when false
          data[:DS_MERCHANT_COF_INI] = 'N'
          data[:DS_MERCHANT_COF_TXNID] = options[:stored_credential][:network_transaction_id] if options[:stored_credential][:network_transaction_id]
        end

        case options[:stored_credential][:reason_type]
        when 'recurring'
          data[:DS_MERCHANT_COF_TYPE] = 'R'
        when 'installment'
          data[:DS_MERCHANT_COF_TYPE] = 'I'
        when 'unscheduled'
          return
        end
      end

      def add_threeds(data, options)
        options[:threeds] = { threeDSInfo: 'CardData' } if options[:execute_threed]
        data[:threeds] = options[:threeds] if options[:threeds]
      end

      def determine_3ds_action(threeds_hash)
        return 'trataPeticion' if threeds_hash.nil?
        return 'iniciaPeticion' if threeds_hash[:threeDSInfo] == 'CardData'
        return 'trataPeticion' if threeds_hash[:threeDSInfo] == 'AuthenticationData' ||
                                  threeds_hash[:threeDSInfo] == 'ChallengeResponse'
      end

      def commit(data, options)
        url = (test? ? test_url : live_url)
        action = determine_3ds_action(data[:threeds])
        parse(ssl_post(url % action, post_data(data, options)))
      end

      def post_data(data, options)
        merchant_parameters = build_merchant_data({}, data, options)
        merchant_parameters.transform_values!(&:to_s)
        logger.info "merchant_parameters: #{merchant_parameters}" if ENV['DEBUG_ACTIVE_MERCHANT']
        encoded_parameters = Base64.strict_encode64(merchant_parameters.to_json)

        post_data = PostData.new
        post_data['Ds_SignatureVersion'] = 'HMAC_SHA256_V1'
        post_data['Ds_MerchantParameters'] = encoded_parameters
        post_data['Ds_Signature'] = sign_request(encoded_parameters, data[:order_id])
        post_data.to_post_data
      end

      # Template Method to allow AM API clients to override decision to escape, based on their own criteria.
      def escape_special_chars?(data, options = {})
        data[:threeds]
      end

      def build_merchant_data(merchant_data, data, options = {})
        merchant_data.tap do |post|
          # Basic elements
          post['DS_MERCHANT_CURRENCY'] =           data[:currency]
          post['DS_MERCHANT_AMOUNT'] =             data[:amount]
          post['DS_MERCHANT_ORDER'] =              data[:order_id]
          post['DS_MERCHANT_TRANSACTIONTYPE'] =    data[:action]
          if data[:description] && escape_special_chars?(data, options)
            post['DS_MERCHANT_PRODUCTDESCRIPTION'] = CGI.escape(data[:description])
          else
            post['DS_MERCHANT_PRODUCTDESCRIPTION'] = data[:description]
          end
          post['DS_MERCHANT_TERMINAL'] =           options[:terminal] || @options[:terminal]
          post['DS_MERCHANT_MERCHANTCODE'] =       @options[:login]

          action = determine_3ds_action(data[:threeds]) if data[:threeds]
          if action == 'iniciaPeticion' && data[:sca_exemption]
            post['DS_MERCHANT_EXCEP_SCA'] = 'Y'
          else
            post['DS_MERCHANT_EXCEP_SCA'] = data[:sca_exemption] if data[:sca_exemption]
            post['DS_MERCHANT_DIRECTPAYMENT'] = data[:sca_exemption_direct_payment_enabled] if data[:sca_exemption_direct_payment_enabled]
          end

          # Only when card is present
          if data[:card]
            if data[:card][:name] && escape_special_chars?(data, options)
              post['DS_MERCHANT_TITULAR'] =    CGI.escape(data[:card][:name])
            else
              post['DS_MERCHANT_TITULAR'] =    data[:card][:name]
            end
            post['DS_MERCHANT_PAN'] =        data[:card][:pan]
            post['DS_MERCHANT_EXPIRYDATE'] = data[:card][:date]
            post['DS_MERCHANT_CVV2'] =       data[:card][:cvv]
            post['DS_MERCHANT_IDENTIFIER'] = 'REQUIRED' if data[:store_in_vault]

            build_merchant_mpi_external(post, data)

          elsif data[:credit_card_token]
            post['DS_MERCHANT_IDENTIFIER'] = data[:credit_card_token]
            post['DS_MERCHANT_DIRECTPAYMENT'] = 'true'
          end

          # Set moto flag only if explicitly requested via moto field
          # Requires account configuration to be able to use
          post['DS_MERCHANT_DIRECTPAYMENT'] = 'moto' if options.dig(:moto) && options.dig(:metadata, :manual_entry)

          post['DS_MERCHANT_EMV3DS'] = data[:threeds].to_json if data[:threeds]

          if options[:stored_credential]
            post['DS_MERCHANT_COF_INI'] = data[:DS_MERCHANT_COF_INI]
            post['DS_MERCHANT_COF_TYPE'] = data[:DS_MERCHANT_COF_TYPE]
            post['DS_MERCHANT_COF_TXNID'] = data[:DS_MERCHANT_COF_TXNID] if data[:DS_MERCHANT_COF_TXNID]
          end
        end
      end

      def build_merchant_mpi_external(post, data)
        return unless data[:txid] || data[:threeDSServerTransID]

        ds_merchant_mpi_external = {}
        ds_merchant_mpi_external[:TXID] = data[:txid] if data[:txid]
        ds_merchant_mpi_external[:CAVV] = data[:cavv] if data[:cavv]
        ds_merchant_mpi_external[:ECI] = data[:eci_v1] if data[:eci_v1]

        ds_merchant_mpi_external[:threeDSServerTransID] = data[:threeDSServerTransID] if data[:threeDSServerTransID]
        ds_merchant_mpi_external[:dsTransID] = data[:dsTransID] if data[:dsTransID]
        ds_merchant_mpi_external[:authenticacionValue] = data[:authenticacionValue] if data[:authenticacionValue]
        ds_merchant_mpi_external[:protocolVersion] = data[:protocolVersion] if data[:protocolVersion]
        ds_merchant_mpi_external[:Eci] = data[:eci_v2] if data[:eci_v2]
        ds_merchant_mpi_external[:authenticacionMethod] = data[:authenticacionMethod] if data[:authenticacionMethod]
        ds_merchant_mpi_external[:authenticacionType] = data[:authenticacionType] if data[:authenticacionType]
        ds_merchant_mpi_external[:authenticacionFlow] = data[:authenticacionFlow] if data[:authenticacionFlow]

        post['DS_MERCHANT_MPIEXTERNAL'] = ds_merchant_mpi_external.to_json unless ds_merchant_mpi_external.empty?
      end

      def parse(body)
        params  = {}
        success = false
        message = ''
        options = @options.merge(test: test?)

        json = JSON.parse(body)
        base64_payload = json['Ds_MerchantParameters']
        signature = json['Ds_Signature']

        if base64_payload
          payload = Base64.decode64(base64_payload)
          params = JSON.parse(payload).transform_keys!(&:downcase).with_indifferent_access
          logger.info "response params: #{params}" if ENV['DEBUG_ACTIVE_MERCHANT']

          if validate_signature(base64_payload, signature, params[:ds_order])
            if params[:ds_response]
              message = response_text(params[:ds_response])
              options[:authorization] = build_authorization(params)
              success = success_response?(params[:ds_response])
            elsif params[:ds_emv3ds]
              message = response_text_3ds(params)
              params[:ds_emv3ds] = params[:ds_emv3ds].to_json
              options[:authorization] = build_authorization(params)
              success = params.size > 0 && success_response?(params[:ds_response])
            else
              message = 'Unexpected response'
            end
          else
            message = 'Response failed validation check'
          end
        else
          message = "#{json['errorCode']} ERROR"
        end

        Response.new(success, message, params, options)
      end

      def validate_signature(data, signature, order_number)
        key = encrypt(@options[:secret_key], order_number)
        Base64.urlsafe_encode64(mac256(key, data)) == signature
      end

      def build_authorization(params)
        [params[:ds_order], params[:ds_amount], params[:ds_currency]].join('|')
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

      def response_text(code)
        code = code.to_i
        code = 0 if code < 100
        RESPONSE_TEXTS[code] || 'Unknown code, please check in manual'
      end

      def response_text_3ds(params)
        params[:ds_emv3ds]['threeDSInfo']
      end

      def success_response?(code)
        (code.to_i < 100) || [400, 481, 500, 900].include?(code.to_i)
      end

      def clean_order_id(order_id)
        cleansed = order_id.gsub(/[^\da-zA-Z]/, '')
        if /^\d{4}/.match?(cleansed)
          cleansed[0..11]
        else
          '%04d' % [rand(0..9999)] + cleansed[0...8]
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

        output = cipher.update(order_id) + cipher.final
        output
      end

      def mac256(key, data)
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, data)
      end
    end
  end
end
