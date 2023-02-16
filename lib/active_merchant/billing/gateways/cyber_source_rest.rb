require 'active_merchant/billing/gateways/cyber_source/cyber_source_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CyberSourceRestGateway < Gateway
      include ActiveMerchant::Billing::CyberSourceCommon

      self.test_url = 'https://apitest.cybersource.com'
      self.live_url = 'https://api.cybersource.com'

      self.supported_countries = ActiveMerchant::Billing::CyberSourceGateway.supported_countries
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb maestro elo union_pay cartes_bancaires mada]

      self.homepage_url = 'http://www.cybersource.com'
      self.display_name = 'CyberSourceRest'

      CREDIT_CARD_CODES = {
        american_express: '003',
        cartes_bancaires: '036',
        dankort: '034',
        diners_club: '005',
        discover: '004',
        elo: '054',
        jcb: '007',
        maestro: '042',
        master: '002',
        unionpay: '062',
        visa: '001'
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :public_key, :private_key)
        super
      end

      def purchase(money, payment, options = {})
        authorize(money, payment, options) do |post|
          post[:processingInformation] = { capture: true }
        end
      end

      def authorize(money, payment, options = {})
        post = build_auth_request(money, payment, options)

        yield post if block_given?

        commit('/pts/v2/payments/', post)
      end

      def store(payment, options = {})
        build_store_request(payment, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(\\?"number\\?":\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?"securityCode\\?":\\?")\d+/, '\1[FILTERED]').
          gsub(/(signature=")[^"]*/, '\1[FILTERED]').
          gsub(/(keyid=")[^"]*/, '\1[FILTERED]').
          gsub(/(Digest: SHA-256=)[\w\/\+=]*/, '\1[FILTERED]')
      end

      private

      def create_instrument_identifier
        commit('tms/v1/instrumentidentifiers')
      end

      def create_customer(payment, options)
        { buyerInformation: {}, clientReferenceInformation: {}, merchantDefinedInformation: [] }.tap do |post|
          post[:buyerInformation][:merchantCustomerId] = options[:customer_id]
          post[:buyerInformation][:email] = options[:email].presence || 'null@cybersource.com'
          add_code(post, options)
          post[:merchantDefinedInformation] = [ { name: 'data1', value: 'x' } ]
        end.compact
      end

      def build_store_request(payment, options)
        customer = create_customer(payment, options)
        require 'pry'
        binding.pry
        response = commit('/tms/v2/customers/', customer)
      end

      def build_auth_request(amount, payment, options)
        { clientReferenceInformation: {}, paymentInformation: {}, orderInformation: {} }.tap do |post|
          add_customer_id(post, options)
          add_code(post, options)
          add_credit_card(post, payment)
          add_amount(post, amount)
          add_address(post, payment, options[:billing_address], options, :billTo)
          add_address(post, payment, options[:shipping_address], options, :shipTo)
        end.compact
      end

      def add_code(post, options)
        return unless options[:order_id].present?

        post[:clientReferenceInformation][:code] = options[:order_id]
      end

      def add_customer_id(post, options)
        return unless options[:customer_id].present?

        post[:paymentInformation][:customer] = { customerId: options[:customer_id] }
      end

      def add_amount(post, amount)
        currency = options[:currency] || currency(amount)

        post[:orderInformation][:amountDetails] = {
          totalAmount: localized_amount(amount, currency),
          currency: currency
        }
      end

      def add_credit_card(post, creditcard)
        post[:paymentInformation][:card] = {
          number: creditcard.number,
          expirationMonth: format(creditcard.month, :two_digits),
          expirationYear: format(creditcard.year, :four_digits),
          securityCode: creditcard.verification_value,
          type: CREDIT_CARD_CODES[card_brand(creditcard).to_sym]
        }
      end

      def add_address(post, payment_method, address, options, address_type)
        return unless address.present?

        first_name, last_name = address_names(address[:name], payment_method)

        post[:orderInformation][address_type] = {
          firstName:             first_name,
          lastName:              last_name,
          address1:              address[:address1],
          address2:              address[:address2],
          locality:              address[:city],
          administrativeArea:    address[:state],
          postalCode:            address[:zip],
          country:               lookup_country_code(address[:country])&.value,
          email:                 options[:email].presence || 'null@cybersource.com',
          phoneNumber:           address[:phone]
          # merchantTaxID:         ship_to ? options[:merchant_tax_id] : nil,
          # company:               address[:company],
          # companyTaxID:          address[:companyTaxID],
          # ipAddress:             options[:ip],
          # driversLicenseNumber:  options[:drivers_license_number],
          # driversLicenseState:   options[:drivers_license_state],
        }.compact
      end

      def url(action)
        "#{(test? ? test_url : live_url)}#{action}"
      end

      def host
        URI.parse(url('')).host
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, post)
        response = parse(ssl_post(url(action), post.to_json, auth_headers(action, post)))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response.dig('processorInformation', 'avs', 'code')),
          # cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ActiveMerchant::ResponseError => e
        response = e.response.body.present? ? parse(e.response.body) : { 'response' => { 'rmsg' => e.response.msg } }
        Response.new(false, response.dig('response', 'rmsg'), response, test: test?)
      end

      def success_from(response)
        response['status'] == 'AUTHORIZED'
      end

      def message_from(response)
        return response['status'] if success_from(response)

        response['errorInformation']['message']
      end

      def authorization_from(response)
        response['id']
      end

      def error_code_from(response)
        response['errorInformation']['reason'] unless success_from(response)
      end

      # This implementation follows the Cybersource guide on how create the request signature, see:
      # https://developer.cybersource.com/docs/cybs/en-us/payments/developer/all/rest/payments/GenerateHeader/httpSignatureAuthentication.html
      def get_http_signature(resource, digest, http_method = 'post', gmtdatetime = Time.now.httpdate)
        string_to_sign = {
          host: host,
          date: gmtdatetime,
          "(request-target)": "#{http_method} #{resource}",
          digest: digest,
          "v-c-merchant-id": @options[:merchant_id]
        }.map { |k, v| "#{k}: #{v}" }.join("\n").force_encoding(Encoding::UTF_8)

        {
          keyid: @options[:public_key],
          algorithm: 'HmacSHA256',
          headers: "host date (request-target)#{digest.present? ? ' digest' : ''} v-c-merchant-id",
          signature: sign_payload(string_to_sign)
        }.map { |k, v| %{#{k}="#{v}"} }.join(', ')
      end

      def sign_payload(payload)
        require 'pry'
        binding.pry
        decoded_key = Base64.decode64(@options[:private_key])
        Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', decoded_key, payload))
      end

      def auth_headers(action, post, http_method = 'post')
        require 'pry'
        binding.pry
        digest = "SHA-256=#{Digest::SHA256.base64digest(post.to_json)}" if post.present?
        date = Time.now.httpdate

        {
          'Accept' => 'application/hal+json;charset=utf-8',
          'Content-Type' => 'application/json;charset=utf-8',
          'V-C-Merchant-Id' => @options[:merchant_id],
          'Date' => date,
          'Host' => host,
          'Signature' => get_http_signature(action, digest, http_method, date),
          'Digest' => digest
        }
      end
    end
  end
end
