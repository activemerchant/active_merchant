require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information visit {Bank Frick Acquiring Services}[http://www.bankfrickacquiring.com/merchantsolutions_en.html]
    #
    # Written by Piers Chambers (Varyonic.com)
    class BankFrickGateway < Gateway
      self.test_url = 'https://test.ctpe.io/payment/ctpe'
      self.live_url = 'https://ctpe.io/payment/ctpe'

      self.supported_countries = ['LI','US']
      self.default_currency = 'EUR'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.bankfrickacquiring.com/'
      self.display_name = 'Bank Frick'

      # The set of supported transactions for this gateway.
      # More operations are supported by the gateway itself, but
      # are not supported in this library.
      SUPPORTED_TRANSACTIONS = {
        'sale'      => 'CC.DB',
        'authonly'  => 'CC.PA',
        'capture'   => 'CC.CP',
        'refund'    => 'CC.RF',
        'void'      => 'CC.RV',
      }

      def initialize(options={})
        requires!(options, :sender, :channel, :userid, :userpwd)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        post = {}
        post[:authorization] = authorization
        add_invoice(post, money, options)

        commit('capture', post)
      end

      def refund(money, authorization, options={})
        post = {}
        post[:authorization] = authorization
        add_invoice(post, money, options)

        commit('refund', post)
      end

      def void(authorization, options={})
        post = {}
        post[:authorization] = authorization

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
        post[:email] = options[:email] || 'noone@example.com'
        post[:ip] = options[:ip] || '0.0.0.0'
      end

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:address] = address[:address1].to_s
          post[:company] = address[:company].to_s
          post[:phone]   = address[:phone].to_s.gsub(/[^0-9]/, '') || "0000000"
          post[:zip]     = address[:zip].to_s
          post[:city]    = address[:city].to_s
          post[:country] = address[:country].to_s
          post[:state]   = address[:state].blank?  ? 'n/a' : address[:state]
        end
      end

      def add_invoice(post, money, options)
        post[:order_id]    = options[:order_id] if post.has_key? :order_id
        post[:amount]      = amount(money)
        post[:currency]    = (options[:currency] || currency(money))
        post[:description] = options[:description]
      end

      def add_payment(post, payment)
        post[:first_name] = payment.first_name
        post[:last_name]  = payment.last_name
        post[:brand]      = payment.brand
        post[:card_num]   = payment.number
        post[:card_code]  = payment.verification_value if payment.verification_value?
        post[:exp_year]   = payment.year
        post[:exp_month]  = payment.month
      end

      def parse(body)
        results  = {}
        xml = Nokogiri::XML(body)
        resp = xml.xpath("//Response/Transaction/Identification")
        resp.children.each do |element|
          results[element.name.downcase.to_sym] = element.text
        end
        resp = xml.xpath("//Response/Transaction/Processing")
        resp.children.each do |element|
          results[element.name.downcase.to_sym] = element.text
        end
        results
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        headers = {
          'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8'
        }
        response = parse(ssl_post(url, post_data(action, parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        response[:result] == 'ACK'
      end

      def message_from(response)
        response[:return]
      end

      def authorization_from(response)
        response[:uniqueid]
      end

      def post_data(action, parameters = {})
        xml = build_xml_request(action, parameters)
        "load=#{CGI.escape(xml)}"
      end

      def build_xml_request(action, data)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.Request(version: '1.0') do
          xml.Header do
            xml.Security(sender: @options[:sender], type: 'MERCHANT')
          end
          xml.Transaction(response: 'SYNC', channel: @options[:channel], mode: 'LIVE') do
            xml.User(pwd: @options[:userpwd], login: @options[:userid])
            xml.Identification do
              xml.TransactionID data[:order_id] if data.has_key? :order_id
              xml.ReferenceID   data[:authorization] if data.has_key? :authorization
            end
            xml.Account do
              xml.Holder        "#{data[:first_name]} #{data[:last_name]}"
              xml.Brand         data[:brand]
              xml.Number        data[:card_num]
              xml.Bank          data[:bankname]
              xml.Country       data[:country]
              xml.Authorization data[:authorization]
              xml.Verification  data[:card_code]
              xml.Year          data[:exp_year]
              xml.Month         data[:exp_month]
            end if data.has_key? :card_num
            xml.Payment(code: SUPPORTED_TRANSACTIONS[action]) do
              xml.Presentation do
                xml.Amount     data[:amount]
                xml.Currency   data[:currency]
                xml.Usage      data[:description]
              end
            end
            xml.Customer do
              xml.Contact do
                xml.Email      data[:email]
                xml.Mobile     data[:mobile]
                xml.Ip         data[:ip]
                xml.Phone      data[:phone]
              end
              xml.Address do
                xml.Street     data[:address]
                xml.Zip        data[:zip]
                xml.City       data[:city]
                xml.State      data[:state]
                xml.Country    data[:country]
              end
              xml.Name do
                xml.Salutation data[:salutation]
                xml.Title      data[:title]
                xml.Given      data[:first_name]
                xml.Family     data[:last_name]
                xml.Company    data[:company]
              end
            end if data.has_key? :last_name
          end
        end
      end
    end
  end
end
