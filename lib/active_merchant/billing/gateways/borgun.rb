require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BorgunGateway < Gateway
      self.display_name = "Borgun"

      self.test_url = 'https://gatewaytest.borgun.is/ws/Heimir.pub.ws:Authorization'
      self.live_url = 'https://gateway01.borgun.is/ws/Heimir.pub.ws:Authorization'
      self.ssl_version = :SSLv3

      self.supported_countries = ['IS']
      self.default_currency = 'ISK'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover, :jcb]

      self.homepage_url = 'https://www.borgun.is/'

      def initialize(options={})
        requires!(options, :processor, :merchant_id, :username, :password)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        post[:TransType] = '1'
        add_invoice(post, money, options)
        add_payment_method(post, payment)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        post[:TransType] = '5'
        add_invoice(post, money, options)
        add_payment_method(post, payment)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        post = {}
        post[:TransType] = '1'
        add_invoice(post, money, options)
        add_reference(post, authorization)
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        post = {}
        post[:TransType] = '3'
        add_invoice(post, money, options)
        add_reference(post, authorization)
        commit('refund', post)
      end

      def void(authorization, options={})
        post = {}
        # TransType and TrAmount must match original values from auth or purchase.
        _, _, _, _, _, transtype, tramount = split_authorization(authorization)
        post[:TransType] = transtype
        add_invoice(post, tramount.to_i, options)
        add_reference(post, authorization)
        commit('void', post)
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency for HDFC: #{k}")}
      CURRENCY_CODES["ISK"] = "352"
      CURRENCY_CODES["EUR"] = "978"

      def add_invoice(post, money, options)
        post[:TrAmount] = amount(money)
        post[:TrCurrency] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def add_payment_method(post, payment_method)
        post[:PAN] = payment_method.number
        post[:ExpDate] = format(payment_method.year, :two_digits) + format(payment_method.month, :two_digits)
        post[:CVC2] = payment_method.verification_value
        post[:DateAndTime] = Time.now.strftime("%y%m%d%H%M%S")
        post[:RRN] = 'AMRCNT' + six_random_digits
      end

      def add_reference(post, authorization)
        dateandtime, batch, transaction, rrn, authcode, _, _ = split_authorization(authorization)
        post[:DateAndTime] = dateandtime
        post[:Batch] = batch
        post[:Transaction] = transaction
        post[:RRN] = rrn
        post[:AuthCode] = authcode
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(CGI.unescapeHTML(xml))
        body = doc.xpath('//getAuthorizationReply')
        body = doc.xpath('//cancelAuthorizationReply') if body.length == 0
        body.children.each do |node|
          if node.text?
            next
          elsif (node.elements.size == 0)
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = childnode.text
            end
          end
        end

        response
      end

      def commit(action, post)
        post[:Version] = '1000'
        post[:Processor] = @options[:processor]
        post[:MerchantID] = @options[:merchant_id]
        post[:TerminalID] = 1

        url = (test? ? test_url : live_url)
        request = build_request(action, post)
        raw = ssl_post(url(action), request, headers)
        pairs = parse(raw)
        success = success_from(pairs)

        Response.new(
          success,
          message_from(success, pairs),
          pairs,
          authorization: authorization_from(pairs),
          test: test?
        )
      end

      def success_from(response)
        (response[:actioncode] == '000')
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response[:message] || "Error with ActionCode=#{response[:actioncode]}"
        end
      end

      def authorization_from(response)
        [
          response[:dateandtime],
          response[:batch],
          response[:transaction],
          response[:rrn],
          response[:authcode],
          response[:transtype],
          response[:tramount]
        ].join("|")
      end

      def split_authorization(authorization)
        dateandtime, batch, transaction, rrn, authcode, transtype, tramount = authorization.split("|")
        [dateandtime, batch, transaction, rrn, authcode, transtype, tramount]
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.strict_encode64(@options[:username].to_s + ':' + @options[:password].to_s),
        }
      end

      def build_request(action, post)
        mode = (action == 'void') ? 'cancel' : 'get'
        xml = Builder::XmlMarkup.new :indent => 18
        xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        xml.tag!("#{mode}Authorization") do
          post.each do |field, value|
            xml.tag!(field, value)
          end
        end
        inner = CGI.escapeHTML(xml.target!)
        envelope(mode).sub(/{{ :body }}/,inner)
      end

      def envelope(mode)
        <<-EOS
          <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:aut="http://Borgun/Heimir/pub/ws/Authorization">
            <soapenv:Header/>
            <soapenv:Body>
              <aut:#{mode}AuthorizationInput>
                <#{mode}AuthReqXml>
                {{ :body }}
                </#{mode}AuthReqXml>
              </aut:#{mode}AuthorizationInput>
            </soapenv:Body>
          </soapenv:Envelope>
        EOS
      end

      def url(action)
        (test? ? test_url : live_url)
      end

      def six_random_digits
        (0...6).map { (48 + rand(10)).chr }.join
      end
    end
  end
end
