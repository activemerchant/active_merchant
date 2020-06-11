require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantPartnersGateway < Gateway
      self.display_name = 'Merchant Partners'
      self.homepage_url = 'http://www.merchantpartners.com/'

      self.live_url = 'https://trans.merchantpartners.com/cgi-bin/ProcessXML.cgi'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb]

      def initialize(options={})
        requires!(options, :account_id, :merchant_pin)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(payment_method.is_a?(String) ? :stored_purchase : :purchase, post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(:authorize, post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit(:capture, post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)

        commit(:void, post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit(:refund, post)
      end

      def credit(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)

        commit(payment_method.is_a?(String) ? :stored_credit : :credit, post)
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

        post[:profileactiontype] = options[:profileactiontype] || STORE_TX_TYPES[:store_only]

        commit(:store, post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<ccnum>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<cvv2>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<merchantpin>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      def test?
        @options[:account_id].eql?('TEST0')
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:merchantordernumber] = options[:order_id]
        post[:currency] = options[:currency] || currency(money)
      end

      def add_payment_method(post, payment_method)
        if payment_method.is_a?(String)
          user_profile_id, last_4 = split_authorization(payment_method)
          post[:userprofileid] = user_profile_id
          post[:last4digits] = last_4
        else
          post[:ccname] = payment_method.name
          post[:ccnum] = payment_method.number
          post[:cvv2] = payment_method.verification_value
          post[:expmon] = format(payment_method.month, :two_digits)
          post[:expyear] = format(payment_method.year, :four_digits)
          post[:swipedata] = payment_method.track_data if payment_method.track_data
        end
      end

      def add_customer_data(post, options)
        post[:email] = options[:email] if options[:email]
        post[:ipaddress] = options[:ip] if options[:ip]
        if (billing_address = options[:billing_address])
          post[:billaddr1] = billing_address[:address1]
          post[:billaddr2] = billing_address[:address2]
          post[:billcity] = billing_address[:city]
          post[:billstate] = billing_address[:state]
          post[:billcountry] = billing_address[:country]
          post[:bilzip] = billing_address[:zip]
          post[:phone] = billing_address[:phone]
        end
      end

      def add_reference(post, authorization)
        post[:historykeyid] = authorization
      end

      ACTIONS = {
        purchase: '2',
        authorize: '1',
        capture: '3',
        void: '5',
        refund: '4',
        credit: '6',
        store: '7',
        stored_purchase: '8',
        stored_credit: '13'
      }

      STORE_TX_TYPES = {
        store_only: '3'
      }

      def commit(action, post)
        post[:acctid] = @options[:account_id]
        post[:merchantpin] = @options[:merchant_pin]
        post[:service] = ACTIONS[action] if ACTIONS[action]

        data = build_request(post)
        response_data = parse(ssl_post(live_url, data, headers))
        succeeded = success_from(response_data)

        Response.new(
          succeeded,
          message_from(succeeded, response_data),
          response_data,
          authorization: authorization_from(post, response_data),
          avs_result: AVSResult.new(code: response_data['avs_response']),
          cvv_result: CVVResult.new(response_data['cvv2_response']),
          test: test?
        )
      end

      def headers
        {
          'Content-Type' => 'application/xml'
        }
      end

      def build_request(post)
        Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
          xml.interface_driver {
            xml.trans_catalog {
              xml.transaction(name: 'creditcard') {
                xml.inputs {
                  post.each do |field, value|
                    xml.send(field, value)
                  end
                }
              }
            }
          }
        end.to_xml
      end

      def parse(body)
        response = {}
        Nokogiri::XML(CGI.unescapeHTML(body)).xpath('//trans_catalog/transaction/outputs').children.each do |node|
          parse_element(response, node)
        end
        response
      end

      def parse_element(response, node)
        if node.elements.size == 0
          response[node.name.downcase.underscore.to_sym] = node.text
        else
          node.elements.each { |element| parse_element(response, element) }
        end
      end

      def success_from(response)
        response[:status] == 'Approved'
      end

      def message_from(succeeded, response)
        succeeded ? 'Succeeded' : error_message_from(response)
      end

      def authorization_from(request, response)
        request[:service] == ACTIONS[:store] ?
          "#{response[:userprofileid]}|#{response[:last4digits]}" :
          response[:historyid]
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def error_message_from(response)
        if response[:status] == 'Declined'
          match = response[:result].match(/DECLINED:\d{10}:(.+):/)
          match[1] if match
        end
      end
    end
  end
end
