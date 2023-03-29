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

        commit('payments', post, options)
      end

      def capture(money, authorization, options = {})
        payment = authorization.split('|').first
        post = build_reference_request(money, options)

        commit("payments/#{payment}/captures", post, options)
      end

      def refund(money, authorization, options = {})
        payment = authorization.split('|').first
        post = build_reference_request(money, options)
        commit("payments/#{payment}/refunds", post, options)
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

      def store(payment, options = {})
        MultiResponse.run do |r|
          if options[:customer_id].nil?
            customer_id = r.process { create_customer_request(payment, options) }.params['id']
            return r unless r.success?
          else
            customer_id = options[:customer_id]
          end
          instrument_identifier = r.process { create_instrument_identifier_request(payment, options) }
          return instrument_identifier unless instrument_identifier.success?

          r.process { create_customer_payment_instrument_request(payment, options, customer_id, instrument_identifier) }
        end
      end

      def unstore(stored_token)
        customer_id, payment_instrument_id = stored_token.split('|')
        commit("customers/#{customer_id}/payment-instruments/#{payment_instrument_id}/", nil, :delete)
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
          add_mdd_fields(post, options)
          add_amount(post, amount, options)
          add_address(post, payment, options[:billing_address], options, :billTo)
          add_address(post, payment, options[:shipping_address], options, :shipTo)
          add_business_rules_data(post, payment, options)
          add_partner_solution_id(post)
          add_stored_credentials(post, payment, options)
          add_order_id(post, options)
        end.compact
      end

      def build_reference_request(amount, options)
        { clientReferenceInformation: {}, orderInformation: {} }.tap do |post|
          add_order_id(post, options)
          add_code(post, options)
          add_mdd_fields(post, options)
          add_amount(post, amount)
          add_partner_solution_id(post)
        end.compact
      end

      def build_credit_request(amount, payment, options)
        { clientReferenceInformation: {}, paymentInformation: {}, orderInformation: {} }.tap do |post|
          add_order_id(post, options)
          add_credit_card(post, payment)
          add_mdd_fields(post, options)
          add_amount(post, amount, options)
          add_address(post, payment, options[:billing_address], options, :billTo)
          add_merchant_description(post, options)
        end.compact
      end

      def create_customer_request(payment, options)
        customer = { buyerInformation: {}, clientReferenceInformation: {}, merchantDefinedInformation: [] }.tap do |post|
          post[:buyerInformation][:merchantCustomerId] = options[:merchant_customer_id] if options[:merchant_customer_id]
          post[:buyerInformation][:email] = options[:email].presence || 'null@cybersource.com'
          add_order_id(post, options)
        end.compact
        commit('customers', customer)
      end

      def create_instrument_identifier_request(payment, options)
        instrument_identifier = {
          card: {
            number: payment.number
          }
        }
        commit('instrumentidentifiers', instrument_identifier)
      end

      def create_customer_payment_instrument_request(payment, options, customer_id, instrument_identifier)
        post = {}
        post[:default] = 'true'
        post[:card] = {}
        post[:card][:type] = CREDIT_CARD_CODES[payment.brand.to_sym]
        post[:card][:expirationMonth] = payment.month.to_s
        post[:card][:expirationYear] = payment.year.to_s
        add_address(post, payment, options[:billing_address], options, :billTo, nil)
        post[:instrumentIdentifier] = {}
        post[:instrumentIdentifier][:id] = instrument_identifier.params['id']
        commit("customers/#{customer_id}/payment-instruments", post)
      end

      def add_order_id(post, options)
        return unless options[:order_id].present?

        post[:clientReferenceInformation][:code] = options[:order_id]
      end

      def add_reversal_amount(post, amount)
        currency = options[:currency] || currency(amount)

        post[:reversalInformation][:amountDetails] = {
          totalAmount: localized_amount(amount, currency)
        }
      end

      def add_amount(post, amount, options)
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
        elsif payment.is_a?(String)
          add_stored_payment(post, payment, options)
        else
          add_credit_card(post, payment)
        end
      end

      def add_stored_payment(post, payment, options)
        customer_id, payment_instrument_id = payment.split('|')
        post[:paymentInstrument] = {
          id: payment_instrument_id
        }
        post[:paymentInformation][:customer] = {
          id: customer_id
        }
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

      def add_address(post, payment_method, address, options, address_type, order = :orderInformation)
        return unless address.present?

        first_name, last_name = address_names(address[:name], payment_method)
        address_hash = {
          firstName:             first_name,
          lastName:              last_name,
          address1:              address[:address1],
          address2:              address[:address2],
          locality:              address[:city],
          administrativeArea:    address[:state],
          postalCode:            address[:zip],
          country:               lookup_country_code(address[:country])&.value,
          email:                 options[:email].presence || 'null@cybersource.com',
          phoneNumber:           address[:phone],
          # merchantTaxID:         ship_to ? options[:merchant_tax_id] : nil,
          company:               address[:company]
          # companyTaxID:          address[:companyTaxID],
          # ipAddress:             options[:ip],
          # driversLicenseNumber:  options[:drivers_license_number],
          # driversLicenseState:   options[:drivers_license_state],
        }.compact
        if order.nil?
          post[address_type] = address_hash
        else
          post[order][address_type] = address_hash
        end
      end

      def add_merchant_description(post, options)
        return unless options[:merchant_descriptor_name] || options[:merchant_descriptor_address1] || options[:merchant_descriptor_locality]

        merchant = post[:merchantInformation][:merchantDescriptor] = {}
        merchant[:name] = options[:merchant_descriptor_name] if options[:merchant_descriptor_name]
        merchant[:address1] = options[:merchant_descriptor_address1] if options[:merchant_descriptor_address1]
        merchant[:locality] = options[:merchant_descriptor_locality] if options[:merchant_descriptor_locality]
      end

      def add_stored_credentials(post, payment, options)
        return unless stored_credential = options[:stored_credential]

        options = stored_credential_options(stored_credential, options.fetch(:reason_code, ''))
        post[:processingInformation][:commerceIndicator] = options.fetch(:transaction_type, 'internet')
        stored_credential[:initial_transaction] ? initial_transaction(post, options) : subsequent_transaction(post, options)
      end

      def stored_credential_options(options, reason_code)
        transaction_type = options[:reason_type]
        transaction_type = 'install' if transaction_type == 'installment'
        initiator = options[:initiator] if  options[:initiator]
        initiator = 'customer' if initiator == 'cardholder'
        stored_on_file = options[:reason_type] == 'recurring'
        options.merge({
          transaction_type: transaction_type,
          initiator: initiator,
          reason_code: reason_code,
          stored_on_file: stored_on_file
        })
      end

      def add_processing_information(initiator, merchant_initiated_transaction_hash = {})
        {
          authorizationOptions: {
            initiator: {
              type: initiator,
              merchantInitiatedTransaction: merchant_initiated_transaction_hash,
              storedCredentialUsed: true
            }
          }
        }.compact
      end

      def initial_transaction(post, options)
        processing_information = add_processing_information(options[:initiator], {
          reason: options[:reason_code]
        })

        post[:processingInformation].merge!(processing_information)
      end

      def subsequent_transaction(post, options)
        network_transaction_id = options[:network_transaction_id] || options.dig(:stored_credential, :network_transaction_id) || ''
        processing_information = add_processing_information(options[:initiator], {
          originalAuthorizedAmount: post.dig(:orderInformation, :amountDetails, :totalAmount),
          previousTransactionID: network_transaction_id,
          reason: options[:reason_code],
          storedCredentialUsed: options[:stored_on_file]
        })
        post[:processingInformation].merge!(processing_information)
      end

      def network_transaction_id_from(response)
        response.dig('processorInformation', 'networkTransactionId')
      end

      def url(action)
        case action
        when /customers/
          "#{(test? ? test_url : live_url)}/tms/v2/#{action}"
        when 'instrumentidentifiers', 'paymentinstruments'
          "#{(test? ? test_url : live_url)}/tms/v1/#{action}"
        else
          "#{(test? ? test_url : live_url)}/pts/v2/#{action}"
        end
      end

      def host
        URI.parse(url('')).host
      end

      def parse(body)
        return {} if body.blank?

        JSON.parse(body)
      end

      def commit(action, post, http_method = :post, options = {})
        add_reconciliation_id(post, options)
        add_sec_code(post, options)
        add_invoice_number(post, options)
        response = parse(ssl_request(http_method, url(action), post.nil? || post.empty? ? nil : post.to_json, auth_headers(action, post, http_method)))
        succeeded = success_from(action, response, http_method)
        body = action == :delete ? { response_code: response.to_s } : response

        Response.new(
          succeeded,
          message_from(body, succeeded, http_method),
          response,
          authorization: authorization_from(response, action),
          avs_result: AVSResult.new(code: response.dig('processorInformation', 'avs', 'code')),
          # cvv_result: CVVResult.new(response['some_cvv_response_key']),
          network_transaction_id: network_transaction_id_from(response),
          test: test?,
          error_code: error_code_from(response, succeeded)
        )
      rescue ActiveMerchant::ResponseError => e
        response = e.response.body.present? ? parse(e.response.body) : { 'response' => { 'rmsg' => e.response.msg } }
        message = response.dig('response', 'rmsg') || response.dig('message')
        Response.new(false, message, response, test: test?)
      end

      def success_from(action, response, http_method)
        return response.empty? if http_method == :delete

        case action
        when /payments/
          %w(AUTHORIZED PENDING REVERSED).include?(response['status'])
        else
          return response['id'].present? && !response['errorInformation'].present? unless http_method == :delete
        end
      end

      def message_from(response, succeeded, http_method)
        return 'OK' if succeeded && http_method == :delete
        return response['status'] if succeeded

        response['errorInformation']['message'] || response['message']
      end

      def authorization_from(response, action)
        id = response['id']
        has_amount = response['orderInformation'] && response['orderInformation']['amountDetails'] && response['orderInformation']['amountDetails']['authorizedAmount']
        amount = response['orderInformation']['amountDetails']['authorizedAmount'].delete('.') if has_amount
        if /payment-instruments/.match(action) && !response.empty?
          customer_id = response['_links']['customer']['href'].split('/').last
          payment_instrument_id = response['id']
          return [customer_id, payment_instrument_id].join('|')
        end
        return id if amount.blank?

        [id, amount].join('|')
      end

      def error_code_from(response, succeeded)
        response['errorInformation']['reason'] unless succeeded
      end

      # This implementation follows the Cybersource guide on how create the request signature, see:
      # https://developer.cybersource.com/docs/cybs/en-us/payments/developer/all/rest/payments/GenerateHeader/httpSignatureAuthentication.html
      def get_http_signature(resource, digest, http_method = 'post', gmtdatetime = Time.now.httpdate)
        target = URI.parse(url(resource)).path

        hash_to_sign = {
          host: host,
          date: gmtdatetime,
          "(request-target)": "#{http_method} #{target}",
          digest: digest,
          "v-c-merchant-id": @options[:merchant_id]
        }
        hash_to_sign.delete(:digest) if http_method == :delete
        string_to_sign = hash_to_sign.map { |k, v| "#{k}: #{v}" }.join("\n").force_encoding(Encoding::UTF_8)

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
          'Accept' => 'application/hal+json, application/json;charset=utf-8',
          'Content-Type' => 'application/json;charset=utf-8',
          'V-C-Merchant-Id' => @options[:merchant_id],
          'Date' => date,
          'Host' => host,
          'Signature' => get_http_signature(action, digest, http_method, date),
          'Digest' => digest
        }
      end

      def add_business_rules_data(post, payment, options)
        post[:processingInformation][:authorizationOptions] = {}
        unless payment.is_a?(NetworkTokenizationCreditCard)
          post[:processingInformation][:authorizationOptions][:ignoreAvsResult] = 'true' if options[:ignore_avs].to_s == 'true'
          post[:processingInformation][:authorizationOptions][:ignoreCvResult] = 'true' if options[:ignore_cvv].to_s == 'true'
        end
      end

      def add_mdd_fields(post, options)
        mdd_fields = options.select { |k, v| k.to_s.start_with?('mdd_field') && v.present? }
        return unless mdd_fields.present?

        post[:merchantDefinedInformation] = mdd_fields.map do |key, value|
          { key: key, value: value }
        end
      end

      def add_reconciliation_id(post, options)
        return unless options[:reconciliation_id].present?

        post[:clientReferenceInformation][:reconciliationId] = options[:reconciliation_id]
      end

      def add_sec_code(post, options)
        return unless options[:sec_code].present?

        post[:processingInformation][:bankTransferOptions] = { secCode: options[:sec_code] }
      end

      def add_invoice_number(post, options)
        return unless options[:invoice_number].present?

        post[:orderInformation][:invoiceDetails] = { invoiceNumber: options[:invoice_number] }
      end

      def add_partner_solution_id(post)
        return unless application_id

        post[:clientReferenceInformation][:partner] = { solutionId: application_id }
      end
    end
  end
end
