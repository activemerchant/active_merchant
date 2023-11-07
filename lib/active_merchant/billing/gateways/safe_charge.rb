require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SafeChargeGateway < Gateway
      self.test_url = 'https://process.sandbox.safecharge.com/service.asmx/Process'
      self.live_url = 'https://process.safecharge.com/service.asmx/Process'

      self.supported_countries = %w[AT BE BG CY CZ DE DK EE GR ES FI FR GI HK HR HU IE IS IT LI LT LU LV MT MX NL NO PL PT RO SE SG SI SK GB US]
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master]

      self.homepage_url = 'https://www.safecharge.com'
      self.display_name = 'SafeCharge'

      VERSION = '4.1.0'

      def initialize(options = {})
        requires!(options, :client_login_id, :client_password)
        super
      end

      def purchase(money, payment, options = {})
        post = {}

        # Determine if 3DS is requested, or there is standard external MPI data
        if options[:three_d_secure]
          if options[:three_d_secure].is_a?(Hash)
            add_external_mpi_data(post, options)
          else
            post[:sg_APIType] = 1
            trans_type = 'Sale3D'
          end
        end

        trans_type ||= 'Sale'

        add_transaction_data(trans_type, post, money, options)
        add_payment(post, payment, options)
        add_customer_details(post, payment, options)

        commit(post)
      end

      def authorize(money, payment, options = {})
        post = {}

        add_external_mpi_data(post, options) if options[:three_d_secure]&.is_a?(Hash)
        add_transaction_data('Auth', post, money, options)
        add_payment(post, payment, options)
        add_customer_details(post, payment, options)

        commit(post)
      end

      def capture(money, authorization, options = {})
        post = {}
        auth, transaction_id, token, exp_month, exp_year, _, original_currency = authorization.split('|')
        add_transaction_data('Settle', post, money, options.merge!({ currency: original_currency }))
        post[:sg_AuthCode] = auth
        post[:sg_TransactionID] = transaction_id
        post[:sg_CCToken] = token
        post[:sg_ExpMonth] = exp_month
        post[:sg_ExpYear] = exp_year
        post[:sg_Email] = options[:email]

        commit(post)
      end

      def refund(money, authorization, options = {})
        post = {}
        auth, transaction_id, token, exp_month, exp_year, _, original_currency = authorization.split('|')
        add_transaction_data('Credit', post, money, options.merge!({ currency: original_currency }))
        post[:sg_CreditType] = 2
        post[:sg_AuthCode] = auth
        post[:sg_CCToken] = token
        post[:sg_ExpMonth] = exp_month
        post[:sg_ExpYear] = exp_year
        post[:sg_TransactionID] = transaction_id unless options[:unreferenced_refund]

        commit(post)
      end

      def credit(money, payment, options = {})
        post = {}

        add_payment(post, payment, options)
        add_transaction_data('Credit', post, money, options)
        add_customer_details(post, payment, options)

        options[:unreferenced_refund].to_s == 'true' ? post[:sg_CreditType] = 2 : post[:sg_CreditType] = 1

        commit(post)
      end

      def void(authorization, options = {})
        post = {}
        auth, transaction_id, token, exp_month, exp_year, original_amount, original_currency = authorization.split('|')
        add_transaction_data('Void', post, (original_amount.to_f * 100), options.merge!({ currency: original_currency }))
        post[:sg_CreditType] = 2
        post[:sg_AuthCode] = auth
        post[:sg_TransactionID] = transaction_id
        post[:sg_CCToken] = token
        post[:sg_ExpMonth] = exp_month
        post[:sg_ExpYear] = exp_year

        commit(post)
      end

      def verify(credit_card, options = {})
        authorize(0, credit_card, options)
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
        currency = options[:currency] || currency(money)

        post[:sg_TransType] = trans_type
        post[:sg_Currency] = currency
        post[:sg_Amount] = localized_amount(money, currency)
        post[:sg_ClientLoginID] = @options[:client_login_id]
        post[:sg_ClientPassword] = @options[:client_password]
        post[:sg_ResponseFormat] = '4'
        post[:sg_Version] = VERSION
        post[:sg_ClientUniqueID] = options[:order_id] if options[:order_id]
        post[:sg_UserID] = options[:user_id] if options[:user_id]
        post[:sg_AuthType] = options[:auth_type] if options[:auth_type]
        post[:sg_ExpectedFulfillmentCount] = options[:expected_fulfillment_count] if options[:expected_fulfillment_count]
        post[:sg_WebsiteID] = options[:website_id] if options[:website_id]
        post[:sg_IPAddress] = options[:ip] if options[:ip]
        post[:sg_VendorID] = options[:vendor_id] if options[:vendor_id]
        post[:sg_Descriptor] = options[:merchant_descriptor] if options[:merchant_descriptor]
        post[:sg_MerchantPhoneNumber] = options[:merchant_phone_number] if options[:merchant_phone_number]
        post[:sg_MerchantName] = options[:merchant_name] if options[:merchant_name]
        post[:sg_ProductID] = options[:product_id] if options[:product_id]
        post[:sg_NotUseCVV] = options[:not_use_cvv].to_s == 'true' ? 1 : 0 unless options[:not_use_cvv].nil?
      end

      def add_payment(post, payment, options = {})
        post[:sg_ExpMonth] = format(payment.month, :two_digits)
        post[:sg_ExpYear] = format(payment.year, :two_digits)
        post[:sg_CardNumber] = payment.number

        if payment.is_a?(NetworkTokenizationCreditCard) && payment.source == :network_token
          post[:sg_CAVV] = payment.payment_cryptogram
          post[:sg_ECI] = options[:three_d_secure] && options[:three_d_secure][:eci] || '05'
          post[:sg_IsExternalMPI] = 1
          post[:sg_ExternalTokenProvider] = 5
        else
          post[:sg_CVV2] = payment.verification_value
          post[:sg_NameOnCard] = payment.name
          post[:sg_StoredCredentialMode] = (options[:stored_credential_mode] == true ? 1 : 0)
        end
      end

      def add_customer_details(post, payment, options)
        if address = options[:billing_address] || options[:address]
          post[:sg_FirstName] = payment.first_name
          post[:sg_LastName] = payment.last_name
          post[:sg_Address] = address[:address1] if address[:address1]
          post[:sg_City] = address[:city] if address[:city]
          post[:sg_State] = address[:state]  if address[:state]
          post[:sg_Zip] = address[:zip] if address[:zip]
          post[:sg_Country] = address[:country] if address[:country]
          post[:sg_Phone] = address[:phone] if address[:phone]
        end

        post[:sg_Email] = options[:email]
      end

      def add_external_mpi_data(post, options)
        post[:sg_ECI] = options[:three_d_secure][:eci] if options[:three_d_secure][:eci]
        post[:sg_CAVV] = options[:three_d_secure][:cavv] if options[:three_d_secure][:cavv]
        post[:sg_dsTransID] = options[:three_d_secure][:ds_transaction_id] if options[:three_d_secure][:ds_transaction_id]
        post[:sg_threeDSProtocolVersion] = options[:three_d_secure][:ds_transaction_id] ? '2' : '1'
        post[:sg_Xid] = options[:three_d_secure][:xid]
        post[:sg_IsExternalMPI] = 1
        post[:sg_EnablePartialApproval] = options[:is_partial_approval]
        post[:sg_challengePreference] = options[:three_d_secure][:challenge_preference] if options[:three_d_secure][:challenge_preference]
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.root.xpath('*').each do |node|
          if node.elements.size == 0
            response[node.name.underscore.downcase.to_sym] = node.text
          else
            node.traverse do |childnode|
              childnode_to_response(response, childnode)
            end
          end
        end
        response
      end

      def childnode_to_response(response, childnode)
        if childnode.elements.size == 0
          element_name_to_symbol(response, childnode)
        else
          childnode.traverse do |node|
            element_name_to_symbol(response, node)
          end
        end
      end

      def element_name_to_symbol(response, childnode)
        name = childnode.name.downcase
        response[name.to_sym] = childnode.text
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
        response[:status] == 'APPROVED'
      end

      def message_from(response)
        return 'Success' if success_from(response)

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
        ].join('|')
      end

      def split_authorization(authorization)
        auth_code, transaction_id, token, month, year, original_amount = authorization.split('|')

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
        end.compact.join('&')
      end

      def error_code_from(response)
        response[:ex_err_code] || response[:err_code] unless success_from(response)
      end

      def underscore(camel_cased_word)
        camel_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
          gsub(/([a-z\d])([A-Z])/, '\1_\2').
          tr('-', '_').
          downcase
      end
    end
  end
end
