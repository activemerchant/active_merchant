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

      def initialize(options = {})
        requires!(options, :merchant_id, :public_key, :private_key)
        super
      end

      def purchase(money, payment, options = {})
        authorize(money, payment, options, true)
      end

      def authorize(money, payment, options = {}, capture = false)
        post = build_auth_request(money, payment, options)
        post[:processingInformation] = { capture: true } if capture && !options[:third_party_token]
        post[:paymentInformation][:customer] = { id: options[:third_party_token] } if options[:third_party_token]
        commit('/pts/v2/payments/', post)
      end

      def store(payment, options = {})
        MultiResponse.run do |r|
          customer = create_customer(payment, options)
          customer_response = r.process { commit('/tms/v2/customers', customer) }
          instrument_identifier = r.process { create_instrument_identifier(payment, options) }
          r.process { create_payment_instrument(payment, instrument_identifier, options) }
          r.process { create_customer_payment_instrument(payment, options, customer_response, instrument_identifier) }
        end
      end

      def unstore(options = {})
        customer_token_id = options[:customer_token_id]
        payment_instrument_id = options[:payment_instrument_id]
        commit("/tms/v2/customers/#{customer_token_id}/payment-instruments/#{payment_instrument_id}/", nil, :delete)
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

      def create_customer(payment, options)
        { buyerInformation: {}, clientReferenceInformation: {}, merchantDefinedInformation: [] }.tap do |post|
          post[:buyerInformation][:merchantCustomerId] = options[:customer_id]
          post[:buyerInformation][:email] = options[:email].presence || 'null@cybersource.com'
          add_code(post, options)
        end.compact
      end

      def create_instrument_identifier(payment, options)
        instrument_identifier = {
          card: {
            number: payment.number
          }
        }
        commit('/tms/v1/instrumentidentifiers', instrument_identifier)
      end

      def create_payment_instrument(payment, instrument_identifier, options)
        post = {
          card: {
            expirationMonth: payment.month.to_s,
            expirationYear: payment.year.to_s,
            type: payment.brand
          },
          billTo: {
            firstName: options[:billing_address][:name].split.first,
            lastName: options[:billing_address][:name].split.last,
            company: options[:company],
            address1: options[:billing_address][:address1],
            locality: options[:billing_address][:city],
            administrativeArea: options[:billing_address][:state],
            postalCode: options[:billing_address][:zip],
            country: options[:billing_address][:country],
            email: options[:email],
            phoneNumber: options[:billing_address][:phone]
          },
          instrumentIdentifier: {
            id: instrument_identifier.params['id']
          }
        }
        commit('/tms/v1/paymentinstruments', post)
      end

      def create_customer_payment_instrument(payment, options, customer_token, instrument_identifier)
        post = {}
        post[:deafult] = 'true'
        post[:card] = {}
        post[:card][:type] = CREDIT_CARD_CODES[payment.brand.to_sym]
        post[:card][:expirationMonth] = payment.month.to_s
        post[:card][:expirationYear] = payment.year.to_s
        post[:billTo] = {
          firstName: options[:billing_address][:name].split.first,
          lastName: options[:billing_address][:name].split.last,
          company: options[:company],
          address1: options[:billing_address][:address1],
          locality: options[:billing_address][:city],
          administrativeArea: options[:billing_address][:state],
          postalCode: options[:billing_address][:zip],
          country: options[:billing_address][:country],
          email: options[:email],
          phoneNumber: options[:billing_address][:phone]
        }
        post[:instrumentIdentifier] = {}
        post[:instrumentIdentifier][:id] = instrument_identifier.params['id']
        commit("/tms/v2/customers/#{customer_token.params['id']}/payment-instruments", post)
      end

      def build_auth_request(amount, payment, options)
        { clientReferenceInformation: {}, paymentInformation: {}, orderInformation: {} }.tap do |post|
          add_customer_id(post, options) unless options[:third_party_token]
          add_code(post, options)
          add_credit_card(post, payment) unless options[:third_party_token]
          add_amount(post, amount)
          add_address(post, payment, options[:billing_address], options, :billTo) unless options[:third_party_token]
          add_address(post, payment, options[:shipping_address], options, :shipTo) unless options[:third_party_token]
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
        JSON.parse(body.nil? ? '{}' : body)
      end

      def commit(action, post, http_method = :post)
        headers = http_method == :delete ? auth_headers_delete(action, post, http_method) : auth_headers(action, post, http_method)
        response = parse(ssl_request(http_method, url(action), post.nil? || post.empty? ? nil : post.to_json, headers))
        Response.new(
          success_from(action, response, http_method),
          message_from(action, response, http_method),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response.dig('processorInformation', 'avs', 'code')),
          # cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(action, response, http_method)
        )
      rescue ActiveMerchant::ResponseError => e
        response = e.response.body.present? ? parse(e.response.body) : { 'response' => { 'rmsg' => e.response.msg } }
        Response.new(false, response.dig('response', 'rmsg'), response, test: test?)
      end

      def success_from(action, response, http_method)
        case action
        when /payments/
          response['status'] == 'AUTHORIZED'
        else
          return response['id'].present? unless http_method == :delete

          return true
        end
      end

      def message_from(action, response, http_method)
        return response['status'] if success_from(action, response, http_method)

        response['errorInformation']['message']
      end

      def authorization_from(response)
        response['id']
      end

      def error_code_from(action, response, http_method)
        response['errorInformation']['reason'] unless success_from(action, response, http_method)
      end

      # This implementation follows the Cybersource guide on how create the request signature, see:
      # https://developer.cybersource.com/docs/cybs/en-us/payments/developer/all/rest/payments/GenerateHeader/httpSignatureAuthentication.html
      def get_http_signature(resource, digest, http_method = :post, gmtdatetime = Time.now.httpdate)
        string_to_sign = {
          host: host,
          date: gmtdatetime,
          "(request-target)": "#{http_method} #{resource}",
          digest: digest,
          "v-c-merchant-id": @options[:merchant_id]
        }.map { |k, v| "#{k}: #{v}" }.join("\n").force_encoding(Encoding::UTF_8)
        delete_string_to_sign = {
          host: host,
          "v-c-date": gmtdatetime,
          "(request-target)": "#{http_method} #{resource}",
          "v-c-merchant-id": @options[:merchant_id]
        }.map { |k, v| "#{k}: #{v}" }.join("\n").force_encoding(Encoding::UTF_8)

        {
          keyid: @options[:public_key],
          algorithm: 'HmacSHA256',
          headers: "host#{http_method == :delete ? ' v-c-date' : ' date'} (request-target)#{digest.present? ? ' digest' : ''} v-c-merchant-id",
          signature: sign_payload(http_method == :delete ? delete_string_to_sign : string_to_sign)
        }.map { |k, v| %{#{k}="#{v}"} }.join(', ')
      end

      def sign_payload(payload)
        decoded_key = Base64.decode64(@options[:private_key])
        Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', decoded_key, payload))
      end

      def auth_headers_delete(action, post, http_method)
        date = Time.now.httpdate
        {
          'v-c-date' => date,
          'V-C-Merchant-Id' => @options[:merchant_id],
          'Host' => host,
          'Signature' => get_http_signature(action, nil, http_method, date)
        }
      end

      def auth_headers(action, post, http_method = :post)
        digest = "SHA-256=#{Digest::SHA256.base64digest(post.to_json)}" if post.present?

        date = Time.now.httpdate
        accept = /payments/.match?(action) ? 'application/hal+json;charset=utf-8' : 'application/json;charset=utf-8'
        headers = {
          'Accept' => accept,
          'Content-Type' => 'application/json;charset=utf-8',
          'V-C-Merchant-Id' => @options[:merchant_id],
          'Host' => host,
          'Signature' => get_http_signature(action, digest, http_method, date),
          'Digest' => digest
        }
        headers.merge!(http_method == :delete ? { 'v-c-date' => date } : { 'date' => date })
        headers
      end
    end
  end
end
