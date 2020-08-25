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
        'maestro'           => 'MC'
      }

      self.money_format = :cents
      self.default_currency = 'EUR'
      self.supported_cardtypes = %i[visa master american_express diners_club]
      self.supported_countries = %w(IE GB FR BE NL LU IT US CA ES)
      self.homepage_url = 'http://www.realexpayments.com/'
      self.display_name = 'Realex'

      SUCCESS, DECLINED          = 'Successful', 'Declined'
      BANK_ERROR = REALEX_ERROR  = 'Gateway is in maintenance. Please try again later.'
      ERROR = CLIENT_DEACTIVATED = 'Gateway Error'

      def initialize(options = {})
        requires!(options, :login, :password)
        options[:refund_hash] = Digest::SHA1.hexdigest(options[:rebate_secret]) if options[:rebate_secret].present?
        options[:credit_hash] = Digest::SHA1.hexdigest(options[:refund_secret]) if options[:refund_secret].present?
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
        request = build_capture_request(money, authorization, options)
        commit(request)
      end

      def refund(money, authorization, options = {})
        request = build_refund_request(money, authorization, options)
        commit(request)
      end

      def credit(money, creditcard, options = {})
        request = build_credit_request(money, creditcard, options)
        commit(request)
      end

      def void(authorization, options = {})
        request = build_void_request(authorization, options)
        commit(request)
      end

      def verify(credit_card, options = {})
        requires!(options, :order_id)

        request = build_verify_request(credit_card, options)
        commit(request)
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<number>)\d+(</number>))i, '\1[FILTERED]\2')
      end

      private

      def commit(request)
        response = parse(ssl_post(self.live_url, request))

        Response.new(
          (response[:result] == '00'),
          message_from(response),
          response,
          test: (response[:message] =~ %r{\[ test system \]}),
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response[:avspostcoderesponse]),
          cvv_result: CVVResult.new(response[:cvnresult])
        )
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.xpath('//response/*').each do |node|
          if node.elements.size == 0
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
        xml = Builder::XmlMarkup.new indent: 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'auth' do
          add_merchant_details(xml, options)
          xml.tag! 'orderid', sanitize_order_id(options[:order_id])
          add_amount(xml, money, options)
          add_card(xml, credit_card)
          xml.tag! 'autosettle', 'flag' => auto_settle_flag(action)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), amount(money), (options[:currency] || currency(money)), credit_card.number)
          if credit_card.is_a?(NetworkTokenizationCreditCard)
            add_network_tokenization_card(xml, credit_card)
          else
            add_three_d_secure(xml, options)
          end
          add_comments(xml, options)
          add_address_and_customer_info(xml, options)
        end
        xml.target!
      end

      def build_capture_request(money, authorization, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new indent: 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'settle' do
          add_merchant_details(xml, options)
          add_amount(xml, money, options)
          add_transaction_identifiers(xml, authorization, options)
          add_comments(xml, options)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), amount(money), (options[:currency] || currency(money)), nil)
        end
        xml.target!
      end

      def build_refund_request(money, authorization, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new indent: 2
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

      def build_credit_request(money, credit_card, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new indent: 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'credit' do
          add_merchant_details(xml, options)
          xml.tag! 'orderid', sanitize_order_id(options[:order_id])
          add_amount(xml, money, options)
          add_card(xml, credit_card)
          xml.tag! 'refundhash', @options[:credit_hash] if @options[:credit_hash]
          xml.tag! 'autosettle', 'flag' => 1
          add_comments(xml, options)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), amount(money), (options[:currency] || currency(money)), credit_card.number)
        end
        xml.target!
      end

      def build_void_request(authorization, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new indent: 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'void' do
          add_merchant_details(xml, options)
          add_transaction_identifiers(xml, authorization, options)
          add_comments(xml, options)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), nil, nil, nil)
        end
        xml.target!
      end

      # Verify initiates an OTB (Open To Buy) request
      def build_verify_request(credit_card, options)
        timestamp = new_timestamp
        xml = Builder::XmlMarkup.new indent: 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'otb' do
          add_merchant_details(xml, options)
          xml.tag! 'orderid', sanitize_order_id(options[:order_id])
          add_card(xml, credit_card)
          add_comments(xml, options)
          add_signed_digest(xml, timestamp, @options[:login], sanitize_order_id(options[:order_id]), credit_card.number)
        end
        xml.target!
      end

      def add_address_and_customer_info(xml, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address]
        ipv4_address = ipv4?(options[:ip]) ? options[:ip] : nil

        return unless billing_address || shipping_address || options[:customer] || options[:invoice] || ipv4_address

        xml.tag! 'tssinfo' do
          xml.tag! 'custnum', options[:customer] if options[:customer]
          xml.tag! 'prodid', options[:invoice] if options[:invoice]
          xml.tag! 'custipaddress', options[:ip] if ipv4_address

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
        xml.tag! 'account', (options[:account] || @options[:account]) if options[:account] || @options[:account]
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
          xml.tag! 'issueno', ''
          xml.tag! 'cvn' do
            xml.tag! 'number', credit_card.verification_value
            xml.tag! 'presind', (options['presind'] || (credit_card.verification_value? ? 1 : nil))
          end
        end
      end

      def add_network_tokenization_card(xml, payment)
        xml.tag! 'mpi' do
          xml.tag! 'cavv', payment.payment_cryptogram
          xml.tag! 'eci', payment.eci
        end
        xml.tag! 'supplementarydata' do
          xml.tag! 'item', 'type' => 'mobile' do
            xml.tag! 'field01', payment.source.to_s.gsub('_', '-')
          end
        end
      end

      def add_three_d_secure(xml, options)
        return unless three_d_secure = options[:three_d_secure]

        version = three_d_secure.fetch(:version, '')
        xml.tag! 'mpi' do
          if /^2/.match?(version)
            xml.tag! 'authentication_value', three_d_secure[:cavv]
            xml.tag! 'ds_trans_id', three_d_secure[:ds_transaction_id]
          else
            xml.tag! 'cavv', three_d_secure[:cavv]
            xml.tag! 'xid', three_d_secure[:xid]
            version = '1'
          end
          xml.tag! 'eci', three_d_secure[:eci]
          xml.tag! 'message_version', version
        end
      end

      def format_address_code(address)
        code = [address[:zip].to_s, address[:address1].to_s + address[:address2].to_s]
        code.collect { |e| e.gsub(/\D/, '') }.reject(&:empty?).join('|')
      end

      def new_timestamp
        Time.now.strftime('%Y%m%d%H%M%S')
      end

      def add_signed_digest(xml, *values)
        string = Digest::SHA1.hexdigest(values.join('.'))
        xml.tag! 'sha1hash', Digest::SHA1.hexdigest([string, @options[:password]].join('.'))
      end

      def auto_settle_flag(action)
        action == :authorization ? '0' : '1'
      end

      def expiry_date(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end

      def message_from(response)
        case response[:result]
        when '00'
          SUCCESS
        when '101'
          response[:message]
        when '102', '103'
          DECLINED
        when /^2[0-9][0-9]/
          BANK_ERROR
        when /^3[0-9][0-9]/
          REALEX_ERROR
        when /^5[0-9][0-9]/
          response[:message]
        when '600', '601', '603'
          ERROR
        when '666'
          CLIENT_DEACTIVATED
        else
          DECLINED
        end
      end

      def sanitize_order_id(order_id)
        order_id.to_s.gsub(/[^a-zA-Z0-9\-_]/, '')
      end

      def ipv4?(ip_address)
        return false if ip_address.nil?

        !ip_address.match(/\A\d+\.\d+\.\d+\.\d+\z/).nil?
      end
    end
  end
end
