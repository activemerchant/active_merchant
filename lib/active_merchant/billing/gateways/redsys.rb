# coding: utf-8

require 'nokogiri'

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
    # Much of the code for this library is based on the active_merchant_sermepa
    # integration gateway which uses essentially the same API but with the
    # banks own payment screen.
    #
    # Written by Samuel Lown for Cabify. For implementation questions, or
    # test access details please get in touch: sam@cabify.com.
    #
    # *** SHA256 Authentication Update ***
    #
    # Redsys is dropping support for the SHA1 authentication method. This
    # adapter has been updated to work with the new SHA256 authentication
    # method, however in your initialization options hash you will need to
    # specify the key/value :signature_algorithm => "sha256" to use the
    # SHA256 method. Otherwise it will default to using the SHA1.
    #
    #
    class RedsysGateway < Gateway
      self.live_url = 'https://sis.redsys.es/sis/operaciones'
      self.test_url = 'https://sis-t.redsys.es:25443/sis/operaciones'

      self.supported_countries = ['ES']
      self.default_currency    = 'EUR'
      self.money_format        = :cents

      # Not all card types may be activated by the bank!
      self.supported_cardtypes = %i[visa master american_express jcb diners_club unionpay]
      self.homepage_url        = 'http://www.redsys.es/'
      self.display_name        = 'Redsys'

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
        purchase:   'A',
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
      # * <tt>:signature_algorithm</tt> -- +"sha256"+ Defaults to +"sha1"+. (OPTIONAL)
      def initialize(options = {})
        requires!(options, :login, :secret_key)
        options[:terminal] ||= 1
        options[:signature_algorithm] ||= 'sha1'
        super
      end

      def purchase(money, payment, options = {})
        requires!(options, :order_id)

        data = {}
        add_action(data, :purchase, options)
        add_amount(data, money, options)
        add_order(data, options[:order_id])
        add_payment(data, payment)
        add_threeds(data, options) if options[:execute_threed]
        data[:description] = options[:description]
        data[:store_in_vault] = options[:store]
        data[:sca_exemption] = options[:sca_exemption]

        commit data, options
      end

      def authorize(money, payment, options = {})
        requires!(options, :order_id)

        data = {}
        add_action(data, :authorize, options)
        add_amount(data, money, options)
        add_order(data, options[:order_id])
        add_payment(data, payment)
        add_threeds(data, options) if options[:execute_threed]
        data[:description] = options[:description]
        data[:store_in_vault] = options[:store]
        data[:sca_exemption] = options[:sca_exemption]

        commit data, options
      end

      def capture(money, authorization, options = {})
        data = {}
        add_action(data, :capture)
        add_amount(data, money, options)
        order_id, = split_authorization(authorization)
        add_order(data, order_id)
        data[:description] = options[:description]

        commit data, options
      end

      def void(authorization, options = {})
        data = {}
        add_action(data, :cancel)
        order_id, amount, currency = split_authorization(authorization)
        add_amount(data, amount, currency: currency)
        add_order(data, order_id)
        data[:description] = options[:description]

        commit data, options
      end

      def refund(money, authorization, options = {})
        data = {}
        add_action(data, :refund)
        add_amount(data, money, options)
        order_id, = split_authorization(authorization)
        add_order(data, order_id)
        data[:description] = options[:description]

        commit data, options
      end

      def verify(creditcard, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((%3CDS_MERCHANT_PAN%3E)\d+(%3C%2FDS_MERCHANT_PAN%3E))i, '\1[FILTERED]\2').
          gsub(%r((%3CDS_MERCHANT_CVV2%3E)\d+(%3C%2FDS_MERCHANT_CVV2%3E))i, '\1[FILTERED]\2').
          gsub(%r((&lt;DS_MERCHANT_PAN&gt;)\d+(&lt;/DS_MERCHANT_PAN&gt;))i, '\1[FILTERED]\2').
          gsub(%r((<DS_MERCHANT_PAN>)\d+(</DS_MERCHANT_PAN>))i, '\1[FILTERED]\2').
          gsub(%r((<DS_MERCHANT_CVV2>)\d+(</DS_MERCHANT_CVV2>))i, '\1[FILTERED]\2').
          gsub(%r((&lt;DS_MERCHANT_CVV2&gt;)\d+(&lt;/DS_MERCHANT_CVV2&gt;))i, '\1[FILTERED]\2').
          gsub(%r((DS_MERCHANT_CVV2)%2F%3E%0A%3C%2F)i, '\1[BLANK]').
          gsub(%r((DS_MERCHANT_CVV2)%2F%3E%3C)i, '\1[BLANK]').
          gsub(%r((DS_MERCHANT_CVV2%3E)(%3C%2FDS_MERCHANT_CVV2))i, '\1[BLANK]\2').
          gsub(%r((<DS_MERCHANT_CVV2>)(</DS_MERCHANT_CVV2>))i, '\1[BLANK]\2').
          gsub(%r((DS_MERCHANT_CVV2%3E)\++(%3C%2FDS_MERCHANT_CVV2))i, '\1[BLANK]\2').
          gsub(%r((<DS_MERCHANT_CVV2>)\s+(</DS_MERCHANT_CVV2>))i, '\1[BLANK]\2')
      end

      private

      def add_action(data, action, options = {})
        data[:action] = options[:execute_threed].present? ? '0' : transaction_code(action)
      end

      def add_amount(data, money, options)
        data[:amount] = amount(money).to_s
        data[:currency] = currency_code(options[:currency] || currency(money))
      end

      def add_order(data, order_id)
        data[:order_id] = clean_order_id(order_id)
      end

      def url
        test? ? test_url : live_url
      end

      def threeds_url
        test? ? 'https://sis-t.redsys.es:25443/sis/services/SerClsWSEntradaV2' : 'https://sis.redsys.es/sis/services/SerClsWSEntradaV2'
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

      def add_threeds(data, options)
        data[:threeds] = {threeDSInfo: 'CardData'} if options[:execute_threed] == true
      end

      def determine_3ds_action(threeds_hash)
        return 'iniciaPeticion' if threeds_hash[:threeDSInfo] == 'CardData'
        return 'trataPeticion' if threeds_hash[:threeDSInfo] == 'AuthenticationData' ||
                                  threeds_hash[:threeDSInfo] == 'ChallengeResponse'
      end

      def commit(data, options = {})
        if data[:threeds]
          action = determine_3ds_action(data[:threeds])
          request = <<-EOS
            <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:apachesoap="http://xml.apache.org/xml-soap" xmlns:impl="http://webservice.sis.sermepa.es" xmlns:intf="http://webservice.sis.sermepa.es" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:wsdlsoap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" >
            <soapenv:Header/>
            <soapenv:Body>
              <intf:#{action} xmlns:intf="http://webservice.sis.sermepa.es">
                <intf:datoEntrada>
                <![CDATA[#{xml_request_from(data, options)}]]>
                </intf:datoEntrada>
              </intf:#{action}>
            </soapenv:Body>
          </soapenv:Envelope>
          EOS
          parse(ssl_post(threeds_url, request, headers(action)), action)
        else
          parse(ssl_post(url, "entrada=#{CGI.escape(xml_request_from(data, options))}", headers), action)
        end
      end

      def headers(action=nil)
        if action
          {
            'Content-Type' => 'text/xml',
            'SOAPAction' => action
          }
        else
          {
            'Content-Type' => 'application/x-www-form-urlencoded'
          }
        end
      end

      def xml_request_from(data, options = {})
        if sha256_authentication?
          build_sha256_xml_request(data, options)
        else
          build_sha1_xml_request(data, options)
        end
      end

      def build_signature(data)
        str = data[:amount] +
              data[:order_id].to_s +
              @options[:login].to_s +
              data[:currency]

        if card = data[:card]
          str << card[:pan]
          str << card[:cvv] if card[:cvv]
        end

        str << data[:action]
        if data[:store_in_vault]
          str << 'REQUIRED'
        elsif data[:credit_card_token]
          str << data[:credit_card_token]
        end
        str << @options[:secret_key]

        Digest::SHA1.hexdigest(str)
      end

      def build_sha256_xml_request(data, options = {})
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.REQUEST do
          build_merchant_data(xml, data, options)
          xml.DS_SIGNATUREVERSION 'HMAC_SHA256_V1'
          xml.DS_SIGNATURE sign_request(merchant_data_xml(data, options), data[:order_id])
        end
        xml.target!
      end

      def build_sha1_xml_request(data, options = {})
        xml = Builder::XmlMarkup.new indent: 2
        build_merchant_data(xml, data, options)
        xml.target!
      end

      def merchant_data_xml(data, options = {})
        xml = Builder::XmlMarkup.new
        build_merchant_data(xml, data, options)
        xml.target!
      end

      def build_merchant_data(xml, data, options = {})
        xml.DATOSENTRADA do
          # Basic elements
          xml.DS_Version 0.1
          xml.DS_MERCHANT_CURRENCY           data[:currency]
          xml.DS_MERCHANT_AMOUNT             data[:amount]
          xml.DS_MERCHANT_ORDER              data[:order_id]
          xml.DS_MERCHANT_TRANSACTIONTYPE    data[:action]
          if data[:description] && data[:threeds]
            xml.DS_MERCHANT_PRODUCTDESCRIPTION CGI.escape(data[:description])
          else
            xml.DS_MERCHANT_PRODUCTDESCRIPTION data[:description]
          end
          xml.DS_MERCHANT_TERMINAL           options[:terminal] || @options[:terminal]
          xml.DS_MERCHANT_MERCHANTCODE       @options[:login]
          xml.DS_MERCHANT_MERCHANTSIGNATURE  build_signature(data) unless sha256_authentication?
          xml.DS_MERCHANT_EXCEP_SCA          data[:sca_exemption] if data[:sca_exemption]

          # Only when card is present
          if data[:card]
            if data[:card][:name] && data[:threeds]
              xml.DS_MERCHANT_TITULAR    CGI.escape(data[:card][:name])
            else
              xml.DS_MERCHANT_TITULAR    data[:card][:name]
            end
            xml.DS_MERCHANT_PAN        data[:card][:pan]
            xml.DS_MERCHANT_EXPIRYDATE data[:card][:date]
            xml.DS_MERCHANT_CVV2       data[:card][:cvv]
            xml.DS_MERCHANT_IDENTIFIER 'REQUIRED' if data[:store_in_vault]
          elsif data[:credit_card_token]
            xml.DS_MERCHANT_IDENTIFIER data[:credit_card_token]
            xml.DS_MERCHANT_DIRECTPAYMENT 'true'
          end

          # Set moto flag only if explicitly requested via moto field
          # Requires account configuration to be able to use
          xml.DS_MERCHANT_DIRECTPAYMENT 'moto' if options.dig(:moto) && options.dig(:metadata, :manual_entry)

          xml.DS_MERCHANT_EMV3DS data[:threeds].to_json if data[:threeds]
        end
      end

      def parse(data, action)
        params  = {}
        success = false
        message = ''
        options = @options.merge(test: test?)
        xml     = Nokogiri::XML(data)
        code    = xml.xpath('//RETORNOXML/CODIGO').text

        if code == '0' && xml.xpath('//RETORNOXML/OPERACION').present?
          op = xml.xpath('//RETORNOXML/OPERACION')
          op.children.each do |element|
            params[element.name.downcase.to_sym] = element.text
          end
          if validate_signature(params)
            message = response_text(params[:ds_response])
            options[:authorization] = build_authorization(params)
            success = success_response?(params[:ds_response])
          else
            message = 'Response failed validation check'
          end
        elsif %w[iniciaPeticion trataPeticion].include?(action)
          vxml = Nokogiri::XML(data).remove_namespaces!.xpath("//Envelope/Body/#{action}Response/#{action}Return").inner_text
          xml = Nokogiri::XML(vxml)
          node = (action == 'iniciaPeticion' ? 'INFOTARJETA' : 'OPERACION')
          op = xml.xpath("//RETORNOXML/#{node}")
          op.children.each do |element|
            params[element.name.downcase.to_sym] = element.text
          end
          message = response_text_3ds(xml, params)
          options[:authorization] = build_authorization(params)
          success = params.size > 0 && success_response?(params[:ds_response])
        else
          # Some kind of programmer error with the request!
          message = "#{code} ERROR"
        end

        Response.new(success, message, params, options)
      end

      def validate_signature(data)
        if sha256_authentication?
          sig = Base64.strict_encode64(mac256(get_key(data[:ds_order].to_s), xml_signed_fields(data)))
          sig.casecmp(data[:ds_signature].to_s).zero?
        else
          str = data[:ds_amount] +
                data[:ds_order].to_s +
                data[:ds_merchantcode] +
                data[:ds_currency] +
                data[:ds_response] +
                data[:ds_cardnumber].to_s +
                data[:ds_transactiontype].to_s +
                data[:ds_securepayment].to_s +
                @options[:secret_key]

          sig = Digest::SHA1.hexdigest(str)
          data[:ds_signature].to_s.downcase == sig
        end
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
        RESPONSE_TEXTS[code] || 'Unkown code, please check in manual'
      end

      def response_text_3ds(xml, params)
        code = xml.xpath('//RETORNOXML/CODIGO').text
        message = ''
        if code != '0'
          message = "#{code} ERROR"
        elsif params[:ds_emv3ds]
          three_ds_data = JSON.parse(params[:ds_emv3ds])
          message = three_ds_data['threeDSInfo']
        elsif params[:ds_response]
          message = response_text(params[:ds_response])
        end
        message
      end

      def success_response?(code)
        (code.to_i < 100) || [400, 481, 500, 900].include?(code.to_i)
      end

      def clean_order_id(order_id)
        cleansed = order_id.gsub(/[^\da-zA-Z]/, '')
        if /^\d{4}/.match?(cleansed)
          cleansed[0..11]
        else
          '%04d%s' % [rand(0..9999), cleansed[0...8]]
        end
      end

      def sha256_authentication?
        @options[:signature_algorithm] == 'sha256'
      end

      def sign_request(xml_request_string, order_id)
        key = encrypt(@options[:secret_key], order_id)
        Base64.strict_encode64(mac256(key, xml_request_string))
      end

      def encrypt(key, order_id)
        block_length = 8
        cipher = OpenSSL::Cipher.new('DES3')
        cipher.encrypt

        cipher.key = Base64.strict_decode64(key)
        # The OpenSSL default of an all-zeroes ("\\0") IV is used.
        cipher.padding = 0

        order_id += "\0" until order_id.bytesize % block_length == 0 # Pad with zeros

        output = cipher.update(order_id) + cipher.final
        output
      end

      def mac256(key, data)
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, data)
      end

      def xml_signed_fields(data)
        xml_signed_fields = data[:ds_amount] + data[:ds_order] + data[:ds_merchantcode] +
                            data[:ds_currency] + data[:ds_response]

        xml_signed_fields += data[:ds_cardnumber] if data[:ds_cardnumber]

        xml_signed_fields += data[:ds_emv3ds] if data[:ds_emv3ds]

        xml_signed_fields + data[:ds_transactiontype] + data[:ds_securepayment]
      end

      def get_key(order_id)
        encrypt(@options[:secret_key], order_id)
      end
    end
  end
end
