require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetaxeptGateway < Gateway
      self.test_url = 'https://epayment-test.bbs.no/'
      self.live_url = 'https://epayment.bbs.no/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['NO', 'DK', 'SE', 'FI']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.betalingsterminal.no/Netthandel-forside/'

      # The name of the gateway
      self.display_name = 'BBS Netaxept'

      self.money_format = :cents

      self.default_currency = 'NOK'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        MultiResponse.run do |r|
          r.process{authorize(money, creditcard, options)}
          r.process{capture(money, r.authorization, options)}
        end
      end

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)

        MultiResponse.run do |r|
          r.process{setup_transaction(money, options)}
          r.process{add_and_auth_credit_card(r.authorization, creditcard, options)}
          r.process{query_transaction(r.authorization, options)}
        end
      end

      def capture(money, authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization, money)
        post[:operation] = "Capture"
        commit("Netaxept/process.aspx", post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization, money)
        post[:operation] = "Credit"
        commit("Netaxept/process.aspx", post)
      end

      def void(authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization)
        post[:operation] = "Annul"
        commit("Netaxept/process.aspx", post)
      end

      private

      def setup_transaction(money, options)
        post = {}
        add_credentials(post, options)
        add_order(post, money, options)
        commit("Netaxept/Register.aspx", post)
      end

      def add_and_auth_credit_card(authorization, creditcard, options)
        post = {}
        add_credentials(post, options, false)
        add_authorization(post, authorization)
        add_creditcard(post, creditcard)
        commit("terminal/default.aspx", post, false)
      end

      def query_transaction(authorization, options)
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization)
        commit("Netaxept/query.aspx", post)
      end

      def add_credentials(post, options, secure=true)
        post[:merchantId] = @options[:login]
        post[:token] = @options[:password] if secure
      end

      def add_authorization(post, authorization, money=nil)
        post[:transactionId] = authorization
        post[:transactionAmount] = amount(money) if money
      end

      def add_order(post, money, options)
        post[:serviceType] = 'M'
        post[:orderNumber] = options[:order_id]
        post[:amount] = amount(money)
        post[:currencyCode] = (options[:currency] || currency(money))
        post[:autoAuth] = "true"
      end

      def add_creditcard(post, options)
        post[:pan] = options.number
        post[:expiryDate] = format(options.month, :two_digits) + format(options.year, :two_digits)
        post[:securityCode] = options.verification_value
      end

      def commit(path, parameters, xml=true)
        raw = parse(ssl_get(build_url(path, parameters)), xml)

        success = false
        authorization = (raw["TransactionId"] || parameters[:transactionId])
        if raw[:container] =~ /Exception|Error/
          message = (raw["Message"] || raw["Error"]["Message"])
        elsif raw["Error"] && !raw["Error"].empty?
          message = (raw["Error"]["ResponseText"] || raw["Error"]["ResponseCode"])
        else
          message = (raw["ResponseText"] || raw["ResponseCode"] || "OK")
          success = true
        end

        Response.new(
          success,
          message,
          raw,
          :test => test?,
          :authorization => authorization
        )
      end

      def parse(result, expects_xml=true)
        if expects_xml
          doc = REXML::Document.new(result)
          extract_xml(doc.root).merge(:container => doc.root.name)
        else
          {:result => result}
        end
      end

      def extract_xml(element)
        if element.has_elements?
          hash = {}
          element.elements.each do |e|
            hash[e.name] = extract_xml(e)
          end
          hash
        else
          element.text
        end
      end

      def build_url(base, parameters=nil)
        url = (test? ? self.test_url : self.live_url).dup
        url << base
        if parameters
          url << '?'
          url << encode(parameters)
        end
        url
      end

      def encode(hash)
        hash.collect{|(k,v)| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
      end
    end
  end
end

