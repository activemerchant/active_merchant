module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Initial setup instructions can be found in
    # http://apps.cybersource.com/library/documentation/dev_guides/SOAP_Toolkits/SOAP_toolkits.pdf
    #
    # Important Notes
    # * For checks you can purchase and store.
    # * AVS and CVV only work against the production server.  You will always
    #   get back X for AVS and no response for CVV against the test server.
    # * Nexus is the list of states or provinces where you have a physical
    #   presence.  Nexus is used to calculate tax.  Leave blank to tax everyone.
    # * If you want to calculate VAT for overseas customers you must supply a
    #   registration number in the options hash as vat_reg_number.
    # * productCode is a value in the line_items hash that is used to tell
    #   CyberSource what kind of item you are selling.  It is used when
    #   calculating tax/VAT.
    # * All transactions use dollar values.
    # * The order of the XML elements does matter, make sure to follow the order in
    #   the documentation exactly.
    class CyberSourceGateway < Gateway
      self.test_url = 'https://ics2wstesta.ic3.com/commerce/1.x/transactionProcessor'
      self.live_url = 'https://ics2wsa.ic3.com/commerce/1.x/transactionProcessor'

      # Schema files can be found here: https://ics2ws.ic3.com/commerce/1.x/transactionProcessor/
      TEST_XSD_VERSION = '1.201'
      PRODUCTION_XSD_VERSION = '1.201'
      ECI_BRAND_MAPPING = {
        visa: 'vbv',
        master: 'spa',
        maestro: 'spa',
        american_express: 'aesk',
        jcb: 'js',
        discover: 'pb',
        diners_club: 'pb'
      }.freeze
      THREEDS_EXEMPTIONS = {
        authentication_outage: 'authenticationOutageExemptionIndicator',
        corporate_card: 'secureCorporatePaymentIndicator',
        delegated_authentication: 'delegatedAuthenticationExemptionIndicator',
        low_risk: 'riskAnalysisExemptionIndicator',
        low_value: 'lowValueExemptionIndicator',
        stored_credential: 'stored_credential',
        trusted_merchant: 'trustedMerchantExemptionIndicator'
      }
      DEFAULT_COLLECTION_INDICATOR = 2

      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb dankort maestro elo]
      self.supported_countries = %w(US AE BR CA CN DK FI FR DE IN JP MX NO SE GB SG LB PK)

      self.default_currency = 'USD'
      self.currencies_without_fractions = %w(JPY)

      self.homepage_url = 'http://www.cybersource.com'
      self.display_name = 'CyberSource'

      @@credit_card_codes = {
        visa: '001',
        master: '002',
        american_express: '003',
        discover: '004',
        diners_club: '005',
        jcb: '007',
        dankort: '034',
        maestro: '042',
        elo: '054'
      }

      @@decision_codes = {
        accept: 'ACCEPT',
        review: 'REVIEW'
      }

      @@response_codes = {
        r100: 'Successful transaction',
        r101: 'Request is missing one or more required fields',
        r102: 'One or more fields contains invalid data',
        r104: 'The merchantReferenceCode sent with this authorization request matches the merchantReferenceCode of another authorization request that you sent in the last 15 minutes.', r110: 'Partial amount was approved',
        r150: 'General failure',
        r151: 'The request was received but a server time-out occurred',
        r152: 'The request was received, but a service timed out',
        r200: 'The authorization request was approved by the issuing bank but declined by CyberSource because it did not pass the AVS check',
        r201: 'The issuing bank has questions about the request',
        r202: 'Expired card',
        r203: 'General decline of the card',
        r204: 'Insufficient funds in the account',
        r205: 'Stolen or lost card',
        r207: 'Issuing bank unavailable',
        r208: 'Inactive card or card not authorized for card-not-present transactions',
        r209: 'American Express Card Identifiction Digits (CID) did not match',
        r210: 'The card has reached the credit limit',
        r211: 'Invalid card verification number',
        r220: 'Generic Decline.',
        r221: "The customer matched an entry on the processor's negative file",
        r222: 'customer\'s account is frozen',
        r230: 'The authorization request was approved by the issuing bank but declined by CyberSource because it did not pass the card verification check',
        r231: 'Invalid account number',
        r232: 'The card type is not accepted by the payment processor',
        r233: 'General decline by the processor',
        r234: 'A problem exists with your CyberSource merchant configuration',
        r235: 'The requested amount exceeds the originally authorized amount',
        r236: 'Processor failure',
        r237: 'The authorization has already been reversed',
        r238: 'The authorization has already been captured',
        r239: 'The requested transaction amount must match the previous transaction amount',
        r240: 'The card type sent is invalid or does not correlate with the credit card number',
        r241: 'The request ID is invalid',
        r242: 'You requested a capture, but there is no corresponding, unused authorization record.',
        r243: 'The transaction has already been settled or reversed',
        r244: 'The bank account number failed the validation check',
        r246: 'The capture or credit is not voidable because the capture or credit information has already been submitted to your processor',
        r247: 'You requested a credit for a capture that was previously voided',
        r248: 'The boleto request was declined by your processor.',
        r250: 'The request was received, but a time-out occurred with the payment processor',
        r251: 'The Pinless Debit card\'s use frequency or maximum amount per use has been exceeded.',
        r254: 'Your CyberSource account is prohibited from processing stand-alone refunds',
        r255: 'Your CyberSource account is not configured to process the service in the country you specified',
        r400: 'Soft Decline - Fraud score exceeds threshold.',
        r450: 'Apartment number missing or not found.',
        r451: 'Insufficient address information.',
        r452: 'House/Box number not found on street.',
        r453: 'Multiple address matches were found.',
        r454: 'P.O. Box identifier not found or out of range.',
        r455: 'Route service identifier not found or out of range.',
        r456: 'Street name not found in Postal code.',
        r457: 'Postal code not found in database.',
        r458: 'Unable to verify or correct address.',
        r459: 'Multiple addres matches were found (international)',
        r460: 'Address match not found (no reason given)',
        r461: 'Unsupported character set',
        r475: 'The cardholder is enrolled in Payer Authentication. Please authenticate the cardholder before continuing with the transaction.',
        r476: 'Encountered a Payer Authentication problem. Payer could not be authenticated.',
        r478: 'Strong customer authentication (SCA) is required for this transaction.',
        r480: 'The order is marked for review by Decision Manager',
        r481: 'The order has been rejected by Decision Manager',
        r490: 'Your aggregator or acquirer is not accepting transactions from you at this time.',
        r491: 'Your aggregator or acquirer is not accepting this transaction.',
        r520: 'Soft Decline - The authorization request was approved by the issuing bank but declined by CyberSource based on your Smart Authorization settings.',
        r700: 'The customer matched the Denied Parties List',
        r701: 'Export bill_country/ship_country match',
        r702: 'Export email_country match',
        r703: 'Export hostname_country/ip_country match'
      }

      @@payment_solution = {
        apple_pay: '001',
        google_pay: '012'
      }

      # These are the options that can be used when creating a new CyberSource
      # Gateway object.
      #
      # :login =>  your username
      #
      # :password =>  the transaction key you generated in the Business Center
      #
      # :test => true   sets the gateway to test mode
      #
      # :vat_reg_number => your VAT registration number
      #
      # :nexus => "WI CA QC" sets the states/provinces where you have a physical
      #           presence for tax purposes
      #
      # :ignore_avs => true   don't want to use AVS so continue processing even
      #                       if AVS would have failed
      #
      # :ignore_cvv => true   don't want to use CVV so continue processing even
      #                       if CVV would have failed
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard_or_reference, options = {})
        setup_address_hash(options)
        commit(build_auth_request(money, creditcard_or_reference, options), :authorize, money, options)
      end

      def capture(money, authorization, options = {})
        setup_address_hash(options)
        commit(build_capture_request(money, authorization, options), :capture, money, options)
      end

      def purchase(money, payment_method_or_reference, options = {})
        setup_address_hash(options)
        commit(build_purchase_request(money, payment_method_or_reference, options), :purchase, money, options)
      end

      def void(identification, options = {})
        commit(build_void_request(identification, options), :void, nil, options)
      end

      def refund(money, identification, options = {})
        commit(build_refund_request(money, identification, options), :refund, money, options)
      end

      def adjust(money, authorization, options = {})
        commit(build_adjust_request(money, authorization, options), :adjust, money, options)
      end

      def verify(payment, options = {})
        amount = eligible_for_zero_auth?(payment, options) ? 0 : 100
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, payment, options) }
          r.process(:ignore_result) { void(r.authorization, options) } unless amount == 0
        end
      end

      # Adds credit to a card or subscription (stand alone credit).
      def credit(money, creditcard_or_reference, options = {})
        setup_address_hash(options)
        commit(build_credit_request(money, creditcard_or_reference, options), :credit, money, options)
      end

      # Stores a customer subscription/profile with type "on-demand".
      # To charge the card while creating a profile, pass
      # options[:setup_fee] => money
      def store(payment_method, options = {})
        setup_address_hash(options)
        commit(build_create_subscription_request(payment_method, options), :store, nil, options)
      end

      # Updates a customer subscription/profile
      def update(reference, creditcard, options = {})
        requires!(options, :order_id)
        setup_address_hash(options)
        commit(build_update_subscription_request(reference, creditcard, options), :update, nil, options)
      end

      # Removes a customer subscription/profile
      def unstore(reference, options = {})
        requires!(options, :order_id)
        commit(build_delete_subscription_request(reference, options), :unstore, nil, options)
      end

      # Retrieves a customer subscription/profile
      def retrieve(reference, options = {})
        requires!(options, :order_id)
        commit(build_retrieve_subscription_request(reference, options), :retrieve, nil, options)
      end

      # CyberSource requires that you provide line item information for tax
      # calculations. If you do not have prices for each item or want to
      # simplify the situation then pass in one fake line item that costs the
      # subtotal of the order
      #
      # The line_item hash goes in the options hash and should look like
      #
      #         :line_items => [
      #           {
      #             :declared_value => '1',
      #             :quantity => '2',
      #             :code => 'default',
      #             :description => 'Giant Walrus',
      #             :sku => 'WA323232323232323'
      #           },
      #           {
      #             :declared_value => '6',
      #             :quantity => '1',
      #             :code => 'default',
      #             :description => 'Marble Snowcone',
      #             :sku => 'FAKE1232132113123'
      #           }
      #         ]
      #
      # This functionality is only supported by this particular gateway may
      # be changed at any time
      def calculate_tax(creditcard, options)
        requires!(options, :line_items)
        setup_address_hash(options)
        commit(build_tax_calculation_request(creditcard, options), :calculate_tax, nil, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<wsse:Password [^>]*>)[^<]*(</wsse:Password>))i, '\1[FILTERED]\2').
          gsub(%r((<accountNumber>)[^<]*(</accountNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<cvNumber>)[^<]*(</cvNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<cavv>)[^<]*(</cavv>))i, '\1[FILTERED]\2').
          gsub(%r((<xid>)[^<]*(</xid>))i, '\1[FILTERED]\2').
          gsub(%r((<authenticationData>)[^<]*(</authenticationData>))i, '\1[FILTERED]\2')
      end

      def supports_network_tokenization?
        true
      end

      def verify_credentials
        response = void('0')
        response.params['reasonCode'] == '102'
      end

      private

      # Create all required address hash key value pairs
      # If a value of nil is received, that value will be passed on to the gateway and will not be replaced with a default value
      # Billing address fields received without an override value or with an empty string value will be replaced with the default_address values
      def setup_address_hash(options)
        default_address = {
          address1: 'Unspecified',
          city: 'Unspecified',
          state: 'NC',
          zip: '00000',
          country: 'US'
        }

        submitted_address = options[:billing_address] || options[:address] || default_address
        options[:billing_address] = default_address.merge(submitted_address.symbolize_keys) { |_k, default, submitted| check_billing_field_value(default, submitted) }
        options[:shipping_address] = options[:shipping_address] || {}
      end

      def check_billing_field_value(default, submitted)
        if submitted.nil?
          nil
        elsif submitted.blank?
          default
        else
          submitted
        end
      end

      def build_auth_request(money, creditcard_or_reference, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_customer_id(xml, options)
        add_payment_method_or_subscription(xml, money, creditcard_or_reference, options)
        add_other_tax(xml, options)
        add_threeds_2_ucaf_data(xml, creditcard_or_reference, options)
        add_decision_manager_fields(xml, options)
        add_mdd_fields(xml, options)
        add_auth_service(xml, creditcard_or_reference, options)
        add_threeds_services(xml, options)
        add_business_rules_data(xml, creditcard_or_reference, options)
        add_airline_data(xml, options)
        add_sales_slip_number(xml, options)
        add_payment_network_token(xml) if network_tokenization?(creditcard_or_reference)
        add_payment_solution(xml, creditcard_or_reference.source) if network_tokenization?(creditcard_or_reference)
        add_tax_management_indicator(xml, options)
        add_stored_credential_subsequent_auth(xml, options)
        add_issuer_additional_data(xml, options)
        add_partner_solution_id(xml)
        add_stored_credential_options(xml, options)
        add_merchant_description(xml, options)
        xml.target!
      end

      def build_adjust_request(money, authorization, options)
        _, request_id = authorization.split(';')

        xml = Builder::XmlMarkup.new indent: 2
        add_purchase_data(xml, money, true, options)
        add_incremental_auth_service(xml, request_id, options)
        xml.target!
      end

      def build_tax_calculation_request(creditcard, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_address(xml, creditcard, options[:billing_address], options, false)
        add_address(xml, creditcard, options[:shipping_address], options, true)
        add_line_item_data(xml, options)
        add_purchase_data(xml, 0, false, options)
        add_tax_service(xml)
        add_business_rules_data(xml, creditcard, options)
        add_tax_management_indicator(xml, options)
        xml.target!
      end

      def build_capture_request(money, authorization, options)
        order_id, request_id, request_token = authorization.split(';')
        options[:order_id] = order_id

        xml = Builder::XmlMarkup.new indent: 2
        add_purchase_data(xml, money, true, options)
        add_other_tax(xml, options)
        add_mdd_fields(xml, options)
        add_capture_service(xml, request_id, request_token, options)
        add_business_rules_data(xml, authorization, options)
        add_tax_management_indicator(xml, options)
        add_issuer_additional_data(xml, options)
        add_merchant_description(xml, options)
        add_partner_solution_id(xml)

        xml.target!
      end

      def build_purchase_request(money, payment_method_or_reference, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_customer_id(xml, options)
        add_payment_method_or_subscription(xml, money, payment_method_or_reference, options)
        add_other_tax(xml, options)
        add_threeds_2_ucaf_data(xml, payment_method_or_reference, options)
        add_decision_manager_fields(xml, options)
        add_mdd_fields(xml, options)
        if (!payment_method_or_reference.is_a?(String) && card_brand(payment_method_or_reference) == 'check') || reference_is_a_check?(payment_method_or_reference)
          add_check_service(xml)
          add_airline_data(xml, options)
          add_sales_slip_number(xml, options)
          add_tax_management_indicator(xml, options)
          add_issuer_additional_data(xml, options)
          add_partner_solution_id(xml)
          options[:payment_method] = :check
        else
          add_purchase_service(xml, payment_method_or_reference, options)
          add_threeds_services(xml, options)
          add_business_rules_data(xml, payment_method_or_reference, options)
          add_airline_data(xml, options)
          add_sales_slip_number(xml, options)
          add_payment_network_token(xml) if network_tokenization?(payment_method_or_reference)
          add_payment_solution(xml, payment_method_or_reference.source) if network_tokenization?(payment_method_or_reference)
          add_tax_management_indicator(xml, options)
          add_stored_credential_subsequent_auth(xml, options)
          add_issuer_additional_data(xml, options)
          add_partner_solution_id(xml)
          add_stored_credential_options(xml, options)
          options[:payment_method] = :credit_card
        end

        add_merchant_description(xml, options)

        xml.target!
      end

      def reference_is_a_check?(payment_method_or_reference)
        payment_method_or_reference.is_a?(String) && payment_method_or_reference.split(';')[7] == 'check'
      end

      def build_void_request(identification, options)
        order_id, request_id, request_token, action, money, currency = identification.split(';')
        options[:order_id] = order_id

        xml = Builder::XmlMarkup.new indent: 2
        case action
        when 'capture', 'purchase'
          add_mdd_fields(xml, options)
          add_void_service(xml, request_id, request_token)
        else
          add_purchase_data(xml, money, true, options.merge(currency: currency || default_currency))
          add_mdd_fields(xml, options)
          add_auth_reversal_service(xml, request_id, request_token)
        end
        add_issuer_additional_data(xml, options)
        add_partner_solution_id(xml)

        xml.target!
      end

      def build_refund_request(money, identification, options)
        order_id, request_id, request_token = identification.split(';')
        options[:order_id] = order_id

        xml = Builder::XmlMarkup.new indent: 2
        add_purchase_data(xml, money, true, options)
        add_credit_service(xml, request_id: request_id,
                                request_token: request_token,
                                use_check_service: reference_is_a_check?(identification))
        add_partner_solution_id(xml)

        xml.target!
      end

      def build_credit_request(money, creditcard_or_reference, options)
        xml = Builder::XmlMarkup.new indent: 2

        add_payment_method_or_subscription(xml, money, creditcard_or_reference, options)
        add_mdd_fields(xml, options)
        add_credit_service(xml, use_check_service: creditcard_or_reference.is_a?(Check))
        add_issuer_additional_data(xml, options)
        add_merchant_description(xml, options)

        xml.target!
      end

      def build_create_subscription_request(payment_method, options)
        default_subscription_params = { frequency: 'on-demand', amount: 0, automatic_renew: false }
        options[:subscription] = default_subscription_params.update(
          options[:subscription] || {}
        )

        xml = Builder::XmlMarkup.new indent: 2
        add_address(xml, payment_method, options[:billing_address], options)
        add_purchase_data(xml, options[:setup_fee] || 0, true, options)
        if card_brand(payment_method) == 'check'
          add_check(xml, payment_method, options)
          add_check_payment_method(xml)
          options[:payment_method] = :check
        else
          add_creditcard(xml, payment_method)
          add_creditcard_payment_method(xml)
          options[:payment_method] = :credit_card
        end
        add_subscription(xml, options)
        if options[:setup_fee]
          if card_brand(payment_method) == 'check'
            add_check_service(xml)
          else
            add_purchase_service(xml, payment_method, options)
            add_payment_network_token(xml) if network_tokenization?(payment_method)
          end
        end
        add_subscription_create_service(xml, options)
        add_business_rules_data(xml, payment_method, options)
        add_tax_management_indicator(xml, options)
        xml.target!
      end

      def build_update_subscription_request(reference, creditcard, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_address(xml, creditcard, options[:billing_address], options) unless options[:billing_address].blank?
        add_purchase_data(xml, options[:setup_fee], true, options) unless options[:setup_fee].blank?
        add_creditcard(xml, creditcard)    if creditcard
        add_creditcard_payment_method(xml) if creditcard
        add_subscription(xml, options, reference)
        add_subscription_update_service(xml, options)
        add_business_rules_data(xml, creditcard, options)
        add_tax_management_indicator(xml, options)
        xml.target!
      end

      def build_delete_subscription_request(reference, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_subscription(xml, options, reference)
        add_subscription_delete_service(xml, options)
        xml.target!
      end

      def build_retrieve_subscription_request(reference, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_subscription(xml, options, reference)
        add_subscription_retrieve_service(xml, options)
        xml.target!
      end

      def add_business_rules_data(xml, payment_method, options)
        prioritized_options = [options, @options]

        xml.tag! 'businessRules' do
          xml.tag!('ignoreAVSResult', 'true') if extract_option(prioritized_options, :ignore_avs).to_s == 'true'
          xml.tag!('ignoreCVResult', 'true') if extract_option(prioritized_options, :ignore_cvv).to_s == 'true'
        end
      end

      def extract_option(prioritized_options, option_name)
        options_matching_key = prioritized_options.detect do |options|
          options.has_key? option_name
        end
        options_matching_key[option_name] if options_matching_key
      end

      def add_line_item_data(xml, options)
        return unless options[:line_items]

        options[:line_items].each_with_index do |value, index|
          xml.tag! 'item', { 'id' => index } do
            xml.tag! 'unitPrice', localized_amount(value[:declared_value].to_i, options[:currency] || default_currency)
            xml.tag! 'quantity', value[:quantity]
            xml.tag! 'productCode', value[:code] || 'shipping_only'
            xml.tag! 'productName', value[:description]
            xml.tag! 'productSKU', value[:sku]
            xml.tag! 'taxAmount', value[:tax_amount] if value[:tax_amount]
            xml.tag! 'nationalTax', value[:national_tax] if value[:national_tax]
          end
        end
      end

      def add_merchant_data(xml, options)
        xml.tag! 'merchantID', options[:merchant_id] || @options[:login]
        xml.tag! 'merchantReferenceCode', options[:order_id] || generate_unique_id
        xml.tag! 'clientLibrary', 'Ruby Active Merchant'
        xml.tag! 'clientLibraryVersion', VERSION
        xml.tag! 'clientEnvironment', RUBY_PLATFORM

        add_merchant_descriptor(xml, options)
      end

      def add_merchant_descriptor(xml, options)
        return unless options[:merchant_descriptor] || options[:user_po] || options[:taxable] || options[:reference_data_code] || options[:invoice_number]

        xml.tag! 'invoiceHeader' do
          xml.tag! 'merchantDescriptor', options[:merchant_descriptor] if options[:merchant_descriptor]
          xml.tag! 'userPO', options[:user_po] if options[:user_po]
          xml.tag! 'taxable', options[:taxable] if options[:taxable]
          xml.tag! 'referenceDataCode', options[:reference_data_code] if options[:reference_data_code]
          xml.tag! 'invoiceNumber', options[:invoice_number] if options[:invoice_number]
        end
      end

      def add_customer_id(xml, options)
        return unless options[:customer_id]

        xml.tag! 'customerID', options[:customer_id]
      end

      def add_merchant_description(xml, options)
        return unless options[:merchant_descriptor_name] || options[:merchant_descriptor_address1] || options[:merchant_descriptor_locality]

        xml.tag! 'merchantInformation' do
          xml.tag! 'merchantDescriptor' do
            xml.tag! 'name', options[:merchant_descriptor_name] if options[:merchant_descriptor_name]
            xml.tag! 'address1', options[:merchant_descriptor_address1] if options[:merchant_descriptor_address1]
            xml.tag! 'locality', options[:merchant_descriptor_locality] if options[:merchant_descriptor_locality]
          end
        end
      end

      def add_sales_slip_number(xml, options)
        xml.tag! 'salesSlipNumber', options[:sales_slip_number] if options[:sales_slip_number]
      end

      def add_airline_data(xml, options)
        return unless options[:airline_agent_code]

        xml.tag! 'airlineData' do
          xml.tag! 'agentCode', options[:airline_agent_code]
        end
      end

      def add_tax_management_indicator(xml, options)
        return unless options[:tax_management_indicator]

        xml.tag! 'taxManagementIndicator', options[:tax_management_indicator] if options[:tax_management_indicator]
      end

      def add_purchase_data(xml, money = 0, include_grand_total = false, options = {})
        xml.tag! 'purchaseTotals' do
          xml.tag! 'currency', options[:currency] || currency(money)
          xml.tag!('discountManagementIndicator', options[:discount_management_indicator]) if options[:discount_management_indicator]
          xml.tag!('taxAmount', options[:purchase_tax_amount]) if options[:purchase_tax_amount]
          xml.tag!('grandTotalAmount', localized_amount(money.to_i, options[:currency] || default_currency)) if include_grand_total
          xml.tag!('originalAmount', options[:original_amount]) if options[:original_amount]
          xml.tag!('invoiceAmount', options[:invoice_amount]) if options[:invoice_amount]
        end
      end

      def add_address(xml, payment_method, address, options, shipTo = false)
        first_name, last_name = address_names(address[:name], payment_method)
        bill_to_merchant_tax_id = options[:merchant_tax_id] unless shipTo

        xml.tag! shipTo ? 'shipTo' : 'billTo' do
          xml.tag! 'firstName',             first_name if first_name
          xml.tag! 'lastName',              last_name if last_name
          xml.tag! 'street1',               address[:address1]
          xml.tag! 'street2',               address[:address2] unless address[:address2].blank?
          xml.tag! 'city',                  address[:city]
          xml.tag! 'state',                 address[:state]
          xml.tag! 'postalCode',            address[:zip]
          xml.tag! 'country',               lookup_country_code(address[:country]) unless address[:country].blank?
          xml.tag! 'company',               address[:company]                 unless address[:company].blank?
          xml.tag! 'companyTaxID',          address[:companyTaxID]            unless address[:company_tax_id].blank?
          xml.tag! 'phoneNumber',           address[:phone]                   unless address[:phone].blank?
          xml.tag! 'email',                 options[:email].presence || 'null@cybersource.com'
          xml.tag! 'ipAddress',             options[:ip]                      unless options[:ip].blank? || shipTo
          xml.tag! 'driversLicenseNumber',  options[:drivers_license_number]  unless options[:drivers_license_number].blank?
          xml.tag! 'driversLicenseState',   options[:drivers_license_state]   unless options[:drivers_license_state].blank?
          xml.tag! 'merchantTaxID',         bill_to_merchant_tax_id           unless bill_to_merchant_tax_id.blank?
        end
      end

      def address_names(address_name, payment_method)
        names = split_names(address_name)
        return names if names.any?(&:present?)

        [
          payment_method&.first_name,
          payment_method&.last_name
        ]
      end

      def add_creditcard(xml, creditcard)
        xml.tag! 'card' do
          xml.tag! 'accountNumber', creditcard.number
          xml.tag! 'expirationMonth', format(creditcard.month, :two_digits)
          xml.tag! 'expirationYear', format(creditcard.year, :four_digits)
          xml.tag!('cvNumber', creditcard.verification_value) unless @options[:ignore_cvv].to_s == 'true' || creditcard.verification_value.blank?
          xml.tag! 'cardType', @@credit_card_codes[card_brand(creditcard).to_sym]
        end
      end

      def add_decision_manager_fields(xml, options)
        return unless options[:decision_manager_enabled]

        xml.tag! 'decisionManager' do
          xml.tag! 'enabled', options[:decision_manager_enabled] if options[:decision_manager_enabled]
          xml.tag! 'profile', options[:decision_manager_profile] if options[:decision_manager_profile]
        end
      end

      def add_payment_solution(xml, source)
        return unless (payment_solution = @@payment_solution[source])

        xml.tag! 'paymentSolution', payment_solution
      end

      def add_issuer_additional_data(xml, options)
        return unless options[:issuer_additional_data]

        xml.tag! 'issuer' do
          xml.tag! 'additionalData', options[:issuer_additional_data]
        end
      end

      def add_other_tax(xml, options)
        return unless options[:local_tax_amount] || options[:national_tax_amount] || options[:national_tax_indicator]

        xml.tag! 'otherTax' do
          xml.tag! 'vatTaxRate', options[:vat_tax_rate] if options[:vat_tax_rate]
          xml.tag! 'localTaxAmount', options[:local_tax_amount] if options[:local_tax_amount]
          xml.tag! 'nationalTaxAmount', options[:national_tax_amount] if options[:national_tax_amount]
          xml.tag! 'nationalTaxIndicator', options[:national_tax_indicator] if options[:national_tax_indicator]
        end
      end

      def add_mdd_fields(xml, options)
        return unless options.keys.any? { |key| key.to_s.start_with?('mdd_field') && options[key] }

        xml.tag! 'merchantDefinedData' do
          (1..100).each do |each|
            key = "mdd_field_#{each}".to_sym
            xml.tag!('mddField', options[key], 'id' => each) if options[key]
          end
        end
      end

      def add_check(xml, check, options)
        xml.tag! 'check' do
          xml.tag! 'accountNumber', check.account_number
          xml.tag! 'accountType', check.account_type == 'checking' ? 'C' : 'S'
          xml.tag! 'bankTransitNumber', format_routing_number(check.routing_number, options)
          xml.tag! 'secCode', options[:sec_code] if options[:sec_code]
        end
      end

      def add_tax_service(xml)
        xml.tag! 'taxService', { 'run' => 'true' } do
          xml.tag!('nexus', @options[:nexus]) unless @options[:nexus].blank?
          xml.tag!('sellerRegistration', @options[:vat_reg_number]) unless @options[:vat_reg_number].blank?
        end
      end

      def add_auth_service(xml, payment_method, options)
        if network_tokenization?(payment_method)
          add_auth_network_tokenization(xml, payment_method, options)
        else
          xml.tag! 'ccAuthService', { 'run' => 'true' } do
            if options[:three_d_secure]
              add_normalized_threeds_2_data(xml, payment_method, options)
              add_threeds_exemption_data(xml, options) if options[:three_ds_exemption_type]
            else
              indicator = options[:commerce_indicator] || stored_credential_commerce_indicator(options)
              xml.tag!('commerceIndicator', indicator) if indicator
            end
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
            xml.tag!('firstRecurringPayment', options[:first_recurring_payment]) if options[:first_recurring_payment]
            xml.tag!('mobileRemotePaymentType', options[:mobile_remote_payment_type]) if options[:mobile_remote_payment_type]
          end
        end
      end

      def add_threeds_exemption_data(xml, options)
        return unless options[:three_ds_exemption_type]

        exemption = options[:three_ds_exemption_type].to_sym

        case exemption
        when :authentication_outage, :corporate_card, :delegated_authentication, :low_risk, :low_value, :trusted_merchant
          xml.tag!(THREEDS_EXEMPTIONS[exemption], '1')
        end
      end

      def add_incremental_auth_service(xml, authorization, options)
        xml.tag! 'ccIncrementalAuthService', { 'run' => 'true' } do
          xml.tag! 'authRequestID', authorization
        end
        xml.tag! 'subsequentAuthReason', options[:auth_reason]
      end

      def add_normalized_threeds_2_data(xml, payment_method, options)
        threeds_2_options = options[:three_d_secure]
        cc_brand = card_brand(payment_method).to_sym

        return if threeds_2_options[:cavv].blank? && infer_commerce_indicator?(options, cc_brand)

        xid = threeds_2_options[:xid]

        xml.tag!('cavv', threeds_2_options[:cavv]) if threeds_2_options[:cavv] && cc_brand != :master
        xml.tag!('cavvAlgorithm', threeds_2_options[:cavv_algorithm]) if threeds_2_options[:cavv_algorithm]
        xml.tag!('paSpecificationVersion', threeds_2_options[:version]) if threeds_2_options[:version]
        xml.tag!('directoryServerTransactionID', threeds_2_options[:ds_transaction_id]) if threeds_2_options[:ds_transaction_id]
        xml.tag!('commerceIndicator', options[:commerce_indicator] || ECI_BRAND_MAPPING[cc_brand])
        xml.tag!('eciRaw', threeds_2_options[:eci]) if threeds_2_options[:eci]

        if xid.present?
          xml.tag!('xid', xid)
        elsif threeds_2_options[:version]&.start_with?('2') && cc_brand != :master
          cavv = threeds_2_options[:cavv]
          xml.tag!('xid', cavv) if cavv.present?
        end

        xml.tag!('veresEnrolled', threeds_2_options[:enrolled]) if threeds_2_options[:enrolled]
        xml.tag!('paresStatus', threeds_2_options[:authentication_response_status]) if threeds_2_options[:authentication_response_status]
      end

      def infer_commerce_indicator?(options, cc_brand)
        options[:commerce_indicator].blank? && ECI_BRAND_MAPPING[cc_brand].present?
      end

      def add_threeds_2_ucaf_data(xml, payment_method, options)
        return unless options[:three_d_secure] && card_brand(payment_method).to_sym == :master

        xml.tag! 'ucaf' do
          xml.tag!('authenticationData', options[:three_d_secure][:cavv])
          xml.tag!('collectionIndicator', options[:collection_indicator] || DEFAULT_COLLECTION_INDICATOR)
        end
      end

      def stored_credential_commerce_indicator(options)
        return unless options[:stored_credential]

        return if options[:stored_credential][:initial_transaction]

        case options[:stored_credential][:reason_type]
        when 'installment' then 'install'
        when 'recurring' then 'recurring'
        end
      end

      def network_tokenization?(payment_method)
        payment_method.is_a?(NetworkTokenizationCreditCard)
      end

      def subsequent_nt_apple_pay_auth(source, options)
        return unless options[:stored_credential] || options[:stored_credential_overrides]
        return unless @@payment_solution[source]

        options.dig(:stored_credential_overrides, :subsequent_auth) || options.dig(:stored_credential, :initiator) == 'merchant'
      end

      def add_auth_network_tokenization(xml, payment_method, options)
        return unless network_tokenization?(payment_method)

        commerce_indicator = 'internet' if subsequent_nt_apple_pay_auth(payment_method.source, options)

        brand = card_brand(payment_method).to_sym

        case brand
        when :visa
          xml.tag! 'ccAuthService', { 'run' => 'true' } do
            xml.tag!('cavv', payment_method.payment_cryptogram) unless commerce_indicator
            xml.commerceIndicator commerce_indicator.nil? ? ECI_BRAND_MAPPING[brand] : commerce_indicator
            xml.tag!('xid', payment_method.payment_cryptogram) unless commerce_indicator
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        when :master
          xml.tag! 'ucaf' do
            xml.tag!('authenticationData', payment_method.payment_cryptogram) unless commerce_indicator
            xml.tag!('collectionIndicator', DEFAULT_COLLECTION_INDICATOR)
          end
          xml.tag! 'ccAuthService', { 'run' => 'true' } do
            xml.commerceIndicator commerce_indicator.nil? ? ECI_BRAND_MAPPING[brand] : commerce_indicator
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        when :american_express
          cryptogram = Base64.decode64(payment_method.payment_cryptogram)
          xml.tag! 'ccAuthService', { 'run' => 'true' } do
            xml.tag!('cavv', Base64.encode64(cryptogram[0...20]))
            xml.tag!('commerceIndicator', ECI_BRAND_MAPPING[brand])
            xml.tag!('xid', Base64.encode64(cryptogram[20...40])) if cryptogram.bytes.count > 20
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        else
          raise ArgumentError.new("Payment method #{brand} is not supported, check https://developer.cybersource.com/docs/cybs/en-us/payments/developer/all/rest/payments/CreatingOnlineAuth/CreatingAuthReqPNT.html")
        end
      end

      def add_payment_network_token(xml)
        xml.tag! 'paymentNetworkToken' do
          xml.tag!('transactionType', '1')
        end
      end

      def add_capture_service(xml, request_id, request_token, options)
        xml.tag! 'ccCaptureService', { 'run' => 'true' } do
          xml.tag! 'authRequestID', request_id
          xml.tag! 'authRequestToken', request_token
          xml.tag! 'gratuityAmount', options[:gratuity_amount] if options[:gratuity_amount]
          xml.tag! 'reconciliationID', options[:reconciliation_id] if options[:reconciliation_id]
        end
      end

      def add_purchase_service(xml, payment_method, options)
        add_auth_service(xml, payment_method, options)
        xml.tag! 'ccCaptureService', { 'run' => 'true' } do
          xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
        end
      end

      def add_void_service(xml, request_id, request_token)
        xml.tag! 'voidService', { 'run' => 'true' } do
          xml.tag! 'voidRequestID', request_id
          xml.tag! 'voidRequestToken', request_token
        end
      end

      def add_auth_reversal_service(xml, request_id, request_token)
        xml.tag! 'ccAuthReversalService', { 'run' => 'true' } do
          xml.tag! 'authRequestID', request_id
          xml.tag! 'authRequestToken', request_token
        end
      end

      def add_credit_service(xml, options = {})
        service = options[:use_check_service] ? 'ecCreditService' : 'ccCreditService'
        request_tag = options[:use_check_service] ? 'debitRequestID' : 'captureRequestID'
        options.delete :request_token if options[:use_check_service]

        xml.tag! service, { 'run' => 'true' } do
          xml.tag! request_tag, options[:request_id] if options[:request_id]
          xml.tag! 'captureRequestToken', options[:request_token] if options[:request_token]
        end
      end

      def add_check_service(xml)
        xml.tag! 'ecDebitService', { 'run' => 'true' }
      end

      def add_subscription_create_service(xml, options)
        xml.tag! 'paySubscriptionCreateService', { 'run' => 'true' }
      end

      def add_subscription_update_service(xml, options)
        xml.tag! 'paySubscriptionUpdateService', { 'run' => 'true' }
      end

      def add_subscription_delete_service(xml, options)
        xml.tag! 'paySubscriptionDeleteService', { 'run' => 'true' }
      end

      def add_subscription_retrieve_service(xml, options)
        xml.tag! 'paySubscriptionRetrieveService', { 'run' => 'true' }
      end

      def add_subscription(xml, options, reference = nil)
        options[:subscription] ||= {}

        xml.tag! 'recurringSubscriptionInfo' do
          if reference
            subscription_id = reference.split(';')[6]
            xml.tag! 'subscriptionID',  subscription_id
          end

          xml.tag! 'status',            options[:subscription][:status] if options[:subscription][:status]
          xml.tag! 'amount',            localized_amount(options[:subscription][:amount].to_i, options[:currency] || default_currency) if options[:subscription][:amount]
          xml.tag! 'numberOfPayments',  options[:subscription][:occurrences]                    if options[:subscription][:occurrences]
          xml.tag! 'automaticRenew',    options[:subscription][:automatic_renew]                if options[:subscription][:automatic_renew]
          xml.tag! 'frequency',         options[:subscription][:frequency]                      if options[:subscription][:frequency]
          xml.tag! 'startDate',         options[:subscription][:start_date].strftime('%Y%m%d')  if options[:subscription][:start_date]
          xml.tag! 'endDate',           options[:subscription][:end_date].strftime('%Y%m%d')    if options[:subscription][:end_date]
          xml.tag! 'approvalRequired',  options[:subscription][:approval_required] || false
          xml.tag! 'event',             options[:subscription][:event]                          if options[:subscription][:event]
          xml.tag! 'billPayment',       options[:subscription][:bill_payment]                   if options[:subscription][:bill_payment]
        end
      end

      def add_creditcard_payment_method(xml)
        xml.tag! 'subscription' do
          xml.tag! 'paymentMethod', 'credit card'
        end
      end

      def add_check_payment_method(xml)
        xml.tag! 'subscription' do
          xml.tag! 'paymentMethod', 'check'
        end
      end

      def add_payment_method_or_subscription(xml, money, payment_method_or_reference, options)
        if payment_method_or_reference.is_a?(String)
          add_purchase_data(xml, money, true, options)
          add_installments(xml, options)
          add_subscription(xml, options, payment_method_or_reference)
        elsif card_brand(payment_method_or_reference) == 'check'
          add_address(xml, payment_method_or_reference, options[:billing_address], options)
          add_purchase_data(xml, money, true, options)
          add_installments(xml, options)
          add_check(xml, payment_method_or_reference, options)
        else
          add_address(xml, payment_method_or_reference, options[:billing_address], options)
          add_address(xml, payment_method_or_reference, options[:shipping_address], options, true)
          add_line_item_data(xml, options)
          add_purchase_data(xml, money, true, options)
          add_installments(xml, options)
          add_creditcard(xml, payment_method_or_reference)
        end
      end

      def add_installments(xml, options)
        return unless %i[installment_total_count installment_total_amount installment_plan_type first_installment_date installment_annual_interest_rate installment_grace_period_duration].any? { |gsf| options.include?(gsf) }

        xml.tag! 'installment' do
          xml.tag!('totalCount', options[:installment_total_count]) if options[:installment_total_count]
          xml.tag!('totalAmount', options[:installment_total_amount]) if options[:installment_total_amount]
          xml.tag!('planType', options[:installment_plan_type]) if options[:installment_plan_type]
          xml.tag!('firstInstallmentDate', options[:first_installment_date]) if options[:first_installment_date]
          xml.tag!('annualInterestRate', options[:installment_annual_interest_rate]) if options[:installment_annual_interest_rate]
          xml.tag!('gracePeriodDuration', options[:installment_grace_period_duration]) if options[:installment_grace_period_duration]
        end
      end

      def add_threeds_services(xml, options)
        xml.tag! 'payerAuthEnrollService', { 'run' => 'true' } if options[:payer_auth_enroll_service]
        if options[:payer_auth_validate_service]
          xml.tag! 'payerAuthValidateService', { 'run' => 'true' } do
            xml.tag! 'signedPARes', options[:pares]
          end
        end
      end

      def lookup_country_code(country_field)
        country_code = Country.find(country_field) rescue nil
        country_code&.code(:alpha2)
      end

      def add_stored_credential_subsequent_auth(xml, options = {})
        return unless options[:stored_credential] || options[:stored_credential_overrides]

        stored_credential_subsequent_auth = 'true' if options.dig(:stored_credential, :initiator) == 'merchant'

        override_subsequent_auth = options.dig(:stored_credential_overrides, :subsequent_auth)

        xml.subsequentAuth override_subsequent_auth.nil? ? stored_credential_subsequent_auth : override_subsequent_auth
      end

      def add_stored_credential_options(xml, options = {})
        return unless options[:stored_credential] || options[:stored_credential_overrides]

        stored_credential_subsequent_auth_first = 'true' if options.dig(:stored_credential, :initial_transaction)
        stored_credential_transaction_id = options.dig(:stored_credential, :network_transaction_id) if options.dig(:stored_credential, :initiator) == 'merchant'
        stored_credential_subsequent_auth_stored_cred = 'true' if subsequent_cardholder_initiated_transaction?(options) || unscheduled_merchant_initiated_transaction?(options) || threeds_stored_credential_exemption?(options)

        override_subsequent_auth_first = options.dig(:stored_credential_overrides, :subsequent_auth_first)
        override_subsequent_auth_transaction_id = options.dig(:stored_credential_overrides, :subsequent_auth_transaction_id)
        override_subsequent_auth_stored_cred = options.dig(:stored_credential_overrides, :subsequent_auth_stored_credential)

        xml.subsequentAuthFirst override_subsequent_auth_first.nil? ? stored_credential_subsequent_auth_first : override_subsequent_auth_first
        xml.subsequentAuthTransactionID override_subsequent_auth_transaction_id.nil? ? stored_credential_transaction_id : override_subsequent_auth_transaction_id
        xml.subsequentAuthStoredCredential override_subsequent_auth_stored_cred.nil? ? stored_credential_subsequent_auth_stored_cred : override_subsequent_auth_stored_cred
      end

      def subsequent_cardholder_initiated_transaction?(options)
        options.dig(:stored_credential, :initiator) == 'cardholder' && !options.dig(:stored_credential, :initial_transaction)
      end

      def unscheduled_merchant_initiated_transaction?(options)
        options.dig(:stored_credential, :initiator) == 'merchant' && options.dig(:stored_credential, :reason_type) == 'unscheduled'
      end

      def threeds_stored_credential_exemption?(options)
        options[:three_ds_exemption_type] == THREEDS_EXEMPTIONS[:stored_credential]
      end

      def add_partner_solution_id(xml)
        return unless application_id

        xml.tag!('partnerSolutionID', application_id)
      end

      # Where we actually build the full SOAP request using builder
      def build_request(body, options)
        xsd_version = test? ? TEST_XSD_VERSION : PRODUCTION_XSD_VERSION

        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct!
        xml.tag! 's:Envelope', { 'xmlns:s' => 'http://schemas.xmlsoap.org/soap/envelope/' } do
          xml.tag! 's:Header' do
            xml.tag! 'wsse:Security', { 's:mustUnderstand' => '1', 'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' } do
              xml.tag! 'wsse:UsernameToken' do
                xml.tag! 'wsse:Username', @options[:login]
                xml.tag! 'wsse:Password', @options[:password], 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText'
              end
            end
          end
          xml.tag! 's:Body', { 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema' } do
            xml.tag! 'requestMessage', { 'xmlns' => "urn:schemas-cybersource-com:transaction-data-#{xsd_version}" } do
              add_merchant_data(xml, options)
              xml << body
            end
          end
        end
        xml.target!
      end

      # Contact CyberSource, make the SOAP request, and parse the reply into a
      # Response object
      def commit(request, action, amount, options)
        begin
          raw_response = ssl_post(test? ? self.test_url : self.live_url, build_request(request, options))
        rescue ResponseError => e
          raw_response = e.response.body
        end

        begin
          response = parse(raw_response)
        rescue REXML::ParseException => e
          response = { message: e.to_s }
        end

        success = success?(response)
        message = message_from(response)
        authorization = success || in_fraud_review?(response) ? authorization_from(response, action, amount, options) : nil

        message = auto_void?(authorization_from(response, action, amount, options), response, message, options)

        Response.new(
          success,
          message,
          response,
          test: test?,
          authorization: authorization,
          fraud_review: in_fraud_review?(response),
          avs_result: { code: response[:avsCode] },
          cvv_result: response[:cvCode]
        )
      end

      def auto_void?(authorization, response, message, options = {})
        return message unless response[:reasonCode] == '230' && options[:auto_void_230]

        response = void(authorization, options)
        response&.success? ? message += ' - transaction has been auto-voided.' : message += ' - transaction could not be auto-voided.'
        message
      end

      # Parse the SOAP response
      # Technique inspired by the Paypal Gateway
      def parse(xml)
        reply = {}
        xml = REXML::Document.new(xml)
        if root = REXML::XPath.first(xml, '//c:replyMessage')
          root.elements.to_a.each do |node|
            case node.expanded_name
            when 'c:reasonCode'
              reply[:reasonCode] = node.text
              reply[:message] = reason_message(node.text)
            else
              parse_element(reply, node)
            end
          end
        elsif root = REXML::XPath.first(xml, '//soap:Fault')
          parse_element(reply, root)
          reply[:message] = "#{reply[:faultcode]}: #{reply[:faultstring]}"
        end
        return reply
      end

      def parse_element(reply, node)
        if node.has_elements?
          node.elements.each { |e| parse_element(reply, e) }
        else
          if /item/.match?(node.parent.name)
            parent = node.parent.name
            parent += '_' + node.parent.attributes['id'] if node.parent.attributes['id']
            parent += '_'
          end
          reply[:reconciliationID2] = node.text if node.name == 'reconciliationID' && reply[:reconciliationID]
          reply["#{parent}#{node.name}".to_sym] ||= node.text
        end
        return reply
      end

      def reason_message(reason_code)
        return if reason_code.blank?

        @@response_codes[:"r#{reason_code}"]
      end

      def authorization_from(response, action, amount, options)
        [options[:order_id], response[:requestID], response[:requestToken], action, amount,
         options[:currency], response[:subscriptionID], options[:payment_method]].join(';')
      end

      def in_fraud_review?(response)
        response[:decision] == @@decision_codes[:review]
      end

      def success?(response)
        response[:decision] == @@decision_codes[:accept]
      end

      def message_from(response)
        if response[:reasonCode] == '101' && response[:missingField]
          "#{response[:message]}: #{response[:missingField]}"
        elsif response[:reasonCode] == '102' && response[:invalidField]
          "#{response[:message]}: #{response[:invalidField]}"
        else
          response[:message]
        end
      end

      def eligible_for_zero_auth?(payment_method, options = {})
        payment_method.is_a?(CreditCard) && options[:zero_amount_auth]
      end

      def format_routing_number(routing_number, options)
        options[:currency] == 'CAD' && routing_number.length > 8 ? routing_number[-8..-1] : routing_number
      end
    end
  end
end
