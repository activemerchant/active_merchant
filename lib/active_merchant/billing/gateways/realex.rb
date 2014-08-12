require 'nokogiri'
require 'digest/sha1'

module ActiveMerchant
  module Billing
    # Realex is the leading CC gateway in Ireland
    # see http://www.realexpayments.com
    # Contributed by John Ward (john@ward.name)
    # see http://thinedgeofthewedge.blogspot.com
    #
    # Realex works using the following
    # login - The unique id of the merchant
    # password - The secret is used to digitally sign the request
    # account - This is an optional third part of the authentication process
    # and is used if the merchant wishes do distinguish cc traffic from the different sources
    # by using a different account. This must be created in advance
    #
    # the Realex team decided to make the orderid unique per request,
    # so if validation fails you can not correct and resend using the
    # same order id
    class RealexGateway < Gateway
      self.live_url = self.test_url = 'https://epage.payandshop.com/epage-remote.cgi'

      CARD_MAPPING = {
        'master'            => 'MC',
        'visa'              => 'VISA',
        'american_express'  => 'AMEX',
        'diners_club'       => 'DINERS',
        'switch'            => 'SWITCH',
        'solo'              => 'SWITCH',
        'laser'             => 'LASER',
        'maestro'           => 'MC'
      }

      self.money_format = :cents
      self.default_currency = 'EUR'
      self.supported_cardtypes = [ :visa, :master, :american_express, :diners_club, :switch, :solo, :laser ]
      self.supported_countries = %w(IE GB FR BE NL LU IT)
      self.homepage_url = 'http://www.realexpayments.com/'
      self.display_name = 'Realex'

      SUCCESS, DECLINED          = "Successful", "Declined"
      BANK_ERROR = REALEX_ERROR  = "Gateway is in maintenance. Please try again later."
      ERROR = CLIENT_DEACTIVATED = "Gateway Error"

      def initialize(options = {})
        requires!(options, :login, :password)
        options[:refund_hash] = Digest::SHA1.hexdigest(options[:rebate_secret]) if options.has_key?(:rebate_secret)
        super
      end

      def purchase(money, credit_card, options = {})
        requires!(options, :order_id)

        request = build_purchase_or_authorization_request(:purchase, money, credit_card, options)
        commit(request)
      end

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)

        request = build_purchase_or_authorization_request(:authorization, money, creditcard, options)
        commit(request)
      end

      def capture(money, authorization, options = {})
        request = build_capture_request(authorization, options)
        commit(request)
      end

      def refund(money, authorization, options = {})
        request = build_refund_request(money, authorization, options)
        commit(request)
      end

      def credit(money, authorization, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      def void(authorization, options = {})
        request = build_void_request(authorization, options)
        commit(request)
      end

      private
      def commit(request)
        response = parse(ssl_post(self.live_url, request))

        Response.new(
          (response[:result] == "00"),
          message_from(response),
          response,
          :test => (response[:message] =~ %r{\[ test system \]}),
          :authorization => authorization_from(response),
          :cvv_result => response[:cvnresult],
          :avs_result => {
            :street_match => response[:avspostcoderesponse],
            :postal_match => response[:avspostcoderesponse]
          }
        )
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.xpath('//response/*').each do |node|
          if (node.elements.size == 0)
            response[node.name.downcase.to_sym] = normalize(node.text)
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = normalize(childnode.text)
            end
          end
        end unless doc.root.nil?

        response
      end

      def authorization_from(parsed)
        [parsed[:orderid], parsed[:pasref], parsed[:authcode]].join(';')
      end

      def build_purchase_or_authorization_request(action, money, credit_card, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'auth' do
          add_merchant_details(xml, options)
          xml.tag! 'orderid', sanitize_order_id(options[:order_id])
          add_amount(xml, money, options)
          add_card(xml, credit_card)
          xml.tag! 'autosettle', 'flag' => auto_settle_flag(action)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), amount(money), (options[:currency] || currency(money)), credit_card.number)
          add_comments(xml, options)
          add_address_and_customer_info(xml, options)
        end
        xml.target!
      end

      def build_capture_request(authorization, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'settle' do
          add_merchant_details(xml, options)
          add_transaction_identifiers(xml, authorization, options)
          add_comments(xml, options)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), nil, nil, nil)
        end
        xml.target!
      end

      def build_refund_request(money, authorization, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'rebate' do
          add_merchant_details(xml, options)
          add_transaction_identifiers(xml, authorization, options)
          xml.tag! 'amount', amount(money), 'currency' => options[:currency] || currency(money)
          xml.tag! 'refundhash', @options[:refund_hash] if @options[:refund_hash]
          xml.tag! 'autosettle', 'flag' => 1
          add_comments(xml, options)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), amount(money), (options[:currency] || currency(money)), nil)
        end
        xml.target!
      end

      def build_void_request(authorization, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'void' do
          add_merchant_details(xml, options)
          add_transaction_identifiers(xml, authorization, options)
          add_comments(xml, options)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), nil, nil, nil)
        end
        xml.target!
      end

      def add_address_and_customer_info(xml, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address]

        return unless billing_address || shipping_address || options[:customer] || options[:invoice] || options[:ip]

        xml.tag! 'tssinfo' do
          xml.tag! 'custnum', options[:customer] if options[:customer]
          xml.tag! 'prodid', options[:invoice] if options[:invoice]
          xml.tag! 'custipaddress', options[:ip] if options[:ip]

          if billing_address
            xml.tag! 'address', 'type' => 'billing' do
              xml.tag! 'code', format_address_code(billing_address)
              xml.tag! 'country', billing_address[:country]
            end
          end

          if shipping_address
            xml.tag! 'address', 'type' => 'shipping' do
              xml.tag! 'code', format_address_code(shipping_address)
              xml.tag! 'country', shipping_address[:country]
            end
          end
        end
      end

      def add_merchant_details(xml, options)
        xml.tag! 'merchantid', @options[:login]
        if options[:account] || @options[:account]
          xml.tag! 'account', (options[:account] || @options[:account])
        end
      end

      def add_transaction_identifiers(xml, authorization, options)
        options[:order_id], pasref, authcode = authorization.split(';')
        xml.tag! 'orderid', sanitize_order_id(options[:order_id])
        xml.tag! 'pasref', pasref
        xml.tag! 'authcode', authcode
      end

      def add_comments(xml, options)
        return unless options[:description]
        xml.tag! 'comments' do
          xml.tag! 'comment', options[:description], 'id' => 1
        end
      end

      def add_amount(xml, money, options)
        xml.tag! 'amount', amount(money), 'currency' => options[:currency] || currency(money)
      end

      def add_card(xml, credit_card)
        xml.tag! 'card' do
          xml.tag! 'number', credit_card.number
          xml.tag! 'expdate', expiry_date(credit_card)
          xml.tag! 'chname', credit_card.name
          xml.tag! 'type', CARD_MAPPING[card_brand(credit_card).to_s]
          xml.tag! 'issueno', credit_card.issue_number
          xml.tag! 'cvn' do
            xml.tag! 'number', credit_card.verification_value
            xml.tag! 'presind', (options['presind'] || (credit_card.verification_value? ? 1 : nil))
          end
        end
      end

      def format_address_code(address)
        code = [address[:zip].to_s, address[:address1].to_s + address[:address2].to_s]
        code.collect{|e| e.gsub(/\D/, "")}.reject{|e| e.empty?}.join("|")
      end

      def new_timestamp
        Time.now.strftime('%Y%m%d%H%M%S')
      end

      def add_signed_digest(xml, *values)
        string = Digest::SHA1.hexdigest(values.join("."))
        xml.tag! 'sha1hash', Digest::SHA1.hexdigest([string, @options[:password]].join("."))
      end

      def auto_settle_flag(action)
        action == :authorization ? '0' : '1'
      end

      def expiry_date(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end

      def message_from(response)
        message = nil
        case response[:result]
        when "00"
          message = SUCCESS
        when "101"
          message = response[:message]
        when "102", "103"
          message = DECLINED
        when /^2[0-9][0-9]/
          message = BANK_ERROR
        when /^3[0-9][0-9]/
          message = REALEX_ERROR
        when /^5[0-9][0-9]/
          message = response[:message]
        when "600", "601", "603"
          message = ERROR
        when "666"
          message = CLIENT_DEACTIVATED
        else
          message = DECLINED
        end
      end

      def sanitize_order_id(order_id)
        order_id.to_s.gsub(/[^a-zA-Z0-9\-_]/, '')
      end
    end
  end
end
