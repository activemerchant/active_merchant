module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Latitude19Gateway < Gateway
      self.display_name = "Latitude19 Gateway"
      self.homepage_url = "http://www.l19tech.com"

      self.live_url = self.test_url = "https://gateway.l19tech.com/payments/"

      self.supported_countries = ["US"]
      self.default_currency = "USD"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      def initialize(options={})
        requires!(options, :account_number, :configuration_id, :secret)
        super
      end

      def purchase(amount, payment_method, options={})
        #JSON
        post = {}

        add_unique_id(post)
        add_session_request_data(post, options)
        # add_invoice(post, amount, options)
        # add_payment_method(post, payment_method)
        # add_customer_data(post, options)

        commit("session/", post)

        # #XML
        # request = build_xml_request do |doc|
        #   add_authentication(doc)
        #   doc.sale(transaction_attributes(options)) do
        #     add_auth_purchase_params(doc, money, payment_method, options)
        #   end
        # end

        # commit(:sale, request)
      end

      def authorize(amount, payment_method, options={})
      end

      def capture(amount, authorization, options={})
      end

      def void(authorization, options={})
      end

      def refund(amount, authorization, options={})
      end

      def credit(amount, payment_method, options={})
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment_method, options = {})
        post = {}
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("store", post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        # JSON.
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((\"card\":{\"number\":\")\d+), '\1[FILTERED]').
          gsub(%r((\"cvc\":\")\d+), '\1[FILTERED]')

        # urlencoded.
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((card\[number\]=)\d+), '\1[FILTERED]').
          gsub(%r((card\[cvc\]=)\d+), '\1[FILTERED]')

        # XML.
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<CardNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<CVN>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<Password>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["USD"] = "840"

      def add_session_request_data(post, options)
        add_method(post, "getSession")
        params = {}
        params[:pgwAccountNumber] = @options[:account_number]
        puts "account number = ", params[:pgwAccountNumber]
        params[:pgwConfigurationId] = @options[:configuration_id]
        puts "configuration id = ", params[:pgwConfigurationId]
        params[:requestTimeStamp] = Time.now.getutc.strftime("%Y%m%d%H%M%S")
        puts "timestamp = ", params[:requestTimeStamp]
        puts "local options", options
        puts "global options", @options
        message = params[:pgwAccountNumber] + "|" + params[:pgwConfigurationId] + "|" + params[:requestTimeStamp] + "|" + post[:method]
        params[:pgwHMAC] = OpenSSL::HMAC.hexdigest('sha512', @options[:secret], message)
        post[:params] = [params]
      end

      def add_method(post, method)
        post[:method] = method
      end

      def add_unique_id(post)
        post[:id] = SecureRandom.hex(16)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:orderid] = options[:order_id]
        post[:currency] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def add_payment_method(post, payment_method)
        post[:cardholder] = payment_method.name
        post[:cardtype] = payment_method.brand
        post[:cardnumber] = payment_method.number
        post[:cardcvv] = payment_method.verification_value
        post[:cardexpyear] = format(payment_method.year, :four_digits)
        post[:cardexpmonth] = format(payment_method.month, :two_digits)
        post[:cardtrackdata] = payment_method.track_data
      end

      def add_customer_data(post, options)
        post[:email] = options[:email]
        if (billing_address = options[:billing_address])
          post[:name] = billing_address[:name]
          post[:company] = billing_address[:company]
          post[:address1] = billing_address[:address1]
          post[:address2] = billing_address[:address2]
          post[:city] = billing_address[:city]
          post[:state] = billing_address[:state]
          post[:country] = billing_address[:country]
          post[:zip]    = billing_address[:zip]
          post[:phone] = billing_address[:phone]
        end
      end

      def add_reference(post, authorization)
        transaction_id, transaction_amount = split_authorization(authorization)
        post[:transaction_id] = transaction_id
        post[:transaction_amount] = transaction_amount
      end

      ACTIONS = {
        purchase: "SALE",
        authorize: "AUTH",
        capture: "CAPTURE",
        void: "VOID",
        refund: "REFUND",
        store: "STORE"
      }

      def commit(endpoint, params)
        raw_response = ssl_post(url() + endpoint, post_data(params), headers)
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: response["result"]["sessionId"],
          # avs_result: AVSResult.new(code: response["some_avs_result_key"]),
          # cvv_result: CVVResult.new(response["some_cvv_result_key"]),
          test: test?
        )

      # rescue JSON::ParserError
      #   unparsable_response(raw_response)
      end

      def headers
        {
          # "Authorization" => "Basic " + Base64.encode64("#{@options[:login]}:#{@options[:password]}").strip,
          # "Content-Type"  => "application/x-www-form-urlencoded;charset=UTF-8"
          "Content-Type"  => "application/json"
        }
      end

      def post_data(params)
        # JSON.
        params.to_json

        # urlencoded.
        # params.map {|k, v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')

        # XML.
        # build_xml_request rather than #post_data
      end

      # def build_xml_request
      #   builder = Nokogiri::XML::Builder.new
      #   builder.__send__("SomeRootTagOrSomething") do |doc|
      #     yield(doc)
      #   end
      #   builder.to_xml
      # end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        # JSON.
        JSON.parse(body)

        # urlencoded.
        # Hash[CGI::parse(body).map{|k,v| [k.upcase,v.first]}]

        # XML
        # response = {}

        # doc = Nokogiri::XML(xml)
        # doc.root.xpath("*").each do |node|
        #   if (node.elements.size == 0)
        #     response[node.name.downcase.to_sym] = node.text
        #   else
        #     node.elements.each do |childnode|
        #       name = "#{node.name.downcase}_#{childnode.name.downcase}"
        #       response[name.to_sym] = childnode.text
        #     end
        #   end
        # end unless doc.root.nil?

        # response
      end

      def success_from(response)
        response["result"]["lastActionSucceeded"] == 1
      end

      def message_from(response)
        if response["result"]["lastActionSucceeded"] == 1
          "Succeeded"
        else
          "Action Failed"
        end
      end

      def unparsable_response(raw_response)
        message = "Invalid JSON response received from Latitude19Gateway. Please contact Latitude19Gateway if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end

      # def add_authentication(doc)
      #   doc.authentication do
      #     doc.user(@options[:login])
      #     doc.password(@options[:password])
      #   end
      # end

    end
  end
end
