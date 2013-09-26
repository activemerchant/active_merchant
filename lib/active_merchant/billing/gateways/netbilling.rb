module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetbillingGateway < Gateway
      self.live_url = self.test_url = 'https://secure.netbilling.com:1402/gw/sas/direct3.1'

      TRANSACTIONS = {
        :authorization => 'A',
        :purchase      => 'S',
        :refund        => 'R',
        :credit        => 'C',
        :capture       => 'D',
        :void          => 'U'
      }

      SUCCESS_CODES = [ '1', 'T' ]
      SUCCESS_MESSAGE = 'The transaction was approved'
      FAILURE_MESSAGE = 'The transaction failed'
      TEST_LOGIN = '104901072025'

      self.display_name = 'NETbilling'
      self.homepage_url = 'http://www.netbilling.com'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def authorize(money, credit_card, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)
        add_address(post, credit_card, options)
        add_customer_data(post, options)

        commit(:authorization, post)
      end

      def purchase(money, credit_card, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)
        add_address(post, credit_card, options)
        add_customer_data(post, options)

        commit(:purchase, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_reference(post, authorization)
        commit(:capture, post)
      end

      def refund(money, source, options = {})
        post = {}
        add_amount(post, money)
        add_reference(post, source)
        commit(:refund, post)
      end

      def credit(money, credit_card, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)
        add_address(post, credit_card, options)
        add_customer_data(post, options)

        commit(:credit, post)
      end

      def void(source, options = {})
        post = {}
        add_reference(post, source)
        commit(:void, post)
      end

      def test?
        (@options[:login] == TEST_LOGIN || super)
      end

      private

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_reference(post, reference)
        post[:orig_id] = reference
      end

      def add_customer_data(post, options)
        post[:cust_email] = options[:email]
        post[:cust_ip] = options[:ip]
      end

      def add_address(post, credit_card, options)
        if billing_address = options[:billing_address] || options[:address]
          post[:bill_street]     = billing_address[:address1]
          post[:cust_phone]      = billing_address[:phone]
          post[:bill_zip]        = billing_address[:zip]
          post[:bill_city]       = billing_address[:city]
          post[:bill_country]    = billing_address[:country]
          post[:bill_state]      = billing_address[:state]
        end

       if shipping_address = options[:shipping_address]
         first_name, last_name = parse_first_and_last_name(shipping_address[:name])

         post[:ship_name1]      = first_name
         post[:ship_name2]      = last_name
         post[:ship_street]     = shipping_address[:address1]
         post[:ship_zip]        = shipping_address[:zip]
         post[:ship_city]       = shipping_address[:city]
         post[:ship_country]    = shipping_address[:country]
         post[:ship_state]      = shipping_address[:state]
       end
      end

      def add_invoice(post, options)
        post[:description] = options[:description]
      end

      def add_credit_card(post, credit_card)
        post[:bill_name1] = credit_card.first_name
        post[:bill_name2] = credit_card.last_name
        post[:card_number] = credit_card.number
        post[:card_expire] = expdate(credit_card)
        post[:card_cvv2] = credit_card.verification_value
      end

      def parse(body)
        results = {}
        body.split(/&/).each do |pair|
          key,val = pair.split(/\=/)
          results[key.to_sym] = CGI.unescape(val)
        end
        results
      end

      def commit(action, parameters)
        response = parse(ssl_post(self.live_url, post_data(action, parameters)))

        Response.new(success?(response), message_from(response), response,
          :test => test_response?(response),
          :authorization => response[:trans_id],
          :avs_result => { :code => response[:avs_code]},
          :cvv_result => response[:cvv2_code]
        )
      rescue ActiveMerchant::ResponseError => e
        raise unless(e.response.code =~ /^[67]\d\d$/)
        return Response.new(false, e.response.message, {:status_code => e.response.code}, :test => test?)
      end

      def test_response?(response)
        !!(test? || response[:auth_msg] =~ /TEST/)
      end

      def success?(response)
        SUCCESS_CODES.include?(response[:status_code])
      end

      def message_from(response)
        success?(response) ? SUCCESS_MESSAGE : (response[:auth_msg] || FAILURE_MESSAGE)
      end

      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end

      def post_data(action, parameters = {})
        parameters[:account_id] = @options[:login]
        parameters[:site_tag] = @options[:site_tag] if @options[:site_tag].present?
        parameters[:pay_type] = 'C'
        parameters[:tran_type] = TRANSACTIONS[action]

        parameters.reject{|k,v| v.blank?}.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def parse_first_and_last_name(value)
        name = value.to_s.split(' ')

        last_name = name.pop || ''
        first_name = name.join(' ')
        [ first_name, last_name ]
      end
    end
  end
end

