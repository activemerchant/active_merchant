module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AdyenGateway < Gateway
      # we recommend setting up merchant-specific endpoints.
      # https://docs.adyen.com/developers/api-manual#apiendpoints
      self.test_url = 'https://pal-test.adyen.com/pal/servlet/'
      self.live_url = 'https://pal-live.adyen.com/pal/servlet/'

      self.supported_countries = %w(AT AU BE BG BR CH CY CZ DE DK EE ES FI FR GB GI GR HK HU IE IS IT LI LT LU LV MC MT MX NL NO PL PT RO SE SG SK SI US)
      self.default_currency = 'USD'
      self.currencies_without_fractions = %w(CVE DJF GNF IDR JPY KMF KRW PYG RWF UGX VND VUV XAF XOF XPF)
      self.currencies_with_three_decimal_places = %w(BHD IQD JOD KWD LYD OMR TND)
      self.supported_cardtypes = %i[visa master american_express diners_club jcb dankort maestro discover elo naranja cabal unionpay]

      self.money_format = :cents

      self.homepage_url = 'https://www.adyen.com/'
      self.display_name = 'Adyen'

      PAYMENT_API_VERSION = 'v68'
      RECURRING_API_VERSION = 'v68'

      STANDARD_ERROR_CODE_MAPPING = {
        '0' => STANDARD_ERROR_CODE[:processing_error],
        '10' => STANDARD_ERROR_CODE[:config_error],
        '100' => STANDARD_ERROR_CODE[:invalid_amount],
        '101' => STANDARD_ERROR_CODE[:incorrect_number],
        '103' => STANDARD_ERROR_CODE[:invalid_cvc],
        '104' => STANDARD_ERROR_CODE[:incorrect_address],
        '131' => STANDARD_ERROR_CODE[:incorrect_address],
        '132' => STANDARD_ERROR_CODE[:incorrect_address],
        '133' => STANDARD_ERROR_CODE[:incorrect_address],
        '134' => STANDARD_ERROR_CODE[:incorrect_address],
        '135' => STANDARD_ERROR_CODE[:incorrect_address]
      }

      def initialize(options = {})
        requires!(options, :username, :password, :merchant_account)
        @username, @password, @merchant_account = options.values_at(:username, :password, :merchant_account)
        super
      end

      def purchase(money, payment, options = {})
        if options[:execute_threed] || options[:threed_dynamic]
          authorize(money, payment, options)
        else
          MultiResponse.run do |r|
            r.process { authorize(money, payment, options) }
            r.process { capture(money, r.authorization, capture_options(options)) }
          end
        end
      end

      def authorize(money, payment, options = {})
        requires!(options, :order_id)
        post = init_post(options)
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_extra_data(post, payment, options)
        add_stored_credentials(post, payment, options)
        add_address(post, options)
        add_installments(post, options) if options[:installments]
        add_3ds(post, options)
        add_3ds_authenticated_data(post, options)
        add_splits(post, options)
        add_recurring_contract(post, options)
        add_network_transaction_reference(post, options)
        add_application_info(post, options)
        add_level_2_data(post, options)
        add_level_3_data(post, options)
        commit('authorise', post, options)
      end

      def capture(money, authorization, options = {})
        post = init_post(options)
        add_invoice_for_modification(post, money, options)
        add_reference(post, authorization, options)
        add_splits(post, options)
        add_network_transaction_reference(post, options)
        add_shopper_statement(post, options)
        commit('capture', post, options)
      end

      def refund(money, authorization, options = {})
        post = init_post(options)
        add_invoice_for_modification(post, money, options)
        add_reference(post, authorization, options)
        add_splits(post, options)
        add_network_transaction_reference(post, options)
        commit('refund', post, options)
      end

      def credit(money, payment, options = {})
        action = 'refundWithData'
        post = init_post(options)
        add_invoice(post, money, options)
        add_payment(post, payment, options, action)
        add_shopper_reference(post, options)
        add_network_transaction_reference(post, options)
        commit(action, post, options)
      end

      def void(authorization, options = {})
        post = init_post(options)
        endpoint = options[:cancel_or_refund] ? 'cancelOrRefund' : 'cancel'
        add_reference(post, authorization, options)
        add_network_transaction_reference(post, options)
        commit(endpoint, post, options)
      end

      def adjust(money, authorization, options = {})
        post = init_post(options)
        add_invoice_for_modification(post, money, options)
        add_reference(post, authorization, options)
        add_extra_data(post, nil, options)
        commit('adjustAuthorisation', post, options)
      end

      def store(credit_card, options = {})
        requires!(options, :order_id)
        post = init_post(options)
        add_invoice(post, 0, options)
        add_payment(post, credit_card, options)
        add_extra_data(post, credit_card, options)
        add_stored_credentials(post, credit_card, options)
        add_address(post, options)
        add_network_transaction_reference(post, options)
        options[:recurring_contract_type] ||= 'RECURRING'
        add_recurring_contract(post, options)

        action = options[:tokenize_only] ? 'storeToken' : 'authorise'

        initial_response = commit(action, post, options)

        if initial_response.success? && card_not_stored?(initial_response)
          unsupported_failure_response(initial_response)
        else
          initial_response
        end
      end

      def unstore(options = {})
        requires!(options, :shopper_reference, :recurring_detail_reference)
        post = {}

        add_shopper_reference(post, options)
        add_merchant_account(post, options)
        post[:recurringDetailReference] = options[:recurring_detail_reference]

        commit('disable', post, options)
      end

      def verify(credit_card, options = {})
        amount = options[:verify_amount]&.to_i || 0
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, credit_card, options) }
          options[:idempotency_key] = nil
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def supports_network_tokenization?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("number\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvc\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cavv\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("bankLocationId\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("iban\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("bankAccountNumber\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      AVS_MAPPING = {
        '0'  => 'R',  # Unknown
        '1'  => 'A',  # Address matches, postal code doesn't
        '2'  => 'N',  # Neither postal code nor address match
        '3'  => 'R',  # AVS unavailable
        '4'  => 'E',  # AVS not supported for this card type
        '5'  => 'U',  # No AVS data provided
        '6'  => 'Z',  # Postal code matches, address doesn't match
        '7'  => 'D',  # Both postal code and address match
        '8'  => 'U',  # Address not checked, postal code unknown
        '9'  => 'B',  # Address matches, postal code unknown
        '10' => 'N',  # Address doesn't match, postal code unknown
        '11' => 'U',  # Postal code not checked, address unknown
        '12' => 'B',  # Address matches, postal code not checked
        '13' => 'U',  # Address doesn't match, postal code not checked
        '14' => 'P',  # Postal code matches, address unknown
        '15' => 'P',  # Postal code matches, address not checked
        '16' => 'N',  # Postal code doesn't match, address unknown
        '17' => 'U',  # Postal code doesn't match, address not checked
        '18' => 'I',  # Neither postal code nor address were checked
        '19' => 'L',  # Name and postal code matches.
        '20' => 'V',  # Name, address and postal code matches.
        '21' => 'O',  # Name and address matches.
        '22' => 'K',  # Name matches.
        '23' => 'F',  # Postal code matches, name doesn't match.
        '24' => 'H',  # Both postal code and address matches, name doesn't match.
        '25' => 'T',  # Address matches, name doesn't match.
        '26' => 'N'   # Neither postal code, address nor name matches.
      }

      CVC_MAPPING = {
        '0' => 'P', # Unknown
        '1' => 'M', # Matches
        '2' => 'N', # Does not match
        '3' => 'P', # Not checked
        '4' => 'S', # No CVC/CVV provided, but was required
        '5' => 'U', # Issuer not certifed by CVC/CVV
        '6' => 'P'  # No CVC/CVV provided
      }

      NETWORK_TOKENIZATION_CARD_SOURCE = {
        'apple_pay' => 'applepay',
        'android_pay' => 'androidpay',
        'google_pay' => 'paywithgoogle'
      }

      def add_extra_data(post, payment, options)
        post[:telephoneNumber] = (options[:billing_address][:phone_number] if options.dig(:billing_address, :phone_number)) || (options[:billing_address][:phone] if options.dig(:billing_address, :phone)) || ''
        post[:fraudOffset] = options[:fraud_offset] if options[:fraud_offset]
        post[:selectedBrand] = options[:selected_brand] if options[:selected_brand]
        post[:selectedBrand] ||= NETWORK_TOKENIZATION_CARD_SOURCE[payment.source.to_s] if payment.is_a?(NetworkTokenizationCreditCard)
        post[:deliveryDate] = options[:delivery_date] if options[:delivery_date]
        post[:merchantOrderReference] = options[:merchant_order_reference] if options[:merchant_order_reference]
        post[:captureDelayHours] = options[:capture_delay_hours] if options[:capture_delay_hours]
        post[:additionalData] ||= {}
        post[:additionalData][:overwriteBrand] = normalize(options[:overwrite_brand]) if options[:overwrite_brand]
        post[:additionalData][:customRoutingFlag] = options[:custom_routing_flag] if options[:custom_routing_flag]
        post[:additionalData]['paymentdatasource.type'] = NETWORK_TOKENIZATION_CARD_SOURCE[payment.source.to_s] if payment.is_a?(NetworkTokenizationCreditCard)
        post[:additionalData][:authorisationType] = options[:authorisation_type] if options[:authorisation_type]
        post[:additionalData][:adjustAuthorisationData] = options[:adjust_authorisation_data] if options[:adjust_authorisation_data]
        post[:additionalData][:industryUsage] = options[:industry_usage] if options[:industry_usage]
        post[:additionalData][:RequestedTestAcquirerResponseCode] = options[:requested_test_acquirer_response_code] if options[:requested_test_acquirer_response_code] && test?
        post[:deviceFingerprint] = options[:device_fingerprint] if options[:device_fingerprint]
        add_shopper_data(post, options)
        add_risk_data(post, options)
        add_shopper_reference(post, options)
        add_merchant_data(post, options)
      end

      def extract_and_transform(mapper, from)
        mapper.each_with_object({}) do |key_map, hsh|
          key, item_key = key_map[0], key_map[1]
          hsh[key] = from[item_key.to_sym]
        end
      end

      def add_level_2_data(post, options)
        return unless options[:level_2_data].present?

        mapper = {
          "enhancedSchemeData.totalTaxAmount": 'total_tax_amount',
          "enhancedSchemeData.customerReference": 'customer_reference'
        }
        post[:additionalData].merge!(extract_and_transform(mapper, options[:level_2_data]))
      end

      def add_level_3_data(post, options)
        return unless options[:level_3_data].present?

        mapper = { "enhancedSchemeData.freightAmount": 'freight_amount',
          "enhancedSchemeData.destinationStateProvinceCode": 'destination_state_province_code',
          "enhancedSchemeData.shipFromPostalCode": 'ship_from_postal_code',
          "enhancedSchemeData.orderDate": 'order_date',
          "enhancedSchemeData.destinationPostalCode": 'destination_postal_code',
          "enhancedSchemeData.destinationCountryCode": 'destination_country_code',
          "enhancedSchemeData.dutyAmount": 'duty_amount' }

        post[:additionalData].merge!(extract_and_transform(mapper, options[:level_3_data]))

        item_detail_keys = %w[description product_code quantity unit_of_measure unit_price discount_amount total_amount commodity_code]
        if options[:level_3_data][:items].present?
          options[:level_3_data][:items].last(9).each.with_index(1) do |item, index|
            mapper = item_detail_keys.each_with_object({}) do |key, hsh|
              hsh["enhancedSchemeData.itemDetailLine#{index}.#{key.camelize(:lower)}"] = key
            end
            post[:additionalData].merge!(extract_and_transform(mapper, item))
          end
        end
        post[:additionalData].compact!
      end

      def add_shopper_data(post, options)
        post[:shopperEmail] = options[:email] if options[:email]
        post[:shopperEmail] = options[:shopper_email] if options[:shopper_email]
        post[:shopperIP] = options[:ip] if options[:ip]
        post[:shopperIP] = options[:shopper_ip] if options[:shopper_ip]
        post[:shopperStatement] = options[:shopper_statement] if options[:shopper_statement]
        post[:additionalData][:updateShopperStatement] = options[:update_shopper_statement] if options[:update_shopper_statement]
      end

      def add_shopper_statement(post, options)
        return unless options[:shopper_statement]

        post[:additionalData] = {
          shopperStatement: options[:shopper_statement]
        }
      end

      def add_merchant_data(post, options)
        post[:additionalData][:subMerchantID] = options[:sub_merchant_id] if options[:sub_merchant_id]
        post[:additionalData][:subMerchantName] = options[:sub_merchant_name] if options[:sub_merchant_name]
        post[:additionalData][:subMerchantStreet] = options[:sub_merchant_street] if options[:sub_merchant_street]
        post[:additionalData][:subMerchantCity] = options[:sub_merchant_city] if options[:sub_merchant_city]
        post[:additionalData][:subMerchantState] = options[:sub_merchant_state] if options[:sub_merchant_state]
        post[:additionalData][:subMerchantPostalCode] = options[:sub_merchant_postal_code] if options[:sub_merchant_postal_code]
        post[:additionalData][:subMerchantCountry] = options[:sub_merchant_country] if options[:sub_merchant_country]
        post[:additionalData][:subMerchantTaxId] = options[:sub_merchant_tax_id] if options[:sub_merchant_tax_id]
        post[:additionalData][:subMerchantMCC] = options[:sub_merchant_mcc] if options[:sub_merchant_mcc]
        post[:additionalData] = post[:additionalData].merge(options[:sub_merchant_data]) if options[:sub_merchant_data]
      end

      def add_risk_data(post, options)
        if (risk_data = options[:risk_data])
          risk_data = Hash[risk_data.map { |k, v| ["riskdata.#{k}", v] }]
          post[:additionalData].merge!(risk_data)
        end
      end

      def add_splits(post, options)
        return unless split_data = options[:splits]

        splits = []
        split_data.each do |split|
          amount = {
            value: split['amount']['value']
          }
          amount[:currency] = split['amount']['currency'] if split['amount']['currency']

          split_hash = {
            amount: amount,
            type: split['type'],
            reference: split['reference']
          }
          split_hash['account'] = split['account'] if split['account']
          splits.push(split_hash)
        end
        post[:splits] = splits
      end

      def add_stored_credentials(post, payment, options)
        add_shopper_interaction(post, payment, options)
        add_recurring_processing_model(post, options)
      end

      def add_merchant_account(post, options)
        post[:merchantAccount] = options[:merchant_account] || @merchant_account
      end

      def add_shopper_reference(post, options)
        post[:shopperReference] = options[:shopper_reference] if options[:shopper_reference]
      end

      def add_shopper_interaction(post, payment, options = {})
        if  (options.dig(:stored_credential, :initial_transaction) && options.dig(:stored_credential, :initiator) == 'cardholder') ||
            (payment.respond_to?(:verification_value) && payment.verification_value && options.dig(:stored_credential, :initial_transaction).nil?) ||
            payment.is_a?(NetworkTokenizationCreditCard)
          shopper_interaction = 'Ecommerce'
        else
          shopper_interaction = 'ContAuth'
        end

        post[:shopperInteraction] = options[:shopper_interaction] || shopper_interaction
      end

      def add_recurring_processing_model(post, options)
        return unless options.dig(:stored_credential, :reason_type) || options[:recurring_processing_model]

        if options.dig(:stored_credential, :reason_type) == 'unscheduled'
          if options.dig(:stored_credential, :initiator) == 'merchant'
            recurring_processing_model = 'UnscheduledCardOnFile'
          else
            recurring_processing_model = 'CardOnFile'
          end
        else
          recurring_processing_model = 'Subscription'
        end

        post[:recurringProcessingModel] = options[:recurring_processing_model] || recurring_processing_model
      end

      def add_address(post, options)
        if address = options[:shipping_address]
          post[:deliveryAddress] = {}
          post[:deliveryAddress][:street] = address[:address1] || 'NA'
          post[:deliveryAddress][:houseNumberOrName] = address[:address2] || 'NA'
          post[:deliveryAddress][:postalCode] = address[:zip] if address[:zip]
          post[:deliveryAddress][:city] = address[:city] || 'NA'
          post[:deliveryAddress][:stateOrProvince] = get_state(address)
          post[:deliveryAddress][:country] = address[:country] if address[:country]
        end
        return unless post[:bankAccount]&.kind_of?(Hash) || post[:card]&.kind_of?(Hash)

        if (address = options[:billing_address] || options[:address]) && address[:country]
          post[:billingAddress] = {}
          post[:billingAddress][:street] = address[:address1] || 'NA'
          post[:billingAddress][:houseNumberOrName] = address[:address2] || 'NA'
          post[:billingAddress][:postalCode] = address[:zip] if address[:zip]
          post[:billingAddress][:city] = address[:city] || 'NA'
          post[:billingAddress][:stateOrProvince] = get_state(address)
          post[:billingAddress][:country] = address[:country] if address[:country]
        end
      end

      def get_state(address)
        address[:state] && !address[:state].blank? ? address[:state] : 'NA'
      end

      def add_invoice(post, money, options)
        currency = options[:currency] || currency(money)
        amount = {
          value: localized_amount(money, currency),
          currency: currency
        }

        post[:amount] = amount
      end

      def add_invoice_for_modification(post, money, options)
        currency = options[:currency] || currency(money)
        amount = {
          value: localized_amount(money, currency),
          currency: currency
        }
        post[:modificationAmount] = amount
      end

      def add_payment(post, payment, options, action = nil)
        if payment.is_a?(String)
          _, _, recurring_detail_reference = payment.split('#')
          post[:selectedRecurringDetailReference] = recurring_detail_reference
          options[:recurring_contract_type] ||= 'RECURRING'
        elsif payment.is_a?(Check)
          add_bank_account(post, payment, options, action)
        else
          add_mpi_data_for_network_tokenization_card(post, payment, options) if payment.is_a?(NetworkTokenizationCreditCard)
          add_card(post, payment)
        end
      end

      def add_bank_account(post, bank_account, options, action)
        bank = {
          bankAccountNumber: bank_account.account_number,
          ownerName: bank_account.name,
          countryCode: options[:billing_address].try(:[], :country)
        }

        action == 'refundWithData' ? bank[:iban] = bank_account.routing_number : bank[:bankLocationId] = bank_account.routing_number

        requires!(bank, :bankAccountNumber, :ownerName, :countryCode)
        post[:bankAccount] = bank
      end

      def add_card(post, credit_card)
        card = {
          expiryMonth: credit_card.month,
          expiryYear: credit_card.year,
          holderName: credit_card.name,
          number: credit_card.number,
          cvc: credit_card.verification_value
        }

        card.delete_if { |_k, v| v.blank? }
        card[:holderName] ||= 'Not Provided'
        requires!(card, :expiryMonth, :expiryYear, :holderName, :number)
        post[:card] = card
      end

      def capture_options(options)
        return options.merge(idempotency_key: "#{options[:idempotency_key]}-cap") if options[:idempotency_key]

        options
      end

      def add_network_transaction_reference(post, options)
        return unless ntid = options[:network_transaction_id] || options.dig(:stored_credential, :network_transaction_id)

        post[:additionalData] = {} unless post[:additionalData]
        post[:additionalData][:networkTxReference] = ntid
      end

      def add_reference(post, authorization, options = {})
        original_reference = authorization.split('#').reject(&:empty?).first
        post[:originalReference] = original_reference
      end

      def add_mpi_data_for_network_tokenization_card(post, payment, options)
        return if options[:skip_mpi_data] == 'Y'

        post[:mpiData] = {}
        post[:mpiData][:authenticationResponse] = 'Y'
        post[:mpiData][:cavv] = payment.payment_cryptogram
        post[:mpiData][:directoryResponse] = 'Y'
        post[:mpiData][:eci] = payment.eci || '07'
      end

      def add_recurring_contract(post, options = {})
        return unless options[:recurring_contract_type]

        recurring = {
          contract: options[:recurring_contract_type]
        }

        post[:recurring] = recurring
      end

      def add_application_info(post, options)
        post[:applicationInfo] ||= {}
        add_external_platform(post, options)
        add_merchant_application(post, options)
      end

      def add_external_platform(post, options)
        options.update(externalPlatform: application_id) if application_id

        return unless options[:externalPlatform]

        post[:applicationInfo][:externalPlatform] = {
          name: options[:externalPlatform][:name],
          version: options[:externalPlatform][:version]
        }
      end

      def add_merchant_application(post, options)
        return unless options[:merchantApplication]

        post[:applicationInfo][:merchantApplication] = {
          name: options[:merchantApplication][:name],
          version: options[:merchantApplication][:version]
        }
      end

      def add_installments(post, options)
        post[:installments] = {
          value: options[:installments]
        }
      end

      def add_3ds(post, options)
        if three_ds_2_options = options[:three_ds_2]
          device_channel = three_ds_2_options[:channel]
          if device_channel == 'app'
            post[:threeDS2RequestData] = { deviceChannel: device_channel }
          else
            add_browser_info(three_ds_2_options[:browser_info], post)
            post[:threeDS2RequestData] = { deviceChannel: device_channel, notificationURL: three_ds_2_options[:notification_url] }
          end

          if options.has_key?(:execute_threed)
            post[:additionalData][:executeThreeD] = options[:execute_threed]
            post[:additionalData][:scaExemption] = options[:sca_exemption] if options[:sca_exemption]
          end
        else
          return unless !options[:execute_threed].nil? || !options[:threed_dynamic].nil?

          post[:browserInfo] = { userAgent: options[:user_agent], acceptHeader: options[:accept_header] } if options[:execute_threed] || options[:threed_dynamic]
          post[:additionalData] ||= {}
          post[:additionalData][:executeThreeD] = options[:execute_threed] if !options[:execute_threed].nil?
        end
      end

      def add_3ds_authenticated_data(post, options)
        if options[:three_d_secure] && options[:three_d_secure][:eci] && options[:three_d_secure][:xid]
          add_3ds1_authenticated_data(post, options)
        elsif options[:three_d_secure]
          add_3ds2_authenticated_data(post, options)
        end
      end

      def add_3ds1_authenticated_data(post, options)
        three_d_secure_options = options[:three_d_secure]
        post[:mpiData] = {
          cavv: three_d_secure_options[:cavv],
          cavvAlgorithm: three_d_secure_options[:cavv_algorithm],
          eci: three_d_secure_options[:eci],
          xid: three_d_secure_options[:xid],
          directoryResponse: three_d_secure_options[:enrolled],
          authenticationResponse: three_d_secure_options[:authentication_response_status]
        }
      end

      def add_3ds2_authenticated_data(post, options)
        three_d_secure_options = options[:three_d_secure]
        # If the transaction was authenticated in a frictionless flow, send the transStatus from the ARes.
        if three_d_secure_options[:authentication_response_status].nil?
          authentication_response = three_d_secure_options[:directory_response_status]
        else
          authentication_response = three_d_secure_options[:authentication_response_status]
        end
        post[:mpiData] = {
          threeDSVersion: three_d_secure_options[:version],
          eci: three_d_secure_options[:eci],
          cavv: three_d_secure_options[:cavv],
          dsTransID: three_d_secure_options[:ds_transaction_id],
          directoryResponse: three_d_secure_options[:directory_response_status],
          authenticationResponse: authentication_response
        }
      end

      def parse(body)
        return {} if body.blank?

        JSON.parse(body)
      end

      def commit(action, parameters, options)
        begin
          raw_response = ssl_post(url(action), post_data(action, parameters), request_headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end

        success = success_from(action, response, options)
        Response.new(
          success,
          message_from(action, response),
          response,
          authorization: authorization_from(action, parameters, response),
          test: test?,
          error_code: success ? nil : error_code_from(response),
          network_transaction_id: network_transaction_id_from(response),
          avs_result: AVSResult.new(code: avs_code_from(response)),
          cvv_result: CVVResult.new(cvv_result_from(response))
        )
      end

      def avs_code_from(response)
        AVS_MAPPING[response['additionalData']['avsResult'][0..1].strip] if response.dig('additionalData', 'avsResult')
      end

      def cvv_result_from(response)
        CVC_MAPPING[response['additionalData']['cvcResult'][0]] if response.dig('additionalData', 'cvcResult')
      end

      def endpoint(action)
        recurring = %w(disable storeToken).include?(action)
        recurring ? "Recurring/#{RECURRING_API_VERSION}/#{action}" : "Payment/#{PAYMENT_API_VERSION}/#{action}"
      end

      def url(action)
        if test?
          "#{test_url}#{endpoint(action)}"
        elsif @options[:subdomain]
          "https://#{@options[:subdomain]}-pal-live.adyenpayments.com/pal/servlet/#{endpoint(action)}"
        else
          "#{live_url}#{endpoint(action)}"
        end
      end

      def basic_auth
        Base64.strict_encode64("#{@username}:#{@password}")
      end

      def request_headers(options)
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
        headers['Idempotency-Key'] = options[:idempotency_key] if options[:idempotency_key]
        headers
      end

      def success_from(action, response, options)
        if %w[RedirectShopper ChallengeShopper].include?(response.dig('resultCode')) && !options[:execute_threed] && !options[:threed_dynamic]
          response['refusalReason'] = 'Received unexpected 3DS authentication response, but a 3DS initiation flag was not included in the request.'
          return false
        end
        case action.to_s
        when 'authorise', 'authorise3d'
          %w[Authorised Received RedirectShopper].include?(response['resultCode'])
        when 'capture', 'refund', 'cancel', 'cancelOrRefund'
          response['response'] == "[#{action}-received]"
        when 'adjustAuthorisation'
          response['response'] == 'Authorised' || response['response'] == '[adjustAuthorisation-received]'
        when 'storeToken'
          response['result'] == 'Success'
        when 'disable'
          response['response'] == '[detail-successfully-disabled]'
        when 'refundWithData'
          response['resultCode'] == 'Received'
        else
          false
        end
      end

      def message_from(action, response)
        return authorize_message_from(response) if %w(authorise authorise3d authorise3ds2).include?(action.to_s)

        response['response'] || response['message'] || response['result'] || response['resultCode']
      end

      def authorize_message_from(response)
        if response['refusalReason'] && response['additionalData'] && response['additionalData']['refusalReasonRaw']
          "#{response['refusalReason']} | #{response['additionalData']['refusalReasonRaw']}"
        else
          response['refusalReason'] || response['resultCode'] || response['message'] || response['result']
        end
      end

      def authorization_from(action, parameters, response)
        return nil if response['pspReference'].nil?

        recurring = response['additionalData']['recurring.recurringDetailReference'] if response['additionalData']
        recurring = response['recurringDetailReference'] if action == 'storeToken'

        "#{parameters[:originalReference]}##{response['pspReference']}##{recurring}"
      end

      def init_post(options = {})
        post = {}
        add_merchant_account(post, options)
        post[:reference] = options[:order_id][0..79] if options[:order_id]
        post
      end

      def post_data(action, parameters = {})
        JSON.generate(parameters)
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['errorCode']] || response['errorCode']
      end

      def network_transaction_id_from(response)
        response.dig('additionalData', 'networkTxReference')
      end

      def add_browser_info(browser_info, post)
        return unless browser_info

        post[:browserInfo] = {
          acceptHeader: browser_info[:accept_header],
          colorDepth: browser_info[:depth],
          javaEnabled: browser_info[:java],
          language: browser_info[:language],
          screenHeight: browser_info[:height],
          screenWidth: browser_info[:width],
          timeZoneOffset: browser_info[:timezone],
          userAgent: browser_info[:user_agent]
        }
      end

      def unsupported_failure_response(initial_response)
        Response.new(
          false,
          'Recurring transactions are not supported for this card type.',
          initial_response.params,
          authorization: initial_response.authorization,
          test: initial_response.test,
          error_code: initial_response.error_code,
          avs_result: initial_response.avs_result,
          cvv_result: initial_response.cvv_result[:code]
        )
      end

      def card_not_stored?(response)
        response.authorization ? response.authorization.split('#')[2].nil? : true
      end
    end
  end
end
