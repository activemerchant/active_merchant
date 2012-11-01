# coding: utf-8
require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # = Redsys Merchant Gateway
    #
    # The Spanish Redsys system is used mainly by members of the Servired
    # system, widely used throught Spain. This library has been developed
    # using CATALUNYA CAIXA.
    #
    # Much of the code for this library is based on the active_merchant_sermepa
    # integration gateway which uses essentially the same API but with the
    # banks own payment screen.
    #
    # == Example use:
    #
    #   gateway = ActiveMerchant::Billing::RedsysGateway.new(
    #               :terminal   => "1",
    #               :merchant   => "091358382",
    #               :secret_key => "qwertyasdf0123456789",
    #            )
    #
    #   # Create a credit card
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #     :type       => 'visa',
    #     :number     => '4792587766554414',
    #     :month      => 10,
    #     :year       => 2015,
    #     :cvv        => '123'
    #     :first_name => 'Bob',
    #     :last_name  => 'Bobsen'
    #   )
    #
    # The Gateway requires an order_id to be provided with each transaction
    # of a specific format. Unfortunately this cannot be generated automatically
    # remotely. The rules are as follows:
    #
    #  * Minimum length: 4
    #  * Maximum length: 12
    #  * First 4 digits must be numerical
    #  * Remaining 8 digits may be alphanumeric
    #
    # The following regular expression could be used to match an order_id:
    #
    #   /^(\d{4})([0-9a-zA-Z]){0,12}$/
    #
    # Performing purchases is as you would expect:
    #
    #   # Run a purchase for 10 euros
    #   response = gateway.purchase(1000, creditcard, :order_id => "123456")
    #
    #   puts reponse.success?       # Check if successful
    #
    #   # Partially refund the purchase
    #   response = gateway.refund(500, "123456")
    #
    #

    class RedsysGateway < Gateway

      self.live_url = "https://sis.sermepa.es/sis/operaciones"
      self.test_url = "https://sis-t.sermepa.es:25443/sis/operaciones"

      # Sensible region specific defaults.
      self.supported_countries = ['ES']
      self.default_currency    = 'EUR'
      self.money_format        = :cents

      # Not all card types may be actived by the bank!
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

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


      def initialize(options = {})
        requires!(options, :terminal, :merchant, :secret_key)
        @options = options
        super
      end

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)
        commit :authorize, money do |data|
          add_creditcard(data, creditcard)
        end
      end

      def capture(money, order_id, options = {})
        commit :capture, money, options.update(:order_id => order_id)
      end

      def void(order_id, options = {})
        commit :cancel, nil, options.update(:order_id => order_id)
      end

      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)
        commit :purchase, money do |data|
          add_creditcard(data, creditcard)
        end
      end

      def refund(money, order_id, options = {})
        commit :cancel, money, options.update(:order_id => order_id)
      end

      def test?
        @options[:test] || super
      end


      private

      def url
        test? ? test_url : live_url
      end

      def add_amount(data, money)
        data[:amount] = money.to_s
      end

      def add_order_id(data, order_id)
        data[:order_id] = order_id
      end

      def add_currency(data, currency)
        data[:currency] = currenct_code(currency || self.class.default_currency)
      end

      def add_creditcard(data, card)
        name  = [card.first_name, card.last_name].join(' ').slice(0, 60)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)
        data[:card] = {
          :name => name,
          :pan  => card.number,
          :expiry_date => "#{month}#{year[2..3]}",
          :cvv  => card.verification_value
        }
      end

      # Generate a signature authenticating the current request.
      # Values included in the signature are determined by the the type of
      # transaction.
      def add_signature(action, data)
        str = data[:amount] +
              data[:order_id].to_s +
              @options[:merchant] +
              data[:currency]

        if [:authorize, :purchase].include?(action)
          card = data[:card]
          str << card[:pan]
          str << card[:cvv].to_s # may be blank
        end

        str << data[:action]
        str << @options[:secret_key]

        data[:signature] = Digest::SHA1.hexdigest(str)
      end


      def commit(action, money, options = {})
        data = {:action => transaction_code(action)}

        add_amount(data, money)
        add_currency(data, options[:currency])
        add_order_id(data, options[:order_id])

        yield(data) if block_given?

        add_signature(action, data)
        xml = build_xml_request(data)

        headers = {}
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
        parse(ssl_post(url, "entrada=#{CGI.escape(xml.to_s)}", headers))
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
          xml.DS_MERCHANT_MERCHANTCODE      @options[:merchant]
          xml.DS_MERCHANT_MERCHANTSIGNATURE data[:signature]

          # Only when card is present
          if data[:card]
            xml.DS_MERCHANT_TITULAR    data[:card][:name]
            xml.DS_MERCHANT_PAN        data[:card][:pan]
            xml.DS_MERCHANT_EXPIRYDATE data[:card][:expiry_data]
            xml.DS_MERCHANT_CVV2       data[:card][:cvv]
          end
        end
        xml.target!
      end

      def parse(data)
        params  = {}
        success = false
        message = ""
        xml     = REXML::Document.new(data)
        code    = REXML::XPath.first(xml, "//RETORNOXML/CODE").text
        if code == "0"
          op = REXML::XPath.first(xml, "//RETORNOXML/OPERACION")
          op.elements.each do |element|
            params[element.name.downcase.to_sym] = element.text
          end

          # Check the data we received
          if validate_signature(params)
            message = response_text(reply[:ds_response])
            @options[:authorization] = params[:ds_order]
            success = is_success_response?(params[:ds_response])
          else
            message = "Response failed validation check"
          end
        else
          # Something very wrong with the request!
          message = "Fatal error with code: #{code}"
        end

        Response.new(success, message, params, @options)
      end

      def validate_signature(data)
        str = data[:ds_amount] +
              data[:ds_order].to_s +
              @options[:merchant] +
              data[:ds_currency] +
              data[:ds_response] +
              data[:ds_cardnumber].to_s +
              data[:ds_transaction_type].to_s +
              data[:ds_securepayment].to_s +
              @options[:secret_key]

        data[:ds_signature].to_s.downcase == Digest::SHA1.hexdigest(str)
      end


      def currency_code(currency)
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
