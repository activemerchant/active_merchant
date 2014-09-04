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
    # Standard ActiveMerchant methods are supported, with one notable exception:
    # :order_id must be provided and must conform to a very specific format.
    #
    # == Example use:
    #
    #   gateway = ActiveMerchant::Billing::RedsysGateway.new(
    #               :login      => "091358382",
    #               :secret_key => "qwertyasdf0123456789"
    #            )
    #
    #   # Run a purchase for 10 euros
    #   response = gateway.purchase(1000, creditcard, :order_id => "123456")
    #   puts reponse.success?       # => true
    #
    #   # Partially refund the purchase
    #   response = gateway.refund(500, response.authorization)
    #
    # Redsys requires an order_id be provided with each transaction of a
    # specific format. The rules are as follows:
    #
    #  * Minimum length: 4
    #  * Maximum length: 12
    #  * First 4 digits must be numerical
    #  * Remaining 8 digits may be alphanumeric
    #
    # Much of the code for this library is based on the active_merchant_sermepa
    # integration gateway which uses essentially the same API but with the
    # banks own payment screen.
    #
    # Written by Samuel Lown for Cabify. For implementation questions, or
    # test access details please get in touch: sam@cabify.com.
    class RedsysGateway < Gateway
      self.live_url = "https://sis.sermepa.es/sis/operaciones"
      self.test_url = "https://sis-t.sermepa.es:25443/sis/operaciones"

      # Sensible region specific defaults.
      self.supported_countries = ['ES']
      self.default_currency    = 'EUR'
      self.money_format        = :cents

      # Not all card types may be activated by the bank!
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :diners_club]

      # Homepage URL of the gateway for reference
      self.homepage_url        = "http://www.redsys.es/"

      # What to call this gateway
      self.display_name        = "Redsys"

      CURRENCY_CODES = {
        "ARS" => '032',
        "AUD" => '036',
        "BRL" => '986',
        "BOB" => '068',
        "CAD" => '124',
        "CHF" => '756',
        "CLP" => '152',
        "COP" => '170',
        "EUR" => '978',
        "GBP" => '826',
        "GTQ" => '320',
        "JPY" => '392',
        "MXN" => '484',
        "NZD" => '554',
        "PEN" => '604',
        "RUB" => '643',
        "SGD" => '702',
        "USD" => '840',
        "UYU" => '858'
      }

      # The set of supported transactions for this gateway.
      # More operations are supported by the gateway itself, but
      # are not supported in this library.
      SUPPORTED_TRANSACTIONS = {
        :purchase   => 'A',
        :authorize  => '1',
        :capture    => '2',
        :refund     => '3',
        :cancel     => '9'
      }

      # These are the text meanings sent back by the acquirer when
      # a card has been rejected. Syntax or general request errors
      # are not covered here.
      RESPONSE_TEXTS = {
        # Accepted Codes
        0 => "Transaction Approved",
        400 => "Cancellation Accepted",
        481 => "Cancellation Accepted",
        500 => "Reconciliation Accepted",
        900 => "Refund / Confirmation approved",

        # Declined error codes
        101 => "Card expired",
        102 => "Card blocked temporarily or under susciption of fraud",
        104 => "Transaction not permitted",
        107 => "Contact the card issuer",
        109 => "Invalid identification by merchant or POS terminal",
        110 => "Invalid amount",
        114 => "Card cannot be used to the requested transaction",
        116 => "Insufficient credit",
        118 => "Non-registered card",
        125 => "Card not effective",
        129 => "CVV2/CVC2 Error",
        167 => "Contact the card issuer: suspected fraud",
        180 => "Card out of service",
        181 => "Card with credit or debit restrictions",
        182 => "Card with credit or debit restrictions",
        184 => "Authentication error",
        190 => "Refusal with no specific reason",
        191 => "Expiry date incorrect",

        # Declined, and suspected of fraud
        201 => "Card expired",
        202 => "Card blocked temporarily or under suscipition of fraud",
        204 => "Transaction not permitted",
        207 => "Contact the card issuer",
        208 => "Lost or stolen card",
        209 => "Lost or stolen card",
        280 => "CVV2/CVC2 Error",
        290 => "Declined with no specific reason",

        # More general codes for specific types of transaction
        480 => "Original transaction not located, or time-out exceeded",
        501 => "Original transaction not located, or time-out exceeded",
        502 => "Original transaction not located, or time-out exceeded",
        503 => "Original transaction not located, or time-out exceeded",

        # Declined transactions by the bank
        904 => "Merchant not registered at FUC",
        909 => "System error",
        912 => "Issuer not available",
        913 => "Duplicate transmission",
        916 => "Amount too low",
        928 => "Time-out exceeded",
        940 => "Transaction cancelled previously",
        941 => "Authorization operation already cancelled",
        942 => "Original authorization declined",
        943 => "Different details from origin transaction",
        944 => "Session error",
        945 => "Duplicate transmission",
        946 => "Cancellation of transaction while in progress",
        947 => "Duplicate tranmission while in progress",
        949 => "POS Inoperative",
        950 => "Refund not possible",
        9064 => "Card number incorrect",
        9078 => "No payment method available",
        9093 => "Non-existent card",
        9218 => "Recursive transaction in bad gateway",
        9253 => "Check-digit incorrect",
        9256 => "Preauth not allowed for merchant",
        9257 => "Preauth not allowed for card",
        9261 => "Operating limit exceeded",
        9912 => "Issuer not available",
        9913 => "Confirmation error",
        9914 => "KO Confirmation"
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
      def initialize(options = {})
        requires!(options, :login, :secret_key)
        options[:terminal] ||= 1
        super
      end

      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        data = {}
        add_action(data, :purchase)
        add_amount(data, money, options)
        add_order(data, options[:order_id])
        add_creditcard(data, creditcard)

        commit data
      end

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)

        data = {}
        add_action(data, :authorize)
        add_amount(data, money, options)
        add_order(data, options[:order_id])
        add_creditcard(data, creditcard)

        commit data
      end

      def capture(money, authorization, options = {})
        data = {}
        add_action(data, :capture)
        add_amount(data, money, options)
        order_id, _, _ = split_authorization(authorization)
        add_order(data, order_id)

        commit data
      end

      def void(authorization, options = {})
        data = {}
        add_action(data, :cancel)
        order_id, amount, currency = split_authorization(authorization)
        add_amount(data, amount, :currency => currency)
        add_order(data, order_id)

        commit data
      end

      def refund(money, authorization, options = {})
        data = {}
        add_action(data, :refund)
        add_amount(data, money, options)
        order_id, _, _ = split_authorization(authorization)
        add_order(data, order_id)

        commit data
      end

      private

      def add_action(data, action)
        data[:action] = transaction_code(action)
      end

      def add_amount(data, money, options)
        data[:amount] = amount(money).to_s
        data[:currency] = currency_code(options[:currency] || currency(money))
      end

      def add_order(data, order_id)
        raise ArgumentError.new("Invalid order_id format") unless(/^\d{4}[\da-zA-Z]{0,8}$/ =~ order_id)
        data[:order_id] = order_id
      end

      def url
        test? ? test_url : live_url
      end

      def add_creditcard(data, card)
        name  = [card.first_name, card.last_name].join(' ').slice(0, 60)
        year  = sprintf("%.4i", card.year)
        month = sprintf("%.2i", card.month)
        data[:card] = {
          :name => name,
          :pan  => card.number,
          :date => "#{year[2..3]}#{month}",
          :cvv  => card.verification_value
        }
      end

      def commit(data)
        headers = {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
        xml = build_xml_request(data)
        parse(ssl_post(url, "entrada=#{CGI.escape(xml)}", headers))
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
        str << @options[:secret_key]

        Digest::SHA1.hexdigest(str)
      end

      def build_xml_request(data)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.DATOSENTRADA do
          # Basic elements
          xml.DS_Version 0.1
          xml.DS_MERCHANT_CURRENCY          data[:currency]
          xml.DS_MERCHANT_AMOUNT            data[:amount]
          xml.DS_MERCHANT_ORDER             data[:order_id]
          xml.DS_MERCHANT_TRANSACTIONTYPE   data[:action]
          xml.DS_MERCHANT_TERMINAL          @options[:terminal]
          xml.DS_MERCHANT_MERCHANTCODE      @options[:login]
          xml.DS_MERCHANT_MERCHANTSIGNATURE build_signature(data)

          # Only when card is present
          if data[:card]
            xml.DS_MERCHANT_TITULAR    data[:card][:name]
            xml.DS_MERCHANT_PAN        data[:card][:pan]
            xml.DS_MERCHANT_EXPIRYDATE data[:card][:date]
            xml.DS_MERCHANT_CVV2       data[:card][:cvv]
          end
        end
        xml.target!
      end

      def parse(data)
        params  = {}
        success = false
        message = ""
        options = @options.merge(:test => test?)
        xml     = Nokogiri::XML(data)
        code    = xml.xpath("//RETORNOXML/CODIGO").text
        if code == "0"
          op = xml.xpath("//RETORNOXML/OPERACION")
          op.children.each do |element|
            params[element.name.downcase.to_sym] = element.text
          end

          if validate_signature(params)
            message = response_text(params[:ds_response])
            options[:authorization] = build_authorization(params)
            success = is_success_response?(params[:ds_response])
          else
            message = "Response failed validation check"
          end
        else
          # Some kind of programmer error with the request!
          message = "#{code} ERROR"
        end

        Response.new(success, message, params, options)
      end

      def validate_signature(data)
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

      def build_authorization(params)
        [params[:ds_order], params[:ds_amount], params[:ds_currency]].join("|")
      end

      def split_authorization(authorization)
        order_id, amount, currency = authorization.split("|")
        [order_id, amount.to_i, currency]
      end

      def currency_code(currency)
        return currency if currency =~ /^\d+$/
        CURRENCY_CODES[currency]
      end

      def transaction_code(type)
        SUPPORTED_TRANSACTIONS[type]
      end

      def response_text(code)
        code = code.to_i
        code = 0 if code < 100
        RESPONSE_TEXTS[code] || "Unkown code, please check in manual"
      end

      def is_success_response?(code)
        (code.to_i < 100) || [400, 481, 500, 900].include?(code.to_i)
      end
    end
  end
end
