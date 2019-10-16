module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IxopayGateway < Gateway
      self.test_url = 'https://secure.ixopay.com/transaction'
      self.live_url = 'https://secure.ixopay.com/transaction'

      self.supported_countries = %w(AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW)
      self.default_currency = 'EUR'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.ixopay.com'
      self.display_name = 'Ixopay'

      def initialize(options={})
        requires!(options, :username, :password, :secret)
        @secret = options[:secret]
        super
      end

      def purchase(money, payment_method, options={})
        commit('purchase', build_purchase_request(money, payment_method, options), options)
      end

      def authorize(money, payment_method, options={})
        # todo
      end

      def capture(money, authorization, options={})
        # todo
      end

      def refund(money, authorization, options={})
        # todo
      end

      def void(authorization, options={})
        # todo
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def headers(xml)
        timestamp = Time.now.httpdate
        signature = generate_signature('POST', xml, timestamp)

        {
          'Authorization' => "Gateway #{options[:api_key]}:#{signature}",
          'Date' => timestamp,
          'Content-Type' => 'text/xml; charset=utf-8'
        }
      end

      def generate_signature(http_method, xml, timestamp)
        content_type = 'text/xml; charset=utf-8'

        message = http_method + "\n" + Digest::MD5.hexdigest(xml) + "\n" + content_type + "\n" \
          + timestamp + "\n\n" + '/transaction'

        digest = OpenSSL::Digest.new('sha512')
        hmac = OpenSSL::HMAC.digest(digest, @secret, message)

        Base64.encode64(hmac).split.join
      end

      def parse(action, xml)
        parse_element({:action => action}, REXML::Document.new(xml))
      end

      # This generic method appears in a number of gateways that parse XML.
      # In the future, we should investigate finding a library method to
      # drop in, or factoring it out to a module or base class.
      def parse_element(raw, node)
        node_name = node.name.underscore

        node.attributes.each do |k, v|
          raw["#{node_name}_#{k.underscore}".to_sym] = v
        end

        if node.has_elements?
          raw[node_name.to_sym] = true unless node.name.blank?
          node.elements.each { |e| parse_element(raw, e) }
        elsif node.children.count > 1
          raw[node_name.to_sym] = node.children.join(' ').strip
        else
          raw[node_name.to_sym] = node.text unless node.text.nil?
        end

        raw
      end

      def build_purchase_request(money, payment_method, options)
        xml = Builder::XmlMarkup.new(indent: 2)

        xml.instruct! :xml, encoding: 'utf-8'

        xml.tag! 'transactionWithCard', 'xmlns' => 'http://secure.ixopay.com/Schema/V2/TransactionWithCard' do
          xml.tag! 'username', @options[:username]
          xml.tag! 'password', Digest::SHA1.hexdigest(@options[:password])
          add_card_data(xml, payment_method)
          add_debit(xml, money, options)
        end

        xml.target!
      end

      def add_card_data(xml, payment_method)
        xml.tag! 'cardData' do
          xml.tag! 'cardHolder', payment_method.name
          xml.tag! 'pan', payment_method.number
          xml.tag! 'cvv', payment_method.verification_value
          xml.tag! 'expirationMonth', format(payment_method.month, :two_digits)
          xml.tag! 'expirationYear', format(payment_method.year, :four_digits)
        end
      end

      def add_debit(xml, money, options)
        currency = options[:currency] || currency(money)
        description = options[:description].blank? ? 'Purchase' : options[:description]

        xml.tag! 'debit' do
          xml.tag! 'transactionId', new_transaction_id
          add_customer_data(xml, options)
          xml.tag! 'amount', money
          xml.tag! 'currency', currency
          xml.tag! 'description', description
          xml.tag! 'callbackUrl', options[:callback_url] || 'http://example.com'
        end
      end

      def add_customer_data(xml, options)
        # Ixopay returns an error if the elements are not added in the order used here.
        xml.tag! 'customer' do
          add_billing_address(xml,  options[:billing_address])  if options[:billing_address]
          add_shipping_address(xml, options[:shipping_address]) if options[:shipping_address]

          if options.dig(:billing_address, :company)
            xml.tag! 'company', options[:billing_address][:company]
          end

          xml.tag! 'email', options[:email]
          xml.tag! 'ipAddress', options[:ip] || '127.0.0.1'
        end
      end

      def add_billing_address(xml, address)
        if address[:name]
          xml.tag! 'firstName', split_names(address[:name])[0]
          xml.tag! 'lastName',  split_names(address[:name])[1]
        end

        xml.tag! 'billingAddress1', address[:address1]
        xml.tag! 'billingAddress2', address[:address2]
        xml.tag! 'billingCity',     address[:city]
        xml.tag! 'billingPostcode', address[:zip]
        xml.tag! 'billingState',    address[:state]
        xml.tag! 'billingCountry',  address[:country]
        xml.tag! 'billingPhone',    address[:phone]
      end

      def add_shipping_address(xml, address)
        if address[:name]
          xml.tag! 'shippingFirstName', split_names(address[:name])[0]
          xml.tag! 'shippingLastName',  split_names(address[:name])[1]
        end

        xml.tag! 'shippingCompany',   address[:company]
        xml.tag! 'shippingAddress1',  address[:address1]
        xml.tag! 'shippingAddress2',  address[:address2]
        xml.tag! 'shippingCity',      address[:city]
        xml.tag! 'shippingPostcode',  address[:zip]
        xml.tag! 'shippingState',     address[:state]
        xml.tag! 'shippingCountry',   address[:country]
        xml.tag! 'shippingPhone',     address[:phone]
      end

      def new_transaction_id
        SecureRandom.uuid
      end

      def commit(action, request, options={})
        url = (test? ? test_url : live_url)

        begin
          raw_response = ssl_post(url, request, headers(request))
        rescue StandardError => error
          return response_from_request_error(action, error)
        end

        response = parse(action, raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def response_from_request_error(action, error)
        puts "*** Error"
        response = parse(action, error.response.body)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response[:success] == 'true'
      end

      def message_from(response)
        response[:message] || response[:return_type]
      end

      def authorization_from(response)
        response[:reference_id] ? response[:reference_id] + '|' + response[:purchase_id] : nil
      end

      def error_code_from(response)
        unless success_from(response)
          response[:code]
        end
      end
    end
  end
end
