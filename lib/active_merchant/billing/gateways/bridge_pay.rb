require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BridgePayGateway < Gateway
      self.display_name = 'BridgePay'
      self.homepage_url = 'http://www.bridgepaynetwork.com/'

      self.test_url = 'https://gatewaystage.itstgate.com/SmartPayments/transact.asmx/ProcessCreditCard'
      self.live_url = 'https://gateway.itstgate.com/SmartPayments/transact.asmx/ProcessCreditCard'

      self.supported_countries = ['US','CA']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]


      def initialize(options={})
        requires!(options, :user_name, :password)
        super
      end

      def purchase(amount, creditcard, options={})
        post = post_required_fields
        post[:TransType] = 'Sale'
        add_invoice(post, amount, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, options)

        commit('purchase', post)
      end

      def authorize(amount, creditcard, options={})
        post = post_required_fields
        post[:TransType] = 'Auth'
        add_invoice(post, amount, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, options)

        resp = commit('authorize', post)
      end

      def capture(amount, authorization, options={})
        post = post_required_fields
        post[:TransType] = 'Force'
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit('capture', post)
      end

      def refund(amount, authorization, options={})
        post = post_required_fields
        post[:TransType] = 'Reversal'
        add_reference(post, authorization)

        commit('refund', post)
      end

      def void(authorization, options={})
        post = post_required_fields
        post[:TransType] = 'Void'
        add_reference(post, authorization)

        commit('void', post)
      end

      private

      def post_required_fields
        post = {}
        post[:Amount] = ''
        post[:PNRef] = ''
        post[:InvNum] = ''
        post[:CardNum] = ''
        post[:ExpDate] = ''
        post[:MagData] = ''
        post[:NameOnCard] = ''
        post[:Zip] = ''
        post[:Street] = ''
        post[:CVNum] = ''
        post[:MagData] = ''
        # Allow the same amount in multiple transactions.
        post[:ExtData] = '<Force>T</Force>'
        post
      end

      def add_customer_data(post, options)
        if(billing_address = (options[:billing_address] || options[:address]))
          post[:Street]        = billing_address[:address1]
          post[:Zip]           = billing_address[:zip]
        end
      end

      def add_invoice(post, amount, options)
        post[:Amount] = amount(amount)
        post[:InvNum] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:NameOnCard]             = creditcard.name if creditcard.name
        post[:ExpDate]                = expdate(creditcard)
        post[:CardNum]                = creditcard.number
        post[:CVNum]                  = creditcard.verification_value
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

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        data = post_data(action, parameters)
        raw = parse(ssl_post(url, data))

        Response.new(
          success_from(raw[:message]),
          message_from(raw),
          raw,
          authorization: authorization_from(raw),
          test: test?
        )
      end

      def success_from(result)
        case result
        when "APPROVAL"
          true
        else
          false
        end
      end

      def message_from(response)
        response[:respmsg]
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

      def post_data(action, parameters = {})
        post = post_required_fields
        post[:UserName] = @options[:user_name]
        post[:Password] = @options[:password]
        post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end
