module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QbmsGateway < Gateway
      API_VERSION = '4.0'

      class_attribute :test_url, :live_url

      self.test_url = "https://webmerchantaccount.ptc.quickbooks.com/j/AppGateway"
      self.live_url = "https://webmerchantaccount.quickbooks.com/j/AppGateway"

      self.homepage_url = 'http://payments.intuit.com/'
      self.display_name = 'QuickBooks Merchant Services'
      self.default_currency = 'USD'
      self.supported_cardtypes = [ :visa, :master, :discover, :american_express, :diners_club, :jcb ]
      self.supported_countries = [ 'US' ]

      TYPES = {
        :authorize => 'CustomerCreditCardAuth',
        :capture   => 'CustomerCreditCardCapture',
        :purchase  => 'CustomerCreditCardCharge',
        :refund    => 'CustomerCreditCardTxnVoidOrRefund',
        :void      => 'CustomerCreditCardTxnVoid',
        :query     => 'MerchantAccountQuery',
      }

      # Creates a new QbmsGateway
      #
      # The gateway requires that a valid app id, app login, and ticket be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The App Login (REQUIRED)
      # * <tt>:ticket</tt> -- The Connection Ticket. (REQUIRED)
      # * <tt>:pem</tt> -- The PEM-encoded SSL client key and certificate. (REQUIRED)
      # * <tt>:test</tt> -- +true+ or +false+. If true, perform transactions against the test server.
      #   Otherwise, perform transactions against the production server.
      #
      def initialize(options = {})
        requires!(options, :login, :ticket)
        test_mode = options[:test] || false
        @options = options
        super
      end

      # Performs an authorization, which reserves the funds on the customer's credit card, but does not
      # charge the card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      #
      def authorize(money, creditcard, options = {})
        commit(:authorize, money, options.merge(:credit_card => creditcard))
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      #
      def purchase(money, creditcard, options = {})
        commit(:purchase, money, options.merge(:credit_card => creditcard))
      end

      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      #
      def capture(money, authorization, options = {})
        commit(:capture, money, options.merge(:transaction_id => authorization))
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request.
      #
      def void(authorization, options = {})
        commit(:void, nil, options.merge(:transaction_id => authorization))
      end

      # Credit an account.
      #
      # This transaction is also referred to as a Refund and indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value in cents.
      # * <tt>identification</tt> -- The ID of the original transaction against which the credit is being issued.
      # * <tt>options</tt> -- A hash of parameters.
      #
      #
      def credit(money, identification, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options = {})
      end

      def refund(money, identification, options = {})
        commit(:refund, money, options.merge(:transaction_id => identification))
      end

      # Query the merchant account status
      def query
        commit(:query, nil, {})
      end

      def test?
        @options[:test] || super  
      end

      private

      def hosted?
        @options[:pem]
      end

      def commit(action, money, parameters)
        url = test? ? self.test_url : self.live_url

        type = TYPES[action]
        parameters[:trans_request_id] ||= SecureRandom.hex(10)

        req = build_request(type, money, parameters)
        data = ssl_post(url, req, "Content-Type" => "application/x-qbmsxml")
        response = parse(type, data)
        message = (response[:status_message] || '').strip

        Response.new(success?(response), message, response,
          :test          => test?,
          :authorization => response[:credit_card_trans_id],
          :fraud_review  => fraud_review?(response),
          :avs_result    => { :code => avs_result(response) },
          :cvv_result    => cvv_result(response)
        )
      end

      def success?(response)
        response[:status_code] == 0
      end

      def fraud_review?(response)
        [10100, 10101].member? response[:status_code]
      end

      def parse(type, body)
        xml = REXML::Document.new(body)

        signon = REXML::XPath.first(xml, "//SignonMsgsRs/#{hosted? ? 'SignonAppCertRs' : 'SignonDesktopRs'}")
        status_code = signon.attributes["statusCode"].to_i

        if status_code != 0
          return {
            :status_code    => status_code,
            :status_message => signon.attributes["statusMessage"],
          }
        end

        response = REXML::XPath.first(xml, "//QBMSXMLMsgsRs/#{type}Rs")

        results = {
          :status_code    => response.attributes["statusCode"].to_i,
          :status_message => response.attributes["statusMessage"],
        }

        response.elements.each do |e|
          name  = e.name.underscore.to_sym
          value = e.text()

          if old_value = results[name]
            results[name] = [old_value] if !old_value.kind_of?(Array)
            results[name] << value
          else
            results[name] = value
          end
        end

        results
      end

      def build_request(type, money, parameters = {})
        xml = Builder::XmlMarkup.new(:indent => 0)

        xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        xml.instruct!(:qbmsxml, :version => API_VERSION)

        xml.tag!("QBMSXML") do
          xml.tag!("SignonMsgsRq") do
            xml.tag!(hosted? ? "SignonAppCertRq" : "SignonDesktopRq") do
              xml.tag!("ClientDateTime", Time.now.xmlschema)
              xml.tag!("ApplicationLogin", @options[:login])
              xml.tag!("ConnectionTicket", @options[:ticket])
            end
          end

          xml.tag!("QBMSXMLMsgsRq") do
            xml.tag!("#{type}Rq") do
              method("build_#{type}").call(xml, money, parameters)
            end
          end
        end

        xml.target!
      end

      def build_CustomerCreditCardAuth(xml, money, parameters)
        cc = parameters[:credit_card]
        name = "#{cc.first_name} #{cc.last_name}"[0...30]

        xml.tag!("TransRequestID", parameters[:trans_request_id])
        xml.tag!("CreditCardNumber", cc.number)
        xml.tag!("ExpirationMonth", cc.month)
        xml.tag!("ExpirationYear", cc.year)
        xml.tag!("IsECommerce", "true")
        xml.tag!("Amount", amount(money))
        xml.tag!("NameOnCard", name)
        add_address(xml, parameters)
        xml.tag!("CardSecurityCode", cc.verification_value) if cc.verification_value?
      end

      def build_CustomerCreditCardCapture(xml, money, parameters)
        xml.tag!("TransRequestID", parameters[:trans_request_id])
        xml.tag!("CreditCardTransID", parameters[:transaction_id])
        xml.tag!("Amount", amount(money))
      end

      def build_CustomerCreditCardCharge(xml, money, parameters)
        cc = parameters[:credit_card]
        name = "#{cc.first_name} #{cc.last_name}"[0...30]

        xml.tag!("TransRequestID", parameters[:trans_request_id])
        xml.tag!("CreditCardNumber", cc.number)
        xml.tag!("ExpirationMonth", cc.month)
        xml.tag!("ExpirationYear", cc.year)
        xml.tag!("IsECommerce", "true")
        xml.tag!("Amount", amount(money))
        xml.tag!("NameOnCard", name)
        add_address(xml, parameters)
        xml.tag!("CardSecurityCode", cc.verification_value) if cc.verification_value?
      end

      def build_CustomerCreditCardTxnVoidOrRefund(xml, money, parameters)
        xml.tag!("TransRequestID", parameters[:trans_request_id])
        xml.tag!("CreditCardTransID", parameters[:transaction_id])
        xml.tag!("Amount", amount(money))
      end

      def build_CustomerCreditCardTxnVoid(xml, money, parameters)
        xml.tag!("TransRequestID", parameters[:trans_request_id])
        xml.tag!("CreditCardTransID", parameters[:transaction_id])
      end

      # Called reflectively by build_request
      def build_MerchantAccountQuery(xml, money, parameters)
      end

      def add_address(xml, parameters)
        if address = parameters[:billing_address] || parameters[:address]
          xml.tag!("CreditCardAddress", address[:address1][0...30])
          xml.tag!("CreditCardPostalCode", address[:zip][0...9])
        end
      end

      def cvv_result(response)
        case response[:card_security_code_match]
        when "Pass"         then 'M'
        when "Fail"         then 'N'
        when "NotAvailable" then 'P'
        end
      end

      def avs_result(response)
        case "#{response[:avs_street]}|#{response[:avs_zip]}"
        when "Pass|Pass"                 then "D"
        when "Pass|Fail"                 then "A"
        when "Pass|NotAvailable"         then "B"
        when "Fail|Pass"                 then "Z"
        when "Fail|Fail"                 then "C"
        when "Fail|NotAvailable"         then "N"
        when "NotAvailable|Pass"         then "P"
        when "NotAvailable|Fail"         then "N"
        when "NotAvailable|NotAvailable" then "U"
        end
      end
    end
  end
end
