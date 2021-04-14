require 'base64'
require 'openssl'
require 'zlib'
require 'active_merchant/billing/gateways/vanco/vanco_common'

module ActiveMerchant
  module Billing
    class VancoNvpGateway < Gateway
      include Empty
      include VancoCommon

      self.test_url = 'https://uat.vancopayments.com/cgi-bin/wsnvp.vps'
      self.live_url = 'https://myvanco.vancopayments.com/cgi-bin/wsnvp.vps'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://vancopayments.com/'
      self.display_name = 'Vanco Payment Solutions'

      def initialize(options={})
        requires!(options, :user_id, :password, :client_id, :client_key)
        super
      end

      def funds(session_id, options={})
        results = MultiResponse.run do |r|
          r.process { commit('funds', vanco_fund_list(session_id, options)) }
        end
      end

      def purchase(money, payment_method, options={})
        MultiResponse.run do |r|
          r.process { login }
          r.process { commit('purchase', purchase_request(money, payment_method, r.params['sessionid'], options)) }
        end
      end

      def vanco_purchase(session_id, customer_ref, payment_method_ref, options={})
        MultiResponse.run do |r|
          r.process { commit('purchase', vanco_purchase_request(customer_ref, payment_method_ref, session_id, options)) }
        end
      end

      def refund(money, authorization, options={})
        MultiResponse.run do |r|
          r.process { login }
          r.process { commit('refund', refund_request(money, authorization, r.params['sessionid'])) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((password=)\w+), '\1[FILTERED]').
          gsub(%r((accountnumber=)\d+), '\1[FILTERED]')
      end

      # performs login and returns session id
      def nvp_login
        session_id = nil
        MultiResponse.run do |r|
          r.process { login }
          session_id = r.params['sessionid'] if r.success?
        end
        session_id
      end

      def nvp_encrypt(params)
        encrypt(params)
      end

      private

      def decrypt(value)
        encrypted = Base64.urlsafe_decode64(value)
        c = OpenSSL::Cipher.new('aes-256-ecb')
        c.decrypt
        c.key = @options[:client_key]
        c.padding = 0
        decrypted = c.update(encrypted) + c.final
        inflated = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(decrypted)
      end

      def parse(body)
        results = body.split(/\r?\n/).inject({}) do |acc, pair|
          key, value = pair.split('=')
          acc[key] = CGI.unescape(value)
          acc
        end
        if !results.include?('errorlist') && results.include?('nvpvar')
          results['nvpvar'] = decrypt(results['nvpvar'])
          results['nvpvar'].split('&').each do |pair|
            key, value = pair.split('=')
            results[key] = CGI.unescape(value)
          end
        end
        results
      end

      def commit(request_type, params)
        response = parse(ssl_post(url, post_data(params), headers))
        succeeded = success_from(request_type, response)
        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(request_type, response)
        return (response['creditrequestreceived'] == 'yes') if request_type == 'refund'
        empty?(response['errorlist'])
      end

      def message_from(succeeded, response)
        return 'Success' if succeeded
        response['errorlist'].split(',').map do |no| 
          ((no == '434' && response['ccauthdesc']) ? response['ccauthdesc'] : VANCO_ERROR_CODE[no])
        end.join(', ') + '.'
      end

      def authorization_from(response)
        [
          response['customerref'],
          response['paymentmethodref'],
          response['transactionref'],
          response['ccauthcode']
        ].join('|')
      end

      def split_authorization(authorization)
        authorization.to_s.split('|')
      end

      def purchase_request(money, payment_method, session_id, options)
        doc = {}
        doc['nvpvar'] = {}
        add_auth(doc, 'eftaddcompletetransaction', session_id)
        add_client_id(doc)
        add_amount(doc, money, options)
        add_payment_method(doc, payment_method, options)
        add_options(doc, options)
        add_purchase_noise(doc)
        doc
      end

      def vanco_fund_list(session_id, options)
        doc = {}
        doc['nvpvar'] = {}
        add_auth(doc, 'eftgetfundlist', session_id)
        add_client_id(doc)
        add_options(doc, options)
        doc
      end

      def vanco_purchase_request(customer_ref, payment_method_ref, session_id, options)
        doc = {}
        doc['nvpvar'] = {}
        add_auth(doc, 'eftaddcompletetransaction', session_id)
        add_client_id(doc)
        add_amount(doc, 0, options)
        doc['nvpvar']['customerref'] = customer_ref unless customer_ref.blank?
        doc['nvpvar']['paymentmethodref'] = payment_method_ref unless payment_method_ref.blank?
