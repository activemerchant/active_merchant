module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantWareVersionFourGateway < Gateway
      self.live_url = 'https://ps1.merchantware.net/Merchantware/ws/RetailTransaction/v4/Credit.asmx'
      self.test_url = 'https://staging.merchantware.net/Merchantware/ws/RetailTransaction/v4/Credit.asmx'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://merchantwarehouse.com/merchantware'
      self.display_name = 'MerchantWARE'

      ENV_NAMESPACES = { "xmlns:xsi"  => "http://www.w3.org/2001/XMLSchema-instance",
                         "xmlns:xsd"  => "http://www.w3.org/2001/XMLSchema",
                         "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/" }

      TX_NAMESPACE = "http://schemas.merchantwarehouse.com/merchantware/40/Credit/"

      ACTIONS = {
        :purchase  => "SaleKeyed",
        :reference_purchase => 'RepeatSale',
        :authorize => "PreAuthorizationKeyed",
        :capture   => "PostAuthorization",
        :void      => "VoidPreAuthorization",
        :refund    => "Refund"
      }

      # Creates a new MerchantWareVersionFourGateway
      #
      # The gateway requires that a valid login, password, and name be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> - The MerchantWARE SiteID.
      # * <tt>:password</tt> - The MerchantWARE Key.
      # * <tt>:name</tt> - The MerchantWARE Name.
      def initialize(options = {})
        requires!(options, :login, :password, :name)
        super
      end

      # Authorize a credit card for a given amount.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be authorized as an Integer value in cents.
      # * <tt>credit_card</tt> - The CreditCard details for the transaction.
      # * <tt>options</tt>
      #   * <tt>:order_id</tt> - A unique reference for this order (required).
      #   * <tt>:billing_address</tt> - The billing address for the cardholder.
      def authorize(money, credit_card, options = {})
        request = build_purchase_request(:authorize, money, credit_card, options)
        commit(:authorize, request)
      end

      # Authorize and immediately capture funds from a credit card.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be authorized as anInteger value in cents.
      # * <tt>payment_source</tt> - The CreditCard details or 'token' from prior transaction
      # * <tt>options</tt>
      #   * <tt>:order_id</tt> - A unique reference for this order (required).
      #   * <tt>:billing_address</tt> - The billing address for the cardholder.
      def purchase(money, payment_source, options = {})
        action = payment_source.is_a?(String) ? :reference_purchase : :purchase
        request = build_purchase_request(action, money, payment_source, options)
        commit(action, request)
      end

      # Capture authorized funds from a credit card.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured as anInteger value in cents.
      # * <tt>authorization</tt> - The authorization string returned from the initial authorization.
      def capture(money, authorization, options = {})
        request = build_capture_request(:capture, money, authorization, options)
        commit(:capture, request)
      end

      # Void a transaction.
      #
      # ==== Parameters
      # * <tt>authorization</tt> - The authorization string returned from the initial authorization or purchase.
      def void(authorization, options = {})
        reference, options[:order_id] = split_reference(authorization)
        request = soap_request(:void) do |xml|
          add_reference_token(xml, reference)
        end
        commit(:void, request)
      end

      # Refund an amount back a cardholder
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be refunded as an Integer value in cents.
      # * <tt>identification</tt> - The credit card you want to refund or the authorization for the existing transaction you are refunding.
      # * <tt>options</tt>
      #   * <tt>:order_id</tt> - A unique reference for this order (required when performing a non-referenced credit)
      def refund(money, identification, options = {})
        reference, options[:order_id] = split_reference(identification)

        request = soap_request(:refund) do |xml|
          add_reference_token(xml, reference)
          add_invoice(xml, options)
          add_amount(xml, money, "overrideAmount")
        end

        commit(:refund, request)
      end

      private

      def soap_request(action)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! "soap:Envelope", ENV_NAMESPACES do
          xml.tag! "soap:Body" do
            xml.tag! ACTIONS[action], "xmlns" => TX_NAMESPACE do
              xml.tag! "merchantName", @options[:name]
              xml.tag! "merchantSiteId", @options[:login]
              xml.tag! "merchantKey", @options[:password]
              yield xml
            end
          end
        end
        xml.target!
      end

      def build_purchase_request(action, money, payment_source, options)
        requires!(options, :order_id)

        request = soap_request(action) do |xml|
          add_invoice(xml, options)
          add_amount(xml, money)
          add_payment_source(xml, payment_source)
          add_address(xml, options)
        end
      end

      def build_capture_request(action, money, identification, options)
        reference, options[:order_id] = split_reference(identification)

        request = soap_request(action) do |xml|
          add_reference_token(xml, reference)
          add_invoice(xml, options)
          add_amount(xml, money)
        end
      end

      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end

      def add_invoice(xml, options)
        xml.tag! "invoiceNumber", options[:order_id].to_s.gsub(/[^\w]/, '').slice(0, 25)
      end

      def add_amount(xml, money, tag = "amount")
        xml.tag! tag, amount(money)
      end

      def add_reference_token(xml, reference)
        xml.tag! "token", reference
      end

      def add_address(xml, options)
        address = options[:billing_address] || options[:address] || {}
        xml.tag! "avsStreetAddress", address[:address1]
        xml.tag! "avsStreetZipCode", address[:zip]
      end

      def add_payment_source(xml, source)
        if source.is_a?(String)
          add_reference_token(xml, source)
        else
          add_credit_card(xml, source)
        end
      end

      def add_credit_card(xml, credit_card)
        xml.tag! "cardNumber", credit_card.number
        xml.tag! "expirationDate", expdate(credit_card)
        xml.tag! "cardholder", credit_card.name
        xml.tag! "cardSecurityCode", credit_card.verification_value if credit_card.verification_value?
      end

      def split_reference(reference)
        reference.to_s.split(";")
      end

      def parse(action, data)
        response = {}
        xml = REXML::Document.new(data)

        root = REXML::XPath.first(xml, "//#{ACTIONS[action]}Response/#{ACTIONS[action]}Result")

        root.elements.each do |element|
          response[element.name] = element.text
        end

        if response["ErrorMessage"].present?
          response[:message] = response["ErrorMessage"]
          response[:success] = false
        else
          status, code, message = response["ApprovalStatus"].split(";")
          response[:status] = status

          if response[:success] = status == "APPROVED"
            response[:message] = status
          else
            response[:message] = message
            response[:failure_code] = code
          end
        end

        response
      end

      def parse_error(http_response, action)
        response = {}
        response[:http_code] = http_response.code
        response[:http_message] = http_response.message
        response[:success] = false

        document = REXML::Document.new(http_response.body)
        node = REXML::XPath.first(document, "//#{ACTIONS[action]}Response/#{ACTIONS[action]}Result")

        node.elements.each do |element|
          response[element.name] = element.text
        end

        response[:message] = response["ErrorMessage"].to_s.gsub("\n", " ")
        response
      rescue REXML::ParseException => e
        response[:http_body]        = http_response.body
        response[:message]          = "Failed to parse the failed response"
        response
      end

      def soap_action(action)
        "#{TX_NAMESPACE}#{ACTIONS[action]}"
      end

      def url
        test? ? test_url : live_url
      end

      def commit(action, request)
        begin
          data = ssl_post(url, request,
                   "Content-Type" => 'text/xml; charset=utf-8',
                   "SOAPAction"   => soap_action(action)
                 )
          response = parse(action, data)
        rescue ActiveMerchant::ResponseError => e
          response = parse_error(e.response, action)
        end

        Response.new(response[:success], response[:message], response,
          :test => test?,
          :authorization => authorization_from(response),
          :avs_result => { :code => response["AvsResponse"] },
          :cvv_result => response["CvResponse"]
        )
      end

      def authorization_from(response)
        response['Token']
      end
    end
  end
end
