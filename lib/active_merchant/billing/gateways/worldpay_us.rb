require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayUsGateway < Gateway
      self.display_name = "Worldpay US"
      self.homepage_url = "http://www.worldpay.com/us"

      # No sandbox, just use test cards.
      self.live_url = 'https://trans.worldpay.us/cgi-bin/process.cgi'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb]

      def initialize(options={})
        requires!(options, :acctid, :subid, :merchantpin)
        super
      end

      def purchase(money, payment_method, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit('purchase', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_credit_card(post, payment)
        add_customer_data(post, options)

        commit('authorize', post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit('capture', post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit("refund", post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)

        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def add_customer_data(post, options)
        if(billing_address = (options[:billing_address] || options[:address]))
          post[:ci_companyname] = billing_address[:company]
          post[:ci_billaddr1]   = billing_address[:address1]
          post[:ci_billaddr2]   = billing_address[:address2]
          post[:ci_billcity]    = billing_address[:city]
          post[:ci_billstate]   = billing_address[:state]
          post[:ci_billzip]     = billing_address[:zip]
          post[:ci_billcountry] = billing_address[:country]

          post[:ci_phone]       = billing_address[:phone]
          post[:ci_email]       = billing_address[:email]
          post[:ci_ipaddress]   = billing_address[:ip]
        end

        if(shipping_address = options[:shipping_address])
          post[:ci_shipaddr1] = shipping_address[:address1]
          post[:ci_shipaddr2] = shipping_address[:address2]
          post[:ci_shipcity] = shipping_address[:city]
          post[:ci_shipstate] = shipping_address[:state]
          post[:ci_shipzip]    = shipping_address[:zip]
          post[:ci_shipcountry]    = shipping_address[:country]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currencycode] = (options[:currency] || currency(money))
        post[:merchantordernumber] = options[:order_id] if options[:order_id]
      end

      def add_payment_method(post, payment_method)
        if card_brand(payment_method) == 'check'
          add_check(post, payment_method)
        else
          add_credit_card(post, payment_method)
        end
      end

      def add_credit_card(post, payment_method)
        post[:ccname] = payment_method.name
        post[:ccnum] = payment_method.number
        post[:cvv2] = payment_method.verification_value
        post[:expyear] = format(payment_method.year, :four_digits)
        post[:expmon] = format(payment_method.month, :two_digits)
      end

      ACCOUNT_TYPES = {
        "checking" => "1",
        "savings" => "2",
      }

      def add_check(post, payment_method)
        post[:action] = 'ns_quicksale_check'
        post[:ckacct] = payment_method.account_number
        post[:ckaba] = payment_method.routing_number
        post[:ckno] = payment_method.number
        post[:ckaccttype] = ACCOUNT_TYPES[payment_method.account_type] if ACCOUNT_TYPES[payment_method.account_type]
      end

      def split_authorization(authorization)
        historyid, orderid = authorization.split("|")
        [historyid, orderid]
      end

      def add_reference(post, authorization)
        historyid, orderid = split_authorization(authorization)
        post[:postonly] = historyid
        post[:historykeyid] = historyid
        post[:orderkeyid] = orderid
      end

      def parse(xml)
        response = {}
        doc = Nokogiri::XML(xml)
        message = doc.xpath("//plaintext")
        message.text.split(/\r?\n/).each do |line|
          key, value = line.split(%r{=})
          response[key] = value if key
        end
        response
      end

      ACTIONS = {
        "purchase" => "ns_quicksale_cc",
        "refund" => "ns_credit",
        "authorize" => "ns_quicksale_cc",
        "capture" => "ns_quicksale_cc",
        "void" => "ns_void",
      }

      def commit(action, post)
        post[:action] = ACTIONS[action] unless post[:action]
        post[:acctid] = @options[:acctid]
        post[:subid] = @options[:subid]
        post[:merchantpin] = @options[:merchantpin]

        post[:authonly] = '1' if action == 'authorize'

        raw = parse(ssl_post(live_url, post.to_query))

        succeeded = success_from(raw['result'])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => authorization_from(raw),
          :test => test?
        )
      end

      def success_from(result)
        result == '1'
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          (response['transresult'] || response['Reason'] || "Unable to read error message")
        end
      end

      def authorization_from(response)
        [response['historyid'], response['orderid']].join("|")
      end
    end
  end
end
