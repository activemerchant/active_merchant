require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SafeChargeGateway < Gateway
      self.test_url = 'https://process.sandbox.safecharge.com/service.asmx/Process'
      self.live_url = 'https://process.safecharge.com/service.asmx/Process'

      self.supported_countries = ['AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'GR', 'ES', 'FI', 'FR', 'HR', 'HU', 'IE', 'IS', 'IT', 'LI', 'LT', 'LU', 'LV', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SE', 'SE', 'SI', 'SK', 'GB', 'US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'https://www.safecharge.com'
      self.display_name = 'SafeCharge'

      VERSION = '4.1.0'

      def initialize(options={})
        requires!(options, :client_login_id, :client_password)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_transaction_data("Sale", post, money, options)
        add_payment(post, payment)
        add_customer_details(post, payment, options)

        commit(post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_transaction_data("Auth", post, money, options)
        add_payment(post, payment)
        add_customer_details(post, payment, options)

        commit(post)
      end

      def capture(money, authorization, options={})
        post = {}
        auth, transaction_id, token, exp_month, exp_year, _, original_currency = authorization.split("|")
        add_transaction_data("Settle", post, money, (options.merge!({currency: original_currency})))
        post[:sg_AuthCode] = auth
        post[:sg_TransactionID] = transaction_id
        post[:sg_CCToken] = token
        post[:sg_ExpMonth] = exp_month
        post[:sg_ExpYear] = exp_year

        commit(post)
      end

      def refund(money, authorization, options={})
        post = {}
        auth, transaction_id, token, exp_month, exp_year, _, original_currency = authorization.split("|")
        add_transaction_data("Credit", post, money, (options.merge!({currency: original_currency})))
        post[:sg_CreditType] = 2
        post[:sg_AuthCode] = auth
        post[:sg_TransactionID] = transaction_id
        post[:sg_CCToken] = token
        post[:sg_ExpMonth] = exp_month
        post[:sg_ExpYear] = exp_year

        commit(post)
      end

      def credit(money, payment, options={})
        post = {}
        add_payment(post, payment)
        add_transaction_data("Credit", post, money, options)
        post[:sg_CreditType] = 1

        commit(post)
      end

      def void(authorization, options={})
        post = {}
        auth, transaction_id, token, exp_month, exp_year, original_amount, original_currency = authorization.split("|")
        add_transaction_data("Void", post, (original_amount.to_f * 100), (options.merge!({currency: original_currency})))
        post[:sg_CreditType] = 2
        post[:sg_AuthCode] = auth
        post[:sg_TransactionID] = transaction_id
        post[:sg_CCToken] = token
        post[:sg_ExpMonth] = exp_month
        post[:sg_ExpYear] = exp_year

        commit(post)
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
        transcript.
          gsub(%r((sg_ClientPassword=)[^&]+(&?)), '\1[FILTERED]\2').
          gsub(%r((sg_CardNumber=)[^&]+(&?)), '\1[FILTERED]\2').
          gsub(%r((sg_CVV2=)\d+), '\1[FILTERED]')
      end

      private

      def add_transaction_data(trans_type, post, money, options)
        post[:sg_TransType] = trans_type
        post[:sg_Currency] = (options[:currency] || currency(money))
        post[:sg_Amount] = amount(money)
        post[:sg_ClientLoginID] = @options[:client_login_id]
        post[:sg_ClientPassword] = @options[:client_password]
        post[:sg_ResponseFormat] = "4"
        post[:sg_Version] = VERSION
        post[:sg_ClientUniqueID] = options[:order_id] if options[:order_id]
        post[:sg_UserID] = options[:user_id] if options[:user_id]
        post[:sg_AuthType] = options[:auth_type] if options[:auth_type]
        post[:sg_ExpectedFulfillmentCount] = options[:expected_fulfillment_count] if options[:expected_fulfillment_count]
      end

      def add_payment(post, payment)
        post[:sg_NameOnCard] = payment.name
        post[:sg_CardNumber] = payment.number
        post[:sg_ExpMonth] = format(payment.month, :two_digits)
        post[:sg_ExpYear] = format(payment.year, :two_digits)
        post[:sg_CVV2] = payment.verification_value
      end

      def add_customer_details(post, payment, options)
        if address = options[:billing_address] || options[:address]
          post[:sg_FirstName] = payment.first_name
          post[:sg_LastName] = payment.last_name
          post[:sg_Address] = address[:address1] if address[:address1]
          post[:sg_City] = address[:city] if address[:city]
          post[:sg_State] = address[:state]  if address[:state]
          post[:sg_Zip] = address[:zip]  if address[:zip]
          post[:sg_Country] = address[:country]  if address[:country]
          post[:sg_Phone] = address[:phone]  if address[:phone]
        end

        post[:sg_Email] = options[:email]
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.root.xpath('*').each do |node|
          response[node.name.underscore.downcase.to_sym] = node.text
        end

        response
      end

      def childnode_to_response(response, node, childnode)
        name = "#{node.name.downcase}_#{childnode.name.downcase}"
        if name == 'payment_method_data' && !childnode.elements.empty?
          response[name.to_sym] = Hash.from_xml(childnode.to_s).values.first
        else
          response[name.to_sym] = childnode.text
        end
      end

      def commit(parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, parameters),
          avs_result: AVSResult.new(code: response[:avs_code]),
          cvv_result: CVVResult.new(response[:cvv2_reply]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response[:status] == "APPROVED"
      end

      def message_from(response)
        return "Success" if success_from(response)
        response[:reason_codes] || response[:reason]
      end

      def authorization_from(response, parameters)
        [
          response[:auth_code],
          response[:transaction_id],
          response[:token],
          parameters[:sg_ExpMonth],
          parameters[:sg_ExpYear],
          parameters[:sg_Amount],
          parameters[:sg_Currency]
        ].join("|")
      end

      def split_authorization(authorization)
        auth_code, transaction_id, token, month, year, original_amount = authorization.split("|")

        {
          auth_code: auth_code,
          transaction_id: transaction_id,
          token: token,
          exp_month: month,
          exp_year: year,
          original_amount: amount(original_amount.to_f * 100)
        }
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value != false && value.blank?
          "#{key}=#{CGI.escape(value.to_s)}"
        end.compact.join("&")
      end

      def error_code_from(response)
        unless success_from(response)
          response[:ex_err_code] || response[:err_code]
        end
      end

      def underscore(camel_cased_word)
        camel_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("-", "_").
          downcase
      end
    end
  end
end
