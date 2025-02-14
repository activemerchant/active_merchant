require 'active_merchant/billing/gateways/cyber_source/cyber_source_common'

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class CyberSourceRestGateway < Gateway
      include ActiveMerchant::Billing::CyberSourceCommon

      self.test_url = 'https://apitest.cybersource.com'
      self.live_url = 'https://api.cybersource.com'

      self.supported_countries = ActiveMerchant::Billing::CyberSourceGateway.supported_countries
      self.default_currency = 'USD'
      self.currencies_without_fractions = ActiveMerchant::Billing::CyberSourceGateway.currencies_without_fractions

      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb maestro elo union_pay cartes_bancaires mada patagonia_365 tarjeta_sol]

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
        visa: '001',
        carnet: '002'
      }

      WALLET_PAYMENT_SOLUTION = {
        apple_pay: '001',
        google_pay: '012'
      }

      NT_PAYMENT_SOLUTION = {
        'master' => '014',
        'visa' => '015'
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
        post = build_void_request(options, amount)
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
          gsub(/(\\?"cryptogram\\?":\\?")[^<]+/, '\1[FILTERED]').
          gsub(/(signature=")[^"]*/, '\1[FILTERED]').
          gsub(/(keyid=")[^"]*/, '\1[FILTERED]').
          gsub(/(Digest: SHA-256=)[\w\/\+=]*/, '\1[FILTERED]')
      end

      private

      def add_level_2_data(post, options)
        return unless options[:purchase_order_number]

        post[:orderInformation][:invoiceDetails] ||= {}
        post[:orderInformation][:invoiceDetails][:purchaseOrderNumber] = options[:purchase_order_number]
      end

      def add_level_3_data(post, options)
        return unless options[:line_items]

        post[:orderInformation][:lineItems] = options[:line_items]
        post[:processingInformation][:purchaseLevel] = '3'
        post[:orderInformation][:shipping_details] = { shipFromPostalCode: options[:ships_from_postal_code] }
        post[:orderInformation][:amountDetails] ||= {}
        post[:orderInformation][:amountDetails][:discountAmount] = options[:discount_amount]
      end

      def add_three_ds(post, payment_method, options)
        return unless three_d_secure = options[:three_d_secure]

        post[:consumerAuthenticationInformation] ||= {}
        if payment_method.brand == 'master'
          post[:consumerAuthenticationInformation][:ucafAuthenticationData] = three_d_secure[:cavv]
          post[:consumerAuthenticationInformation][:ucafCollectionIndicator] = '2'
        else
          post[:consumerAuthenticationInformation][:cavv] = three_d_secure[:cavv]
        end
        post[:consumerAuthenticationInformation][:cavvAlgorithm] = three_d_secure[:cavv_algorithm] if three_d_secure[:cavv_algorithm]
        post[:consumerAuthenticationInformation][:paSpecificationVersion] = three_d_secure[:version] if three_d_secure[:version]
        post[:consumerAuthenticationInformation][:directoryServerTransactionID] = three_d_secure[:ds_transaction_id] if three_d_secure[:ds_transaction_id]
        post[:consumerAuthenticationInformation][:eciRaw] = three_d_secure[:eci] if three_d_secure[:eci]
        if three_d_secure[:xid].present?
          post[:consumerAuthenticationInformation][:xid] = three_d_secure[:xid]
        else
          post[:consumerAuthenticationInformation][:xid] = three_d_secure[:cavv]
        end
        post[:consumerAuthenticationInformation][:veresEnrolled] = three_d_secure[:enrolled] if three_d_secure[:enrolled]
        post[:consumerAuthenticationInformation][:paresStatus] = three_d_secure[:authentication_response_status] if three_d_secure[:authentication_response_status]
        post
      end

      def build_void_request(options, amount = nil)
        { reversalInformation: { amountDetails: { totalAmount: nil } } }.tap do |post|
          add_reversal_amount(post, amount.to_i) if amount.present?
          add_merchant_category_code(post, options)
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
          add_merchant_category_code(post, options)
          add_partner_solution_id(post)
          add_stored_credentials(post, payment, options)
          add_three_ds(post, payment, options)
          add_level_2_data(post, options)
          add_level_3_data(post, options)
        end.compact
      end

      def build_reference_request(amount, options)
        { clientReferenceInformation: {}, orderInformation: {} }.tap do |post|
          add_code(post, options)
          add_mdd_fields(post, options)
          add_amount(post, amount, options)
          add_merchant_category_code(post, options)
          add_partner_solution_id(post)
        end.compact
      end

      def build_credit_request(amount, payment, options)
        { clientReferenceInformation: {}, paymentInformation: {}, orderInformation: {} }.tap do |post|
          add_code(post, options)
          add_credit_card(post, payment)
          add_mdd_fields(post, options)
          add_amount(post, amount, options)
          add_merchant_category_code(post, options)
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

      def add_amount(post, amount, options)
        currency = options[:currency] || currency(amount)
        post[:orderInformation][:amountDetails] = {
          totalAmount: localized_amount(amount, currency),
          currency:
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
        if options.dig(:stored_credential, :initiator) == 'merchant'
          post[:paymentInformation][:tokenizedCard] = {
            number: payment.number,
            expirationMonth: payment.month,
            expirationYear: payment.year,
            type:  CREDIT_CARD_CODES[card_brand(payment).to_sym],
            transactionType: payment.source == :network_token ? '3' : '1'
          }
        else
          post[:paymentInformation][:tokenizedCard] = {
            number: payment.number,
            expirationMonth: payment.month,
            expirationYear: payment.year,
            cryptogram: payment.payment_cryptogram,
            type:  CREDIT_CARD_CODES[card_brand(payment).to_sym],
            transactionType: payment.source == :network_token ? '3' : '1'
          }
          add_apple_pay_google_pay_cryptogram(post, payment) unless payment.source == :network_token
        end

        post[:processingInformation][:commerceIndicator] = 'internet' unless options[:stored_credential] || card_brand(payment) == 'jcb'

        add_payment_solution(post, payment)
      end

      def add_payment_solution(post, payment)
        if payment.source == :network_token && NT_PAYMENT_SOLUTION[payment.brand]
          post[:processingInformation][:paymentSolution] = NT_PAYMENT_SOLUTION[payment.brand]
        else
          post[:processingInformation][:paymentSolution] = WALLET_PAYMENT_SOLUTION[payment.source]
        end
      end

      def add_apple_pay_google_pay_cryptogram(post, payment)
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

      def add_merchant_category_code(post, options)
        return unless options[:merchant_category_code]

        post[:merchantInformation] ||= {}
        post[:merchantInformation][:categoryCode] = options[:merchant_category_code] if options[:merchant_category_code]
      end

      def add_stored_credentials(post, payment, options)
        return unless options[:stored_credential]

        post[:processingInformation][:commerceIndicator] = commerce_indicator(options.dig(:stored_credential, :reason_type))
        add_authorization_options(post, payment, options)
      end

      def commerce_indicator(reason_type)
        case reason_type
        when 'recurring'
          'recurring'
        when 'installment'
          'install'
        else
          'internet'
        end
      end

      def add_authorization_options(post, payment, options)
        initiator = options.dig(:stored_credential, :initiator) == 'cardholder' ? 'customer' : 'merchant'
        authorization_options = {
          authorizationOptions: {
            initiator: {
              type: initiator
            }
          }
        }.compact

        authorization_options[:authorizationOptions][:initiator][:storedCredentialUsed] = true if initiator == 'merchant'
        authorization_options[:authorizationOptions][:initiator][:credentialStoredOnFile] = true if options.dig(:stored_credential, :initial_transaction)
        authorization_options[:authorizationOptions][:initiator][:merchantInitiatedTransaction] ||= {}
        unless options.dig(:stored_credential, :initial_transaction)
          network_transaction_id = options[:network_transaction_id] || options.dig(:stored_credential, :network_transaction_id) || ''
          authorization_options[:authorizationOptions][:initiator][:merchantInitiatedTransaction][:previousTransactionID] = network_transaction_id
          authorization_options[:authorizationOptions][:initiator][:merchantInitiatedTransaction][:originalAuthorizedAmount] = post.dig(:orderInformation, :amountDetails, :totalAmount) if card_brand(payment) == 'discover'
        end
        authorization_options[:authorizationOptions][:initiator][:merchantInitiatedTransaction][:reason] = options[:reason_code] if options[:reason_code]
        post[:processingInformation].merge!(authorization_options)
      end

      def network_transaction_id_from(response)
        response.dig('processorInformation', 'networkTransactionId')
      end

      def url(action)
        "#{test? ? test_url : live_url}/pts/v2/#{action}"
      end

      def host
        URI.parse(url('')).host
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, post, options = {})
        add_reconciliation_id(post, options)
        add_sec_code(post, options)
        add_invoice_number(post, options)
        response = parse(ssl_post(url(action), post.to_json, auth_headers(action, options, post)))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response.dig('processorInformation', 'avs', 'code')),
          # cvv_result: CVVResult.new(response['some_cvv_response_key']),
          network_transaction_id: network_transaction_id_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ActiveMerchant::ResponseError => e
        response = e.response.body.present? ? parse(e.response.body) : { 'response' => { 'rmsg' => e.response.msg } }
        message = response.dig('response', 'rmsg') || response.dig('message')
        Response.new(false, message, response, test: test?)
      end

      def success_from(response)
        %w(AUTHORIZED PENDING REVERSED).include?(response['status'])
      end

      def message_from(response)
        return response['status'] if success_from(response)

        response.dig('errorInformation', 'message') || response['message']
      end

      def authorization_from(response)
        id = response['id']
        amount = response.dig('orderInformation', 'amountDetails', 'authorizedAmount')&.delete('.')

        amount.present? ? [id, amount].join('|') : id
      end

      def error_code_from(response)
        response.dig('errorInformation', 'reason') unless success_from(response)
      end

      # This implementation follows the Cybersource guide on how create the request signature, see:
      # https://developer.cybersource.com/docs/cybs/en-us/payments/developer/all/rest/payments/GenerateHeader/httpSignatureAuthentication.html
      def get_http_signature(resource, digest, http_method = 'post', gmtdatetime = Time.now.httpdate)
        string_to_sign = {
          host:,
          date: gmtdatetime,
          'request-target': "#{http_method} /pts/v2/#{resource}",
          digest:,
          'v-c-merchant-id': @options[:merchant_id]
        }.map { |k, v| "#{k}: #{v}" }.join("\n").force_encoding(Encoding::UTF_8)

        {
          keyid: @options[:public_key],
          algorithm: 'HmacSHA256',
          headers: "host date request-target#{digest.present? ? ' digest' : ''} v-c-merchant-id",
          signature: sign_payload(string_to_sign)
        }.map { |k, v| %{#{k}="#{v}"} }.join(', ')
      end

      def sign_payload(payload)
        decoded_key = Base64.decode64(@options[:private_key])
        Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', decoded_key, payload))
      end

      def auth_headers(action, options, post, http_method = 'post')
        digest = "SHA-256=#{Digest::SHA256.base64digest(post.to_json)}" if post.present?
        date = Time.now.httpdate

        {
          'Accept' => 'application/hal+json;charset=utf-8',
          'Content-Type' => 'application/json;charset=utf-8',
          'V-C-Merchant-Id' => options[:merchant_id] || @options[:merchant_id],
          'Date' => date,
          'Host' => host,
          'Signature' => get_http_signature(action, digest, http_method, date),
          'Digest' => digest
        }
      end

      def add_business_rules_data(post, payment, options)
        post[:processingInformation][:authorizationOptions] = {}
        post[:processingInformation][:authorizationOptions][:ignoreAvsResult] = 'true' if options[:ignore_avs].to_s == 'true'
        post[:processingInformation][:authorizationOptions][:ignoreCvResult] = 'true' if options[:ignore_cvv].to_s == 'true'
      end

      def add_mdd_fields(post, options)
        mdd_fields = options.select { |k, v| k.to_s.start_with?('mdd_field') && v.present? }
        return unless mdd_fields.present?

        post[:merchantDefinedInformation] = mdd_fields.map do |key, value|
          { key:, value: }
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

        post[:orderInformation][:invoiceDetails] ||= {}
        post[:orderInformation][:invoiceDetails][:invoiceNumber] = options[:invoice_number]
      end

      def add_partner_solution_id(post)
        return unless application_id

        post[:clientReferenceInformation][:partner] = { solutionId: application_id }
      end
    end
  end
end
