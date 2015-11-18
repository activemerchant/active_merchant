require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BridgePayGateway < Gateway
      self.display_name = "BridgePay"
      self.homepage_url = "http://www.bridgepaynetwork.com/"

      self.test_url = "https://gatewaystage.itstgate.com/SmartPayments/transact.asmx"
      self.live_url = "https://gateway.itstgate.com/SmartPayments/transact.asmx"

      self.supported_countries = ["CA", "US"]
      self.default_currency = "USD"
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]


      def initialize(options={})
        requires!(options, :user_name, :password)
        super
      end

      def purchase(amount, payment_method, options={})
        post = initialize_required_fields("Sale")

        # Allow the same amount in multiple transactions.
        post[:ExtData] = "<Force>T</Force>"
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(post)
      end

      def authorize(amount, payment_method, options={})
        post = initialize_required_fields("Auth")

        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(post)
      end

      def capture(amount, authorization, options={})
        post = initialize_required_fields("Force")

        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit(post)
      end

      def refund(amount, authorization, options={})
        post = initialize_required_fields("Return")

        add_invoice(post, amount, options)
        add_reference(post, authorization)

        commit(post)
      end

      def void(authorization, options={})
        post = initialize_required_fields("Void")

        add_reference(post, authorization)

        commit(post)
      end

      def verify(creditcard, options = {})
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
          gsub(%r((&?CardNum=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?CVNum=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?Password=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?TransitNum=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?AccountNum=)[^&]*)i, '\1[FILTERED]')
      end

      private

      def add_payment_method(post, payment_method)
        if payment_method.respond_to? :brand
          post[:NameOnCard] = payment_method.name if payment_method.name
          post[:ExpDate]    = expdate(payment_method)
          post[:CardNum]    = payment_method.number
          post[:CVNum]      = payment_method.verification_value
        else
          post[:CheckNum] = payment_method.number
          post[:TransitNum] = payment_method.routing_number
          post[:AccountNum] = payment_method.account_number
          post[:NameOnCheck] = payment_method.name
          post[:ExtData] = "<AccountType>#{payment_method.account_type.capitalize}</AccountType>"
        end
      end

      def initialize_required_fields(transaction_type)
        post = {}
        post[:TransType] = transaction_type
        post[:Amount] = ""
        post[:PNRef] = ""
        post[:InvNum] = ""
        post[:CardNum] = ""
        post[:ExpDate] = ""
        post[:MagData] = ""
        post[:NameOnCard] = ""
        post[:Zip] = ""
        post[:Street] = ""
        post[:CVNum] = ""
        post[:MagData] = ""
        post[:ExtData] = ""
        post[:MICR] = ""
        post[:DL] = ""
        post[:SS] = ""
        post[:DOB] = ""
        post[:StateCode] = ""
        post[:CheckType] = ""
        post
      end

      def add_customer_data(post, options)
        if(billing_address = (options[:billing_address] || options[:address]))
          post[:Street] = billing_address[:address1]
          post[:Zip]    = billing_address[:zip]
        end
      end

      def add_invoice(post, amount, options)
        post[:Amount] = amount(amount)
        post[:InvNum] = options[:order_id]
      end

      def expdate(creditcard)
        "#{format(creditcard.month, :two_digits)}#{format(creditcard.year, :two_digits)}"
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.root.xpath("*").each do |node|
          if (node.elements.size == 0)
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = childnode.text
            end
          end
        end unless doc.root.nil?

        response
      end

      def commit(parameters)
        url = url(parameters[:TransitNum] ? 'ProcessCheck' : 'ProcessCreditCard')
        data = post_data(parameters)
        raw = parse(ssl_post(url, data))

        Response.new(
          success_from(raw),
          message_from(raw),
          raw,
          authorization: authorization_from(raw),
          test: test?
        )
      end

      def url(action)
        base = test? ? test_url : live_url
        "#{base}/#{action}"
      end

      def success_from(response)
        response[:result] == "0"
      end

      def message_from(response)
        response[:respmsg] || response[:message]
      end

      def authorization_from(response)
        [response[:authcode], response[:pnref]].join("|")
      end

      def split_authorization(authorization)
        authcode, pnref = authorization.split("|")
        [authcode, pnref]
      end

      def add_reference(post, authorization)
        authcode, pnref = split_authorization(authorization)
        post[:AuthCode] = authcode
        post[:PNRef] = pnref
      end

      def post_data(post)
        {
          :UserName => @options[:user_name],
          :Password => @options[:password]
        }.merge(post).collect{|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join("&")
      end
    end
  end
end
