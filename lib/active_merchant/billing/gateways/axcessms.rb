module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AxcessmsGateway < Gateway
      self.test_url = "https://test.ctpe.io/payment/ctpe"
      self.live_url = "https://ctpe.io/payment/ctpe"

      self.supported_countries = %w(AD AT BE BG BR CA CH CY CZ DE DK EE ES FI FO FR GB
                                    GI GR HR HU IE IL IM IS IT LI LT LU LV MC MT MX NL
                                    NO PL PT RO RU SE SI SK TR US VA)

      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :solo]

      self.homepage_url = "http://www.axcessms.com/"
      self.display_name = "Axcess MS"
      self.money_format = :dollars
      self.default_currency = "GBP"

      API_VERSION = "1.0"
      PAYMENT_CODE_PREAUTHORIZATION = "CC.PA"
      PAYMENT_CODE_DEBIT = "CC.DB"
      PAYMENT_CODE_CAPTURE = "CC.CP"
      PAYMENT_CODE_REVERSAL = "CC.RV"
      PAYMENT_CODE_REFUND = "CC.RF"
      PAYMENT_CODE_REBILL = "CC.RB"

      def initialize(options={})
        requires!(options, :sender, :login, :password, :channel)
        super
      end

      def purchase(money, payment, options={})
        payment_code = payment.respond_to?(:number) ? PAYMENT_CODE_DEBIT : PAYMENT_CODE_REBILL
        commit(payment_code, money, payment, options)
      end

      def authorize(money, authorization, options={})
        commit(PAYMENT_CODE_PREAUTHORIZATION, money, authorization, options)
      end

      def capture(money, authorization, options={})
        commit(PAYMENT_CODE_CAPTURE, money, authorization, options)
      end

      def refund(money, authorization, options={})
        commit(PAYMENT_CODE_REFUND, money, authorization, options)
      end

      def void(authorization, options={})
        commit(PAYMENT_CODE_REVERSAL, nil, authorization, options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def commit(paymentcode, money, payment, options)
        options[:mode] ||= (test? ? "INTEGRATOR_TEST" : "LIVE")
        request = build_request(paymentcode, money, payment, options)

        headers = {
          "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8"
        }

        response = parse(ssl_post((test? ? test_url : live_url), "load=#{CGI.escape(request)}", headers))
        success = (response[:result] == "ACK")
        message = "#{response[:reason]} - #{response[:return]}"
        authorization = response[:unique_id]

        Response.new(success, message, response,
          :authorization => authorization,
          :test => (response[:mode] != "LIVE")
        )
      end

      def parse(body)
        return {} if body.blank?

        xml = REXML::Document.new(body)

        response = {}
        xml.root.elements.to_a.each do |node|
          parse_element(response, node)
        end

        response[:mode] = REXML::XPath.first(xml, "//Transaction").attributes["mode"]

        response
      end

      def parse_element(response, node)
        if node.has_attributes?
          node.attributes.each{|name, value| response["#{node.name}_#{name}".underscore.to_sym] = value }
        end

        if node.has_elements?
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def build_request(payment_code, money, payment, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! "Request", "version" => API_VERSION do
          xml.tag! "Header" do
            xml.tag! "Security", "sender" => @options[:sender]
          end
          xml.tag! "Transaction", "mode" => options[:mode], "channel" => @options[:channel], "response" => "SYNC" do
            xml.tag! "User", "login" => @options[:login], "pwd" => @options[:password]
            xml.tag! "Identification" do
              xml.tag! "TransactionID", options[:order_id] || generate_unique_id
              xml.tag! "ReferenceID", payment unless payment.respond_to?(:number)
            end

            xml.tag! "Payment", "code" => payment_code do
              xml.tag! "Memo", options[:memo] unless options[:memo].blank?
              xml.tag! "Presentation" do
                xml.tag! "Amount", amount(money)
                xml.tag! "Currency", (options[:currency] || currency(money))
                xml.tag! "Usage", options[:description]
              end
            end

            if payment.respond_to?(:number)
              add_payment(xml, payment)

              xml.tag! "Customer" do
                add_customer_name(xml, payment)
                add_address(xml, options[:billing_address] || options[:address])
                add_contact(xml, options)
              end
            end
          end
        end

        xml.target!
      end

      def add_contact(xml, options)
        xml.tag! "Contact" do
          xml.tag! "Email", (options[:email] || "unknown@example.com")
          xml.tag! "Ip", (options[:ip] || "127.0.0.1")
        end
      end

      def add_customer_name(xml, payment)
        xml.tag! "Name" do
          xml.tag! "Given", payment.first_name
          xml.tag! "Family", payment.last_name
        end
      end

      def add_payment(xml, payment)
        xml.tag! "Account" do
          xml.tag! "Number", payment.number
          xml.tag! "Holder", payment.name
          xml.tag! "Brand", payment.brand
          xml.tag! "Expiry", "month" => payment.month, "year" => payment.year
          xml.tag! "Verification", payment.verification_value
        end
      end

      def add_address(xml, address)
        raise ArgumentError.new("Address is required") unless address
        xml.tag! "Address" do
          xml.tag! "Street", "#{address[:address1]} #{address[:address2]}".strip
          xml.tag! "City", address[:city]
          xml.tag! "State", address[:state]
          xml.tag! "Zip", address[:zip]
          xml.tag! "Country", address[:country]
        end
      end
    end
  end
end
