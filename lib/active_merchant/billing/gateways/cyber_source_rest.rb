require 'active_merchant/billing/gateways/cyber_source/cyber_source_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CyberSourceRestGateway < Gateway
      include ActiveMerchant::Billing::CyberSourceCommon

      self.test_url = 'https://apitest.cybersource.com'
      self.live_url = 'https://api.cybersource.com'

      self.supported_countries = ActiveMerchant::Billing::CyberSourceGateway.supported_countries
      self.default_currency = 'USD'
      self.currencies_without_fractions = ActiveMerchant::Billing::CyberSourceGateway.currencies_without_fractions

      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb maestro elo union_pay cartes_bancaires mada]

      self.homepage_url = 'http://www.cybersource.com'
      self.display_name = 'Cybersource REST'

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

      PAYMENT_SOLUTION = {
        apple_pay: '001',
        google_pay: '012'
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :public_key, :private_key)
        super
      end

      def purchase(money, payment, options = {})
        authorize(money, payment, options, true)
      end

      def authorize(money, payment, options = {}, capture = false)
        post = build_auth_request(money, payment, options)
        post[:processingInformation][:capture] = true if capture

        commit('payments', post)
      end

      def capture(money, authorization, options = {})
        payment = authorization.split('|').first
        post = build_reference_request(money, options)

        commit("payments/#{payment}/captures", post)
      end

      def refund(money, authorization, options = {})
        payment = authorization.split('|').first
        post = build_reference_request(money, options)
        commit("payments/#{payment}/refunds", post)
      end

      def credit(money, payment, options = {})
        post = build_credit_request(money, payment, options)
        commit('credits', post)
      end

      def void(authorization, options = {})
        payment, amount = authorization.split('|')
        post = build_void_request(amount)
        commit("payments/#{payment}/reversals", post)
      end

      def verify(credit_card, options = {})
        amount = eligible_for_zero_auth?(credit_card, options) ? 0 : 100
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(\\?"number\\?":\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?"routingNumber\\?":\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?"securityCode\\?":\\?")\d+/, '\1[FILTERED]').
          gsub(/(signature=")[^"]*/, '\1[FILTERED]').
          gsub(/(keyid=")[^"]*/, '\1[FILTERED]').
          gsub(/(Digest: SHA-256=)[\w\/\+=]*/, '\1[FILTERED]')
      end

      private

      def build_void_request(amount = nil)
        { reversalInformation: { amountDetails: { totalAmount: nil } } }.tap do |post|
          add_reversal_amount(post, amount.to_i) if amount.present?
        end.compact
      end

      def build_auth_request(amount, payment, options)
        { clientReferenceInformation: {}, paymentInformation: {}, orderInformation: {} }.tap do |post|
          add_customer_id(post, options)
          add_code(post, options)
          add_payment(post, payment, options)
          add_amount(post, amount)
          add_address(post, payment, options[:billing_address], options, :billTo)
          add_address(post, payment, options[:shipping_address], options, :shipTo)
        end.compact
      end

      def build_reference_request(amount, options)
        { clientReferenceInformation: {}, orderInformation: {} }.tap do |post|
          add_code(post, options)
          add_amount(post, amount)
        end.compact
      end

      def build_credit_request(amount, payment, options)
        { clientReferenceInformation: {}, paymentInformation: {}, orderInformation: {} }.tap do |post|
          add_code(post, options)
          add_credit_card(post, payment)
          add_amount(post, amount)
          add_address(post, payment, options[:billing_address], options, :billTo)
          add_merchant_description(post, options)
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

      def add_reversal_amount(post, amount)
        currency = options[:currency] || currency(amount)

        post[:reversalInformation][:amountDetails] = {
          totalAmount: localized_amount(amount, currency)
        }
      end

      def add_amount(post, amount)
        currency = options[:currency] || currency(amount)

        post[:orderInformation][:amountDetails] = {
          totalAmount: localized_amount(amount, currency),
          currency: currency
        }
      end

      def add_ach(post, payment)
        post[:paymentInformation][:bank] = {
          account: {
            type: payment.account_type == 'checking' ? 'C' : 'S',
            number: payment.account_number
          },
          routingNumber: payment.routing_number
        }
      end

      def add_payment(post, payment, options)
        post[:processingInformation] = {}
        if payment.is_a?(NetworkTokenizationCreditCard)
          add_network_tokenization_card(post, payment, options)
        elsif payment.is_a?(Check)
          add_ach(post, payment)
        else
          add_credit_card(post, payment)
        end
      end

      def add_network_tokenization_card(post, payment, options)
        post[:processingInformation][:paymentSolution] = PAYMENT_SOLUTION[payment.source]
        post[:processingInformation][:commerceIndicator] = 'internet' unless card_brand(payment) == 'jcb'

        post[:paymentInformation][:tokenizedCard] = {
          number: payment.number,
          expirationMonth: payment.month,
          expirationYear: payment.year,
          cryptogram: payment.payment_cryptogram,
          transactionType: '1',
          type:  CREDIT_CARD_CODES[card_brand(payment).to_sym]
        }

        if card_brand(payment) == 'master'
          post[:consumerAuthenticationInformation] = {
            ucafAuthenticationData: payment.payment_cryptogram,
            ucafCollectionIndicator: '2'
          }
        else
          post[:consumerAuthenticationInformation] = { cavv: payment.payment_cryptogram }
        end
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

      def add_merchant_description(post, options)
        return unless options[:merchant_descriptor_name] || options[:merchant_descriptor_address1] || options[:merchant_descriptor_locality]

        merchant = post[:merchantInformation][:merchantDescriptor] = {}
        merchant[:name] = options[:merchant_descriptor_name] if options[:merchant_descriptor_name]
        merchant[:address1] = options[:merchant_descriptor_address1] if options[:merchant_descriptor_address1]
        merchant[:locality] = options[:merchant_descriptor_locality] if options[:merchant_descriptor_locality]
      end

      def url(action)
        "#{(test? ? test_url : live_url)}/pts/v2/#{action}"
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
        %w(AUTHORIZED PENDING REVERSED).include?(response['status'])
      end

      def message_from(response)
        return response['status'] if success_from(response)

        response['errorInformation']['message'] || response['message']
      end

      def authorization_from(response)
        id = response['id']
        has_amount = response['orderInformation'] && response['orderInformation']['amountDetails'] && response['orderInformation']['amountDetails']['authorizedAmount']
        amount = response['orderInformation']['amountDetails']['authorizedAmount'].delete('.') if has_amount

        return id if amount.blank?

        [id, amount].join('|')
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
          "(request-target)": "#{http_method} /pts/v2/#{resource}",
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
        decoded_key = Base64.decode64(@options[:private_key])
        Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', decoded_key, payload))
      end

      def auth_headers(action, post, http_method = 'post')
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