#        doc['accounttype'] = 'CC'
        doc['nvpvar']['isdebitcardonly'] = 'No'
        add_options(doc, options)
        add_purchase_noise(doc)
        doc
      end

      def refund_request(money, authorization, session_id)
        doc = {}
        doc['nvpvar'] = {}
        add_auth(doc, 'eftaddcredit', session_id)
        add_client_id(doc)
        add_amount(doc, money, options)
        add_reference(doc, authorization)
        add_refund_noise(doc)
        doc
      end

      def add_request(doc, request_type)
        doc['nvpvar'] ||= {}
        doc['nvpvar']['requesttype'] = request_type
        doc['nvpvar']['requestid'] = SecureRandom.hex(15)
      end

      def add_auth(doc, request_type, session_id)
        add_request(doc, request_type)
        doc['sessionid'] = session_id
      end

      def add_reference(doc, authorization)
        customer_ref, payment_method_ref, transaction_ref = split_authorization(authorization)
        doc['nvpvar']['customerref'] = customer_ref
        doc['nvpvar']['paymentmethodref'] = payment_method_ref
        doc['nvpvar']['transactionref'] = transaction_ref
      end

      def add_amount(doc, money, options)
        if empty?(options[:fund_id])
          doc['amount'] = amount(money)
        elsif options[:fund_id].respond_to?(:each_with_index)
          options[:fund_id].each_with_index do |(k,v), i|
            doc['nvpvar']["fundid_#{i}"] = k
            doc['nvpvar']["fundamount_#{i}"] = amount(v)
          end
        else
          doc['nvpvar']["fundid_0"] = options[:fund_id]
          doc['nvpvar']["fundamount_0"] = amount(money)
        end
      end

      def add_payment_method(doc, payment_method, options)
        if card_brand(payment_method) == 'check'
          add_echeck(doc, payment_method)
        else
          add_credit_card(doc, payment_method, options)
        end
      end

      def add_credit_card(doc, credit_card, options)
        doc['accountnumber'] = credit_card.number
        doc['nvpvar']['customername'] = "#{credit_card.last_name}, #{credit_card.first_name}"
        doc['name'] = "#{credit_card.last_name}, #{credit_card.first_name}"
        doc['name_on_card'] = credit_card.name
        doc['cardexpmonth'] = format(credit_card.month, :two_digits)
        doc['cardexpyear'] = format(credit_card.year, :two_digits)
        doc['cvvcode'] = credit_card.verification_value
        doc['cardbillingname'] = credit_card.name
        doc['accounttype'] = 'CC'
        doc['nvpvar']['isdebitcardonly'] = 'No'
        add_billing_address(doc, options)
      end

      def add_billing_address(doc, options)
        address = options[:billing_address]
        return unless address

        doc['cardbillingaddr1'] = address[:address1]
        doc['cardbillingaddr2'] = address[:address2] unless empty?(address[:address2])
        doc['cardbillingcity'] = address[:city]
        doc['cardbillingstate'] = address[:state]
        doc['cardbillingzip'] = address[:zip]
        doc['cardbillingcountrycode'] = address[:country] unless empty?(address[:country])
      end

      def add_echeck(doc, echeck)
        if echeck.account_type == 'savings'
          doc['accounttype'] = 'S'
        else
          doc['accounttype'] = 'C'
        end

        doc['name'] = "#{echeck.last_name}, #{echeck.first_name}"
        doc['nvpvar']['customername'] = "#{echeck.last_name}, #{echeck.first_name}"
        doc['accountnumber'] = echeck.account_number
        doc['routingnumber'] = echeck.routing_number
        doc['nvpvar']['transactiontypecode'] = 'WEB'
      end

      def add_purchase_noise(doc)
        doc['nvpvar']['startdate'] = '0000-00-00'
        doc['nvpvar']['frequencycode'] = 'O'
      end

      def add_refund_noise(doc)
        doc['nvpvar']['contactname'] = 'Bilbo Baggins'
        doc['nvpvar']['contactphone'] = '1234567890'
        doc['nvpvar']['contactextension'] = 'none'
        doc['nvpvar']['reasonforcredit'] = 'Refund requested'
      end

      def add_options(doc, options)
        doc['customeripaddress'] = options[:ip] if options[:ip]
        doc['newcustomer'] = options[:new_customer] if options[:new_customer]
        doc['nvpvar']['customerid'] = options[:customer_id] if options[:customer_id]
      end

      def add_client_id(doc)
        doc['nvpvar']['clientid'] = @options[:client_id]
      end

      def login
        commit('login', login_request)
      end

      def login_request
        doc = {}
        doc['nvpvar'] = {}
        add_request(doc, 'login')
        doc['nvpvar']['userid'] = @options[:user_id]
        doc['nvpvar']['password'] = @options[:password]
        doc
      end

      def url
        (test? ? test_url : live_url)
      end

      def headers
        { 'Content-Type'  => 'application/x-www-form-urlencoded;charset=UTF-8' }
      end

      def post_data(doc)
        if doc.include?('nvpvar')
          nvpvar = doc['nvpvar'].map { |k, v| "#{k.to_s}=#{v.to_s}" }.join('&')
          if doc['nvpvar']['requesttype'] && doc['nvpvar']['requesttype'] != 'login'
            nvpvar = encrypt(nvpvar)
          end
          params = doc.merge({ 'nvpvar' => nvpvar })
        else
          params = doc
        end
        params.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def encrypt(nvpvar)
        deflated = Zlib::Deflate.new(nil, -Zlib::MAX_WBITS).deflate(nvpvar, Zlib::FINISH)
        padding_needed = 16 - (deflated.length % 16)
        padded = deflated + (padding_needed == 16 ? '' : ' ' * padding_needed)
        c = OpenSSL::Cipher.new('aes-256-ecb')
        c.encrypt
        c.key = @options[:client_key]
        c.padding = 0
        encrypted = c.update(padded) + c.final
        nvpvar = Base64.urlsafe_encode64(encrypted)
      end
    end
  end
end
