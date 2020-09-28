module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SallieMaeGateway < Gateway
      self.live_url = self.test_url = 'https://trans.salliemae.com/cgi-bin/process.cgi'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.salliemae.com/'

      # The name of the gateway
      self.display_name = 'Sallie Mae'

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def test?
        @options[:login] == "TEST0"
      end

      def authorize(money, creditcard, options = {})
        post = PostData.new
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit(:authonly, money, post)
      end

      def purchase(money, creditcard, options = {})
        post = PostData.new
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit(:sale, money, post)
      end

      def capture(money, authorization, options = {})
        post = PostData.new
        post[:postonly] = authorization
        commit(:capture, money, post)
      end

      private

      def add_customer_data(post, options)
        if address = options[:billing_address] || options[:shipping_address] || options[:address]
          post[:ci_phone] = address[:phone].to_s
        end

        post[:ci_email] = options[:email].to_s unless options[:email].blank?
        post[:ci_IP]    = options[:ip].to_s unless options[:ip].blank?
      end

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:ci_billaddr1] = address[:address1].to_s
          post[:ci_billaddr2] = address[:address2].to_s unless address[:address2].blank?
          post[:ci_billcity]  = address[:city].to_s
          post[:ci_billstate] = address[:state].to_s
          post[:ci_billzip]   = address[:zip].to_s
        end

        if shipping_address = options[:shipping_address] || options[:address]
          post[:ci_shipaddr1] = shipping_address[:address1].to_s
          post[:ci_shipaddr2] = shipping_address[:address2].to_s unless shipping_address[:address2].blank?
          post[:ci_shipcity]  = shipping_address[:city].to_s
          post[:ci_shipstate] = shipping_address[:state].to_s
          post[:ci_shipzip]   = shipping_address[:zip].to_s
        end
      end

      def add_invoice(post, options)
        memo = "OrderID: #{options[:order_id]}\nDescription: #{options[:description]}"
        post[:ci_memo] = memo
      end

      def add_creditcard(post, creditcard)
        post[:ccnum]   = creditcard.number.to_s
        post[:ccname]  = creditcard.name.to_s
        post[:cvv2]    = creditcard.verification_value.to_s if creditcard.verification_value?
        post[:expmon]  = creditcard.month.to_s
        post[:expyear] = creditcard.year.to_s
      end

      def parse(body)
        h = {}
        body.gsub!("<html><body><plaintext>", "")
        body.
          split("\r\n").
          map do |i|
            a = i.split("=")
            h[a.first] = a.last unless a.first.nil?
          end
        h
      end

      def commit(action, money, parameters)
        parameters[:acctid] = @options[:login].to_s
        parameters[:subid]  = @options[:sub_id].to_s unless @options[:sub_id].blank?
        parameters[:amount] = amount(money)

        case action
        when :sale
          parameters[:action] = "ns_quicksale_cc"
        when :authonly
          parameters[:action] = "ns_quicksale_cc"
          parameters[:authonly] = 1
        when :capture
          parameters[:action] = "ns_quicksale_cc"
        end

        response = parse(ssl_post(self.live_url, parameters.to_post_data) || "")
        Response.new(successful?(response), message_from(response), response,
          :test => test?,
          :authorization => response["refcode"]
        )
      end

      def successful?(response)
        response["Status"] == "Accepted"
      end

      def message_from(response)
        if successful?(response)
          "Accepted"
        else
          response["Reason"].split(":")[2].capitalize unless response["Reason"].nil?
        end
      end
    end
  end
end

