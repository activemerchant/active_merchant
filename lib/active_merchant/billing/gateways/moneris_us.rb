require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # To learn more about the Moneris (US) gateway, please contact
    # ussales@moneris.com for a copy of their integration guide. For
    # information on remote testing, please see "Test Environment Penny Value
    # Response Table", and "Test Environment eFraud (AVS and CVD) Penny
    # Response Values", available at Moneris' {eSelect Plus Documentation
    # Centre}[https://www3.moneris.com/connect/en/documents/index.html].
    class MonerisUsGateway < Gateway
      self.test_url = 'https://esplusqa.moneris.com/gateway_us/servlet/MpgRequest'
      self.live_url = 'https://esplus.moneris.com/gateway_us/servlet/MpgRequest'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover]
      self.homepage_url = 'http://www.monerisusa.com/'
      self.display_name = 'Moneris (US)'

      # Initialize the Gateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- Your Store ID
      # * <tt>:password</tt> -- Your API Token
      # * <tt>:cvv_enabled</tt> -- Specify that you would like the CVV passed to the gateway.
      #                            Only particular account types at Moneris will allow this.
      #                            Defaults to false.  (optional)
      def initialize(options = {})
        requires!(options, :login, :password)
        @cvv_enabled = options[:cvv_enabled]
        @avs_enabled = options[:avs_enabled]
        options = { :crypt_type => 7 }.merge(options)
        super
      end

      def verify(creditcard_or_datakey, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, creditcard_or_datakey, options) }
          r.process(:ignore_result) { capture(0, r.authorization) }
        end
      end

      # Referred to as "PreAuth" in the Moneris integration guide, this action
      # verifies and locks funds on a customer's card, which then must be
      # captured at a later date.
      #
      # Pass in +order_id+ and optionally a +customer+ parameter.
      def authorize(money, creditcard_or_datakey, options = {})
        requires!(options, :order_id)
        post = {}
        add_payment_source(post, creditcard_or_datakey, options)
        post[:amount]     = amount(money)
        post[:order_id]   = options[:order_id]
        post[:address]    = options[:billing_address] || options[:address]
        post[:crypt_type] = options[:crypt_type] || @options[:crypt_type]
        action = post[:data_key].blank? ? 'us_preauth' : 'us_res_preauth_cc'
        commit(action, post)
      end

      # This action verifies funding on a customer's card and readies them for
      # deposit in a merchant's account.
      #
      # Pass in <tt>order_id</tt> and optionally a <tt>customer</tt> parameter
      def purchase(money, creditcard_or_datakey, options = {})
        requires!(options, :order_id)
        post = {}
        add_payment_source(post, creditcard_or_datakey, options)
        post[:amount]     = amount(money)
        post[:order_id]   = options[:order_id]
        add_address(post, creditcard_or_datakey, options)
        post[:crypt_type] = options[:crypt_type] || @options[:crypt_type]
        action = if creditcard_or_datakey.is_a?(String)
          'us_res_purchase_cc'
        elsif card_brand(creditcard_or_datakey) == 'check'
          'us_ach_debit'
        elsif post[:data_key].blank?
          'us_purchase'
        end
        commit(action, post)
      end

      # This method retrieves locked funds from a customer's account (from a
      # PreAuth) and prepares them for deposit in a merchant's account.
      #
      # Note: Moneris requires both the order_id and the transaction number of
      # the original authorization.  To maintain the same interface as the other
      # gateways the two numbers are concatenated together with a ; separator as
      # the authorization number returned by authorization
      def capture(money, authorization, options = {})
        commit 'us_completion', crediting_params(authorization, :comp_amount => amount(money))
      end

      # Voiding requires the original transaction ID and order ID of some open
      # transaction. Closed transactions must be refunded. Note that the only
      # methods which may be voided are +capture+ and +purchase+.
      #
      # Concatenate your transaction number and order_id by using a semicolon
      # (';'). This is to keep the Moneris interface consistent with other
      # gateways. (See +capture+ for details.)
      def void(authorization, options = {})
        commit 'us_purchasecorrection', crediting_params(authorization)
      end

      # Performs a refund. This method requires that the original transaction
      # number and order number be included. Concatenate your transaction
      # number and order_id by using a semicolon (';'). This is to keep the
      # Moneris interface consistent with other gateways. (See +capture+ for
      # details.)
      def credit(money, authorization, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      def refund(money, authorization, options = {})
        commit 'us_refund', crediting_params(authorization, :amount => amount(money))
      end

      def store(payment_source, options = {})
        post = {}
        add_payment_source(post, payment_source, options)
        post[:crypt_type] = options[:crypt_type] || @options[:crypt_type]
        card_brand(payment_source) == 'check' ? commit('us_res_add_ach', post) : commit('us_res_add_cc', post)
      end

      def unstore(data_key, options = {})
        post = {}
        post[:data_key] = data_key
        commit('us_res_delete', post)
      end

      def update(data_key, payment_source, options = {})
        post = {}
        add_payment_source(post, payment_source, options)
        post[:data_key] = data_key
        card_brand(payment_source) == 'check' ? commit('us_res_update_ach', post) : commit('us_res_update_cc', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<pan>)[^<]*(</pan>))i, '\1[FILTERED]\2').
          gsub(%r((<api_token>)[^<]*(</api_token>))i, '\1[FILTERED]\2').
          gsub(%r((<cvd_value>)[^<]*(</cvd_value>))i, '\1[FILTERED]\2')
      end

      private # :nodoc: all

      def expdate(creditcard)
        sprintf('%.4i', creditcard.year)[-2..-1] + sprintf('%.2i', creditcard.month)
      end

      def add_address(post, payment_method, options)
        if !payment_method.is_a?(String) && card_brand(payment_method) == 'check'
          post[:ach_info][:cust_first_name] = payment_method.first_name if payment_method.first_name
          post[:ach_info][:cust_last_name] = payment_method.last_name if payment_method.last_name
          if address = options[:billing_address] || options[:address]
            post[:ach_info][:cust_address1] = address[:address1] if address[:address1]
            post[:ach_info][:cust_address2] = address[:address2] if address[:address2]
            post[:ach_info][:city] = address[:city] if address[:city]
            post[:ach_info][:state] = address[:state] if address[:state]
            post[:ach_info][:zip] = address[:zip] if address[:zip]
          end
        else
          post[:address] = options[:billing_address] || options[:address]
        end
      end

      def add_payment_source(post, source, options)
        if source.is_a?(String)
          post[:data_key]   = source
          post[:cust_id]    = options[:customer]
        elsif card_brand(source) == 'check'
          ach_info = {}
          ach_info[:sec] = 'web'
          ach_info[:routing_num] = source.routing_number
          ach_info[:account_num] = source.account_number
          ach_info[:account_type] = source.account_type
          ach_info[:check_num] = source.number if source.number
          post[:ach_info] = ach_info
        else
          post[:pan]        = source.number
          post[:expdate]    = expdate(source)
          post[:cvd_value]  = source.verification_value if source.verification_value?
          if crypt_type = options[:crypt_type] || @options[:crypt_type]
            post[:crypt_type] = crypt_type
          end
          post[:cust_id]    = options[:customer] || source.name
        end
      end

      # Common params used amongst the +credit+, +void+ and +capture+ methods
      def crediting_params(authorization, options = {})
        {
          :txn_number => split_authorization(authorization).first,
          :order_id   => split_authorization(authorization).last,
          :crypt_type => options[:crypt_type] || @options[:crypt_type]
        }.merge(options)
      end

      # Splits an +authorization+ param and retrieves the order id and
      # transaction number in that order.
      def split_authorization(authorization)
        if authorization.nil? || authorization.empty? || authorization !~ /;/
          raise ArgumentError, 'You must include a valid authorization code (e.g. "1234;567")'
        else
          authorization.split(';')
        end
      end

      def commit(action, parameters = {})
        data = post_data(action, parameters)
        url = test? ? self.test_url : self.live_url
        raw = ssl_post(url, data)
        response = parse(raw)

        Response.new(successful?(response), message_from(response[:message]), response,
          :test          => test?,
          :avs_result    => { :code => response[:avs_result_code] },
          :cvv_result    => response[:cvd_result_code] && response[:cvd_result_code][-1,1],
          :authorization => authorization_from(response)
        )
      end

      # Generates a Moneris authorization string of the form 'trans_id;receipt_id'.
      def authorization_from(response = {})
        if response[:trans_id] && response[:receipt_id]
          "#{response[:trans_id]};#{response[:receipt_id]}"
        end
      end

      # Tests for a successful response from Moneris' servers
      def successful?(response)
        response[:response_code] &&
        response[:complete] &&
        (0..49).cover?(response[:response_code].to_i)
      end

      def parse(xml)
        response = { :message => 'Global Error Receipt', :complete => false }
        hashify_xml!(xml, response)
        response
      end

      def hashify_xml!(xml, response)
        xml = REXML::Document.new(xml)
        return if xml.root.nil?
        xml.elements.each('//receipt/*') do |node|
          response[node.name.underscore.to_sym] = normalize(node.text)
        end
      end

      def post_data(action, parameters = {})
        xml   = REXML::Document.new
        root  = xml.add_element('request')
        root.add_element('store_id').text  = options[:login]
        root.add_element('api_token').text = options[:password]
        root.add_element(transaction_element(action, parameters))

        xml.to_s
      end

      def transaction_element(action, parameters)
        transaction = REXML::Element.new(action)

        # Must add the elements in the correct order
        actions[action].each do |key|
          case key
          when :avs_info
            transaction.add_element(avs_element(parameters[:address])) if @avs_enabled && parameters[:address]
          when :cvd_info
            transaction.add_element(cvd_element(parameters[:cvd_value])) if @cvv_enabled
          when :ach_info
            transaction.add_element(ach_element(parameters[:ach_info]))
          else
            transaction.add_element(key.to_s).text = parameters[key] unless parameters[key].blank?
          end
        end

        transaction
      end

      def avs_element(address)
        full_address = "#{address[:address1]} #{address[:address2]}"
        tokens = full_address.split(/\s+/)

        element = REXML::Element.new('avs_info')
        element.add_element('avs_street_number').text = tokens.select{|x| x =~ /\d/}.join(' ')
        element.add_element('avs_street_name').text = tokens.reject{|x| x =~ /\d/}.join(' ')
        element.add_element('avs_zipcode').text = address[:zip]
        element
      end

      def cvd_element(cvd_value)
        element = REXML::Element.new('cvd_info')
        if cvd_value
          element.add_element('cvd_indicator').text = '1'
          element.add_element('cvd_value').text = cvd_value
        else
          element.add_element('cvd_indicator').text = '0'
        end
        element
      end

      def ach_element(ach_info)
        element = REXML::Element.new('ach_info')
        actions['ach_info'].each do |key|
          element.add_element(key.to_s).text = ach_info[key] unless ach_info[key].blank?
        end
        element
      end

      def message_from(message)
        return 'Unspecified error' if message.blank?
        message.gsub(/[^\w]/, ' ').split.join(' ').capitalize
      end

      def actions
        {
          'us_purchase'           => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type, :avs_info, :cvd_info],
          'us_preauth'            => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type, :avs_info, :cvd_info],
          'us_command'            => [:order_id],
          'us_refund'             => [:order_id, :amount, :txn_number, :crypt_type],
          'us_indrefund'          => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
          'us_completion'         => [:order_id, :comp_amount, :txn_number, :crypt_type],
          'us_purchasecorrection' => [:order_id, :txn_number, :crypt_type],
          'us_cavvpurcha'         => [:order_id, :cust_id, :amount, :pan, :expdate, :cav],
          'us_cavvpreaut'         => [:order_id, :cust_id, :amount, :pan, :expdate, :cavv],
          'us_transact'           => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
          'us_Batchcloseall'      => [],
          'us_opentotals'         => [:ecr_number],
          'us_batchclose'         => [:ecr_number],
          'us_res_add_cc'         => [:pan, :expdate, :crypt_type],
          'us_res_delete'         => [:data_key],
          'us_res_update_cc'      => [:data_key, :pan, :expdate, :crypt_type],
          'us_res_purchase_cc'    => [:data_key, :order_id, :cust_id, :amount, :crypt_type],
          'us_res_preauth_cc'     => [:data_key, :order_id, :cust_id, :amount, :crypt_type],
          'us_ach_debit'          => [:order_id, :cust_id, :amount, :ach_info],
          'us_res_add_ach'        => [:order_id, :cust_id, :amount, :ach_info],
          'us_res_update_ach'     => [:order_id, :data_key, :cust_id, :amount, :ach_info],
          'ach_info'              => [:sec, :cust_first_name, :cust_last_name, :cust_address1, :cust_address2, :cust_city, :cust_state, :cust_zip, :routing_num, :account_num, :check_num, :account_type]
        }
      end
    end
  end
end
