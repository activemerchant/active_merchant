require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      self.test_url = 'https://ps.gcsip.nl/wdl/wdl'
      self.live_url = 'https://ps.gcsip.com/wdl/wdl'

      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :discover, :solo, :dankort, :maestro, :laser]
      self.default_currency = 'CAD'
      self.homepage_url = 'http://www.globalcollect.com/'
      self.display_name = 'GlobalCollect WebCollect'
      self.money_format = :cents

      PAYMENT_PRODUCTS = {
        'visa'             => 1,
        'american_express' => 2,
        'master'           => 3,
        'maestro'          => 117,
        'solo'             => 118,
        'dankort'          => 123,
        'laser'            => 124,
        'jcb'              => 125,
        'discover'         => 128,
      }

      def initialize(options = {})
        requires!(options, :merchant_id)
        super
      end

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)
        order_id = format_order_id(options[:order_id])
        order_type = options.fetch(:order_type, '1')

        requires!(options, :billing_address)
        requires!(options[:billing_address], :country)
        country = options[:billing_address][:country]
        payment_product = PAYMENT_PRODUCTS.fetch(creditcard.brand || 'visa')

        post = {
          'ORDER' => {
            'ORDERID' => order_id,
            'ORDERTYPE' => order_type,
            'MERCHANTREFERENCE' => order_id,
            'COUNTRYCODE' => country,
            'LANGUAGECODE' => 'en'
          },
          'PAYMENT' => {
            'PAYMENTPRODUCTID' => payment_product,
            'COUNTRYCODE' => country,
            'LANGUAGECODE' => 'en'
          }
        }
        add_amount(post['ORDER'], money, options)
        add_amount(post['PAYMENT'], money, options)
        add_credit_card(post['PAYMENT'], creditcard, options)
        response = commit('INSERT_ORDERWITHPAYMENT', post)
        if successful?(response)
          effort_id = response['ROW']['EFFORTID']
          build_response response, "#{order_id}|#{payment_product}|#{effort_id}"
        else
          build_response response, nil
        end
      end
      def build_response params, authorization=nil
        if successful?(params)
          Response.new true, "Success", params, {:test => test?, :authorization => authorization}
        else
          message = Array.wrap(params['ERROR']).map do |error|
            error['MESSAGE'].strip
          end.join('; ')
          Response.new false, message,  params, {:test => test?}
        end
      end

      def status order_id
        post = { 'ORDER' => { 'ORDERID' => order_id } }
        response = commit('GET_ORDERSTATUS', post)
        build_response response
      end

      def purchase(money, creditcard, options = {})
        MultiResponse.new.tap do |r|
          r.process{authorize(money, creditcard, options)}
          r.process{capture(money, r.authorization, options)}
        end
      end

      def capture(money, authorization, options = {})
        order_id, payment_product, effort_id = authorization.split('|')
        post = {
          'PAYMENT' => {
            'ORDERID' => order_id,
            'PAYMENTPRODUCTID' => payment_product,
            'EFFORTID' => effort_id
          }
        }
        add_amount(post['PAYMENT'], money, options)
        response = commit('SET_PAYMENT', post)
        build_response(response, authorization)
      end

      def void(authorization, options = {})
        order_id, _, effort_id = authorization.split('|')
        post = {
          'PAYMENT' => {
            'ORDERID' => order_id,
            'EFFORTID' => effort_id,
            'ATTEMPTID' => 1
          }
        }
        response = commit('CANCEL_PAYMENT', post)
        build_response response, authorization
      end

      def refund(money, authorization, options = {})
        order_id, _, _ = authorization.split('|')
        post = { 'PAYMENT' => { 'ORDERID' => order_id } }
        add_amount(post['PAYMENT'], money, options)
        response = commit('DO_REFUND', post)
        build_response(response, authorization)
      end

      def credit(money, authorization, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      # variable recurring orders

      # create a new order with ORDERTYPE=4
      def multiple_initial_purchase money, creditcard, options={}
        options = options.merge({:order_type => 4})
        authorize(money, creditcard, options)
      end

      # Create an additional payment on an existing order
      # Only available on variable recurring (ORDERTYPE=4) orders
      def multiple_append_purchase money, options={}
        requires!(options, :order_id, :effort_id)
        order_id = format_order_id(options[:order_id])
        effort_id = options[:effort_id]
        post = { 'PAYMENT' => { 'ORDERID' => order_id, 'EFFORTID' => effort_id } }
        add_amount(post['PAYMENT'], money, options)
        response = commit('DO_PAYMENT', post)
        build_response response, "#{order_id}||#{effort_id}"
      end

      private

      def parse(body)
        xml = Nokogiri::XML(body)
        response = xml.xpath('/XML/REQUEST/RESPONSE')
        return Hash.from_xml(response.to_xml)['RESPONSE']
      end

      def post_data(action, params = {})
        {
          'REQUEST' => {
            'ACTION' => action,
            'META' => {'MERCHANTID' => @options[:merchant_id], 'VERSION' => '2.0'},
            'PARAMS' => params
          }
        }.to_xml(:skip_instruct => true, :skip_types => true, :root => 'XML', :indent => 2)
      end

      def commit(action, params)
        xml = post_data(action, params)
        url = test?? test_url : live_url
        headers = { 'Content-Type' => 'text/xml; charset=utf-8' }
        parse(ssl_post(url, xml, headers))
      end

      def add_amount post, money, options
        post['AMOUNT'] = amount(money)
        post['CURRENCYCODE'] = options[:currency] || currency(money)
      end

      def add_credit_card post, creditcard, options={}
        post['CREDITCARDNUMBER'] = creditcard.number
        post['EXPIRYDATE'] = expiry(creditcard)
        post['CVV'] = creditcard.verification_value if creditcard.verification_value?
      end

      def successful? response
        response['RESULT'] == 'OK'
      end

      # only numeric
      def format_order_id order_id
        order_id.to_s.gsub(/[^\d]/, '')[0...10]
      end

      def expiry credit_card
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)
        "#{month}#{year}"
      end
    end
  end
end

