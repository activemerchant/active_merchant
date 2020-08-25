require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    #
    # == Monei gateway
    # This class implements Monei gateway for Active Merchant. For more information about Monei
    # gateway please go to http://www.monei.net
    #
    # === Setup
    # In order to set-up the gateway you need four paramaters: sender_id, channel_id, login and pwd.
    # Request that data to Monei.
    class MoneiGateway < Gateway
      self.test_url = 'https://test.monei-api.net/payment/ctpe'
      self.live_url = 'https://monei-api.net/payment/ctpe'

      self.supported_countries = %w[AD AT BE BG CA CH CY CZ DE DK EE ES FI FO FR GB GI GR HU IE IL IS IT LI LT LU LV MT NL NO PL PT RO SE SI SK TR US VA]
      self.default_currency = 'EUR'
      self.supported_cardtypes = %i[visa master maestro jcb american_express]

      self.homepage_url = 'http://www.monei.net/'
      self.display_name = 'Monei'

      # Constructor
      #
      # options - Hash containing the gateway credentials, ALL MANDATORY
      #           :sender_id  Sender ID
      #           :channel_id Channel ID
      #           :login      User login
      #           :pwd        User password
      #
      def initialize(options={})
        requires!(options, :sender_id, :channel_id, :login, :pwd)
        super
      end

      # Public: Performs purchase operation
      #
      # money       - Amount of purchase
      # credit_card - Credit card
      # options     - Hash containing purchase options
      #               :order_id         Merchant created id for the purchase
      #               :billing_address  Hash with billing address information
      #               :description      Merchant created purchase description (optional)
      #               :currency         Sale currency to override money object or default (optional)
      #
      # Returns Active Merchant response object
      def purchase(money, credit_card, options={})
        execute_new_order(:purchase, money, credit_card, options)
      end

      # Public: Performs authorization operation
      #
      # money       - Amount to authorize
      # credit_card - Credit card
      # options     - Hash containing authorization options
      #               :order_id         Merchant created id for the authorization
      #               :billing_address  Hash with billing address information
      #               :description      Merchant created authorization description (optional)
      #               :currency         Sale currency to override money object or default (optional)
      #
      # Returns Active Merchant response object
      def authorize(money, credit_card, options={})
        execute_new_order(:authorize, money, credit_card, options)
      end

      # Public: Performs capture operation on previous authorization
      #
      # money         - Amount to capture
      # authorization - Reference to previous authorization, obtained from response object returned by authorize
      # options       - Hash containing capture options
      #                 :order_id         Merchant created id for the authorization (optional)
      #                 :description      Merchant created authorization description (optional)
      #                 :currency         Sale currency to override money object or default (optional)
      #
      # Note: you should pass either order_id or description
      #
      # Returns Active Merchant response object
      def capture(money, authorization, options={})
        execute_dependant(:capture, money, authorization, options)
      end

      # Public: Refunds from previous purchase
      #
      # money         - Amount to refund
      # authorization - Reference to previous purchase, obtained from response object returned by purchase
      # options       - Hash containing refund options
      #                 :order_id         Merchant created id for the authorization (optional)
      #                 :description      Merchant created authorization description (optional)
      #                 :currency         Sale currency to override money object or default (optional)
      #
      # Note: you should pass either order_id or description
      #
      # Returns Active Merchant response object
      def refund(money, authorization, options={})
        execute_dependant(:refund, money, authorization, options)
      end

      # Public: Voids previous authorization
      #
      # authorization - Reference to previous authorization, obtained from response object returned by authorize
      # options       - Hash containing capture options
      #                 :order_id         Merchant created id for the authorization (optional)
      #
      # Returns Active Merchant response object
      def void(authorization, options={})
        execute_dependant(:void, nil, authorization, options)
      end

      # Public: Verifies credit card. Does this by doing a authorization of 1.00 Euro and then voiding it.
      #
      # credit_card - Credit card
      # options     - Hash containing authorization options
      #               :order_id         Merchant created id for the authorization
      #               :billing_address  Hash with billing address information
      #               :description      Merchant created authorization description (optional)
      #               :currency         Sale currency to override money object or default (optional)
      #
      # Returns Active Merchant response object of Authorization operation
      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      # Private: Execute purchase or authorize operation
      def execute_new_order(action, money, credit_card, options)
        request = build_request do |xml|
          add_identification_new_order(xml, options)
          add_payment(xml, action, money, options)
          add_account(xml, credit_card)
          add_customer(xml, credit_card, options)
          add_three_d_secure(xml, options)
        end

        commit(request)
      end

      # Private: Execute operation that depends on authorization code from previous purchase or authorize operation
      def execute_dependant(action, money, authorization, options)
        request = build_request do |xml|
          add_identification_authorization(xml, authorization, options)
          add_payment(xml, action, money, options)
        end

        commit(request)
      end

      # Private: Build XML wrapping code yielding to code to fill the transaction information
      def build_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.Request(version: '1.0') do
            xml.Header { xml.Security(sender: @options[:sender_id]) }
            xml.Transaction(mode: test? ? 'CONNECTOR_TEST' : 'LIVE', response: 'SYNC', channel: @options[:channel_id]) do
              xml.User(login: @options[:login], pwd: @options[:pwd])
              yield xml
            end
          end
        end
        builder.to_xml
      end

      # Private: Add identification part to XML for new orders
      def add_identification_new_order(xml, options)
        requires!(options, :order_id)
        xml.Identification do
          xml.TransactionID options[:order_id]
        end
      end

      # Private: Add identification part to XML for orders that depend on authorization from previous operation
      def add_identification_authorization(xml, authorization, options)
        xml.Identification do
          xml.ReferenceID authorization
          xml.TransactionID options[:order_id]
        end
      end

      # Private: Add payment part to XML
      def add_payment(xml, action, money, options)
        code = tanslate_payment_code(action)

        xml.Payment(code: code) do
          xml.Presentation do
            xml.Amount amount(money)
            xml.Currency options[:currency] || currency(money)
            xml.Usage options[:description] || options[:order_id]
          end unless money.nil?
        end
      end

      # Private: Add account part to XML
      def add_account(xml, credit_card)
        xml.Account do
          xml.Holder credit_card.name
          xml.Number credit_card.number
          xml.Brand credit_card.brand.upcase
          xml.Expiry(month: credit_card.month, year: credit_card.year)
          xml.Verification credit_card.verification_value
        end
      end

      # Private: Add customer part to XML
      def add_customer(xml, credit_card, options)
        requires!(options, :billing_address)
        address = options[:billing_address]
        xml.Customer do
          xml.Name do
            xml.Given credit_card.first_name
            xml.Family credit_card.last_name
          end
          xml.Address do
            xml.Street address[:address1].to_s
            xml.Zip address[:zip].to_s
            xml.City address[:city].to_s
            xml.State address[:state].to_s if address.has_key? :state
            xml.Country address[:country].to_s
          end
          xml.Contact do
            xml.Email options[:email] || 'noemail@monei.net'
            xml.Ip options[:ip] || '0.0.0.0'
          end
        end
      end

      # Private : Convert ECI to ResultIndicator
      # Possible ECI values:
      # 02 or 05 - Fully Authenticated Transaction
      # 00 or 07 - Non 3D Secure Transaction
      # Possible ResultIndicator values:
      # 01 = MASTER_3D_ATTEMPT
      # 02 = MASTER_3D_SUCCESS
      # 05 = VISA_3D_SUCCESS
      # 06 = VISA_3D_ATTEMPT
      # 07 = DEFAULT_E_COMMERCE
      def eci_to_result_indicator(eci)
        case eci
        when '02', '05'
          return eci
        else
          return '07'
        end
      end

      # Private : Add the 3DSecure infos to XML
      def add_three_d_secure(xml, options)
        if options[:three_d_secure]
          xml.Authentication(type: '3DSecure') do
            xml.ResultIndicator eci_to_result_indicator options[:three_d_secure][:eci]
            xml.Parameter(name: 'VERIFICATION_ID') { xml.text options[:three_d_secure][:cavv] }
            xml.Parameter(name: 'XID') { xml.text options[:three_d_secure][:xid] }
          end
        end
      end

      # Private: Parse XML response from Monei servers
      def parse(body)
        xml = Nokogiri::XML(body)
        {
          unique_id: xml.xpath('//Response/Transaction/Identification/UniqueID').text,
          status: translate_status_code(xml.xpath('//Response/Transaction/Processing/Status/@code').text),
          reason: translate_status_code(xml.xpath('//Response/Transaction/Processing/Reason/@code').text),
          message: xml.xpath('//Response/Transaction/Processing/Return').text
        }
      end

      # Private: Send XML transaction to Monei servers and create AM response
      def commit(xml)
        url = (test? ? test_url : live_url)

        response = parse(ssl_post(url, post_data(xml), 'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8'))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      # Private: Decide success from servers response
      def success_from(response)
        response[:status] == :success || response[:status] == :new
      end

      # Private: Get message from servers response
      def message_from(response)
        response[:message]
      end

      # Private: Get error code from servers response
      def error_code_from(response)
        success_from(response) ? nil : STANDARD_ERROR_CODE[:card_declined]
      end

      # Private: Get authorization code from servers response
      def authorization_from(response)
        response[:unique_id]
      end

      # Private: Encode POST parameters
      def post_data(xml)
        "load=#{CGI.escape(xml)}"
      end

      # Private: Translate Monei status code to native ruby symbols
      def translate_status_code(code)
        {
          '00' => :success,
          '40' => :neutral,
          '59' => :waiting_bank,
          '60' => :rejected_bank,
          '64' => :waiting_risk,
          '65' => :rejected_risk,
          '70' => :rejected_validation,
          '80' => :waiting,
          '90' => :new
        }[code]
      end

      # Private: Translate AM operations to Monei operations codes
      def tanslate_payment_code(action)
        {
          purchase: 'CC.DB',
          authorize: 'CC.PA',
          capture: 'CC.CP',
          refund: 'CC.RF',
          void: 'CC.RV'
        }[action]
      end
    end
  end
end
