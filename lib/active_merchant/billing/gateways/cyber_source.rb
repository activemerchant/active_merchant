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
    # * To process pinless debit cards through the pinless debit card
    #   network, your Cybersource merchant account must accept pinless
    #   debit card payments.
    # * The order of the XML elements does matter, make sure to follow the order in
    #   the documentation exactly.
    class CyberSourceGateway < Gateway
      self.test_url = 'https://ics2wstesta.ic3.com/commerce/1.x/transactionProcessor'
      self.live_url = 'https://ics2wsa.ic3.com/commerce/1.x/transactionProcessor'

      # Schema files can be found here: https://ics2ws.ic3.com/commerce/1.x/transactionProcessor/
      TEST_XSD_VERSION = '1.164'
      PRODUCTION_XSD_VERSION = '1.164'
      ECI_BRAND_MAPPING = {
        visa: 'vbv',
        master: 'spa',
        maestro: 'spa',
        american_express: 'aesk',
        jcb: 'js',
        discover: 'pb',
        diners_club: 'pb'
      }.freeze
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
        r221: "The customer matched an entry on the processor's negative file",
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
        r250: 'The request was received, but a time-out occurred with the payment processor',
        r254: 'Your CyberSource account is prohibited from processing stand-alone refunds',
        r255: 'Your CyberSource account is not configured to process the service in the country you specified'
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

      # options[:pinless_debit_card] => true # attempts to process as pinless debit card
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

      def verify(payment, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, payment, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
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

      # Determines if a card can be used for Pinless Debit Card transactions
      def validate_pinless_debit_card(creditcard, options = {})
        requires!(options, :order_id)
        commit(build_validate_pinless_debit_request(creditcard, options), :validate_pinless_debit_card, nil, options)
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

      # Create all address hash key value pairs so that we still function if we
      # were only provided with one or two of them or even none
      def setup_address_hash(options)
        default_address = {
          address1: 'Unspecified',
          city: 'Unspecified',
          state: 'NC',
          zip: '00000',
          country: 'US'
        }

        submitted_address = options[:billing_address] || options[:address] || default_address
        options[:billing_address] = default_address.merge(submitted_address) { |_k, default, submitted| submitted.blank? ? default : submitted }
        options[:shipping_address] = options[:shipping_address] || {}
      end

      def build_auth_request(money, creditcard_or_reference, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_payment_method_or_subscription(xml, money, creditcard_or_reference, options)
        add_threeds_2_ucaf_data(xml, creditcard_or_reference, options)
        add_decision_manager_fields(xml, options)
        add_mdd_fields(xml, options)
        add_auth_service(xml, creditcard_or_reference, options)
        add_threeds_services(xml, options)
        add_payment_network_token(xml) if network_tokenization?(creditcard_or_reference)
        add_business_rules_data(xml, creditcard_or_reference, options)
        add_stored_credential_subsequent_auth(xml, options)
        add_issuer_additional_data(xml, options)
        add_partner_solution_id(xml)
        add_stored_credential_options(xml, options)
        add_merchant_description(xml, options)

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
        xml.target!
      end

      def build_capture_request(money, authorization, options)
        order_id, request_id, request_token = authorization.split(';')
        options[:order_id] = order_id

        xml = Builder::XmlMarkup.new indent: 2
        add_purchase_data(xml, money, true, options)
        add_other_tax(xml, options)
        add_mdd_fields(xml, options)
        add_capture_service(xml, request_id, request_token)
        add_business_rules_data(xml, authorization, options)
        add_issuer_additional_data(xml, options)
        add_merchant_description(xml, options)
        add_partner_solution_id(xml)

        xml.target!
      end

      def build_purchase_request(money, payment_method_or_reference, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_payment_method_or_subscription(xml, money, payment_method_or_reference, options)
        add_threeds_2_ucaf_data(xml, payment_method_or_reference, options)
        add_decision_manager_fields(xml, options)
        add_mdd_fields(xml, options)
        if !payment_method_or_reference.is_a?(String) && card_brand(payment_method_or_reference) == 'check'
          add_check_service(xml)
          add_issuer_additional_data(xml, options)
          add_partner_solution_id(xml)
        else
          add_purchase_service(xml, payment_method_or_reference, options)
          add_threeds_services(xml, options)
          add_payment_network_token(xml) if network_tokenization?(payment_method_or_reference)
          add_business_rules_data(xml, payment_method_or_reference, options) unless options[:pinless_debit_card]
          add_stored_credential_subsequent_auth(xml, options)
          add_issuer_additional_data(xml, options)
          add_partner_solution_id(xml)
          add_stored_credential_options(xml, options)
        end

        add_merchant_description(xml, options)

        xml.target!
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
        add_credit_service(xml, request_id, request_token)
        add_partner_solution_id(xml)

        xml.target!
      end

      def build_credit_request(money, creditcard_or_reference, options)
        xml = Builder::XmlMarkup.new indent: 2

        add_payment_method_or_subscription(xml, money, creditcard_or_reference, options)
        add_mdd_fields(xml, options)
        add_credit_service(xml)
        add_issuer_additional_data(xml, options)
        add_merchant_description(xml, options)

        xml.target!
      end

      def build_create_subscription_request(payment_method, options)
        default_subscription_params = {frequency: 'on-demand', amount: 0, automatic_renew: false}
        options[:subscription] = default_subscription_params.update(
          options[:subscription] || {}
        )

        xml = Builder::XmlMarkup.new indent: 2
        add_address(xml, payment_method, options[:billing_address], options)
        add_purchase_data(xml, options[:setup_fee] || 0, true, options)
        if card_brand(payment_method) == 'check'
          add_check(xml, payment_method)
          add_check_payment_method(xml)
        else
          add_creditcard(xml, payment_method)
          add_creditcard_payment_method(xml)
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

      def build_validate_pinless_debit_request(creditcard, options)
        xml = Builder::XmlMarkup.new indent: 2
        add_creditcard(xml, creditcard)
        add_validate_pinless_debit_service(xml)
        xml.target!
      end

      def add_business_rules_data(xml, payment_method, options)
        prioritized_options = [options, @options]

        unless network_tokenization?(payment_method)
          xml.tag! 'businessRules' do
            xml.tag!('ignoreAVSResult', 'true') if extract_option(prioritized_options, :ignore_avs)
            xml.tag!('ignoreCVResult', 'true') if extract_option(prioritized_options, :ignore_cvv)
          end
        end
      end

      def extract_option(prioritized_options, option_name)
        options_matching_key = prioritized_options.detect do |options|
          options.has_key? option_name
        end
        options_matching_key[option_name] if options_matching_key
      end

      def add_line_item_data(xml, options)
        options[:line_items].each_with_index do |value, index|
          xml.tag! 'item', {'id' => index} do
            xml.tag! 'unitPrice', localized_amount(value[:declared_value].to_i, options[:currency] || default_currency)
            xml.tag! 'quantity', value[:quantity]
            xml.tag! 'productCode', value[:code] || 'shipping_only'
            xml.tag! 'productName', value[:description]
            xml.tag! 'productSKU', value[:sku]
          end
        end
      end

      def add_merchant_data(xml, options)
        xml.tag! 'merchantID', @options[:login]
        xml.tag! 'merchantReferenceCode', options[:order_id] || generate_unique_id
        xml.tag! 'clientLibrary', 'Ruby Active Merchant'
        xml.tag! 'clientLibraryVersion', VERSION
        xml.tag! 'clientEnvironment', RUBY_PLATFORM

        add_merchant_descriptor(xml, options)
      end

      def add_merchant_descriptor(xml, options)
        return unless options[:merchant_descriptor]

        xml.tag! 'invoiceHeader' do
          xml.tag! 'merchantDescriptor', options[:merchant_descriptor]
        end
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

      def add_purchase_data(xml, money = 0, include_grand_total = false, options={})
        xml.tag! 'purchaseTotals' do
          xml.tag! 'currency', options[:currency] || currency(money)
          xml.tag!('grandTotalAmount', localized_amount(money.to_i, options[:currency] || default_currency)) if include_grand_total
        end
      end

      def add_address(xml, payment_method, address, options, shipTo = false)
        xml.tag! shipTo ? 'shipTo' : 'billTo' do
          xml.tag! 'firstName',             payment_method.first_name if payment_method
          xml.tag! 'lastName',              payment_method.last_name if payment_method
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
        end
      end

      def add_creditcard(xml, creditcard)
        xml.tag! 'card' do
          xml.tag! 'accountNumber', creditcard.number
          xml.tag! 'expirationMonth', format(creditcard.month, :two_digits)
          xml.tag! 'expirationYear', format(creditcard.year, :four_digits)
          xml.tag!('cvNumber', creditcard.verification_value) unless @options[:ignore_cvv] || creditcard.verification_value.blank?
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

      def add_issuer_additional_data(xml, options)
        return unless options[:issuer_additional_data]

        xml.tag! 'issuer' do
          xml.tag! 'additionalData', options[:issuer_additional_data]
        end
      end

      def add_other_tax(xml, options)
        return unless options[:local_tax_amount] || options[:national_tax_amount]

        xml.tag! 'otherTax' do
          xml.tag! 'localTaxAmount', options[:local_tax_amount] if options[:local_tax_amount]
          xml.tag! 'nationalTaxAmount', options[:national_tax_amount] if options[:national_tax_amount]
        end
      end

      def add_mdd_fields(xml, options)
        return unless options.keys.any? { |key| key.to_s.start_with?('mdd_field') }

        xml.tag! 'merchantDefinedData' do
          (1..100).each do |each|
            key = "mdd_field_#{each}".to_sym
            xml.tag!("field#{each}", options[key]) if options[key]
          end
        end
      end

      def add_check(xml, check)
        xml.tag! 'check' do
          xml.tag! 'accountNumber', check.account_number
          xml.tag! 'accountType', check.account_type[0]
          xml.tag! 'bankTransitNumber', check.routing_number
        end
      end

      def add_tax_service(xml)
        xml.tag! 'taxService', {'run' => 'true'} do
          xml.tag!('nexus', @options[:nexus]) unless @options[:nexus].blank?
          xml.tag!('sellerRegistration', @options[:vat_reg_number]) unless @options[:vat_reg_number].blank?
        end
      end

      def add_auth_service(xml, payment_method, options)
        if network_tokenization?(payment_method)
          add_auth_network_tokenization(xml, payment_method, options)
        else
          xml.tag! 'ccAuthService', {'run' => 'true'} do
            if options[:three_d_secure]
              add_normalized_threeds_2_data(xml, payment_method, options)
            else
              indicator = options[:commerce_indicator] || stored_credential_commerce_indicator(options)
              xml.tag!('commerceIndicator', indicator) if indicator
            end
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        end
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

      def add_auth_network_tokenization(xml, payment_method, options)
        return unless network_tokenization?(payment_method)

        brand = card_brand(payment_method).to_sym

        case brand
        when :visa
          xml.tag! 'ccAuthService', {'run' => 'true'} do
            xml.tag!('cavv', payment_method.payment_cryptogram)
            xml.tag!('commerceIndicator', ECI_BRAND_MAPPING[brand])
            xml.tag!('xid', payment_method.payment_cryptogram)
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        when :master
          xml.tag! 'ucaf' do
            xml.tag!('authenticationData', payment_method.payment_cryptogram)
            xml.tag!('collectionIndicator', DEFAULT_COLLECTION_INDICATOR)
          end
          xml.tag! 'ccAuthService', {'run' => 'true'} do
            xml.tag!('commerceIndicator', ECI_BRAND_MAPPING[brand])
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        when :american_express
          cryptogram = Base64.decode64(payment_method.payment_cryptogram)
          xml.tag! 'ccAuthService', {'run' => 'true'} do
            xml.tag!('cavv', Base64.encode64(cryptogram[0...20]))
            xml.tag!('commerceIndicator', ECI_BRAND_MAPPING[brand])
            xml.tag!('xid', Base64.encode64(cryptogram[20...40]))
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        end
      end

      def add_payment_network_token(xml)
        xml.tag! 'paymentNetworkToken' do
          xml.tag!('transactionType', '1')
        end
      end

      def add_capture_service(xml, request_id, request_token)
        xml.tag! 'ccCaptureService', {'run' => 'true'} do
          xml.tag! 'authRequestID', request_id
          xml.tag! 'authRequestToken', request_token
          xml.tag! 'reconciliationID', options[:reconciliation_id] if options[:reconciliation_id]
        end
      end

      def add_purchase_service(xml, payment_method, options)
        if options[:pinless_debit_card]
          xml.tag! 'pinlessDebitService', {'run' => 'true'} do
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        else
          add_auth_service(xml, payment_method, options)
          xml.tag! 'ccCaptureService', {'run' => 'true'} do
            xml.tag!('reconciliationID', options[:reconciliation_id]) if options[:reconciliation_id]
          end
        end
      end

      def add_void_service(xml, request_id, request_token)
        xml.tag! 'voidService', {'run' => 'true'} do
          xml.tag! 'voidRequestID', request_id
          xml.tag! 'voidRequestToken', request_token
        end
      end

      def add_auth_reversal_service(xml, request_id, request_token)
        xml.tag! 'ccAuthReversalService', {'run' => 'true'} do
          xml.tag! 'authRequestID', request_id
          xml.tag! 'authRequestToken', request_token
        end
      end

      def add_credit_service(xml, request_id = nil, request_token = nil)
        xml.tag! 'ccCreditService', {'run' => 'true'} do
          xml.tag! 'captureRequestID', request_id if request_id
          xml.tag! 'captureRequestToken', request_token if request_token
        end
      end

      def add_check_service(xml)
        xml.tag! 'ecDebitService', {'run' => 'true'}
      end

      def add_subscription_create_service(xml, options)
        xml.tag! 'paySubscriptionCreateService', {'run' => 'true'}
      end

      def add_subscription_update_service(xml, options)
        xml.tag! 'paySubscriptionUpdateService', {'run' => 'true'}
      end

      def add_subscription_delete_service(xml, options)
        xml.tag! 'paySubscriptionDeleteService', {'run' => 'true'}
      end

      def add_subscription_retrieve_service(xml, options)
        xml.tag! 'paySubscriptionRetrieveService', {'run' => 'true'}
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
          add_check(xml, payment_method_or_reference)
        else
          add_address(xml, payment_method_or_reference, options[:billing_address], options)
          add_address(xml, payment_method_or_reference, options[:shipping_address], options, true)
          add_purchase_data(xml, money, true, options)
          add_installments(xml, options)
          add_creditcard(xml, payment_method_or_reference)
        end
      end

      def add_installments(xml, options)
        return unless options[:installment_total_count]

        xml.tag! 'installment' do
          xml.tag! 'totalCount', options[:installment_total_count]
        end
      end

      def add_validate_pinless_debit_service(xml)
        xml.tag! 'pinlessDebitValidateService', {'run' => 'true'}
      end

      def add_threeds_services(xml, options)
        xml.tag! 'payerAuthEnrollService', {'run' => 'true'} if options[:payer_auth_enroll_service]
        if options[:payer_auth_validate_service]
          xml.tag! 'payerAuthValidateService', {'run' => 'true'} do
            xml.tag! 'signedPARes', options[:pares]
          end
        end
      end

      def lookup_country_code(country_field)
        country_code = Country.find(country_field) rescue nil
        country_code&.code(:alpha2)
      end

      def add_stored_credential_subsequent_auth(xml, options={})
        return unless options[:stored_credential] || options[:stored_credential_overrides]

        stored_credential_subsequent_auth = 'true' if options.dig(:stored_credential, :initiator) == 'merchant'

        override_subsequent_auth = options.dig(:stored_credential_overrides, :subsequent_auth)

        xml.subsequentAuth override_subsequent_auth.nil? ? stored_credential_subsequent_auth : override_subsequent_auth
      end

      def add_stored_credential_options(xml, options={})
        return unless options[:stored_credential] || options[:stored_credential_overrides]

        stored_credential_subsequent_auth_first = 'true' if options.dig(:stored_credential, :initial_transaction)
        stored_credential_transaction_id = options.dig(:stored_credential, :network_transaction_id) if options.dig(:stored_credential, :initiator) == 'merchant'
        stored_credential_subsequent_auth_stored_cred = 'true' if options.dig(:stored_credential, :initiator) == 'cardholder' && !options.dig(:stored_credential, :initial_transaction) || options.dig(:stored_credential, :initiator) == 'merchant' && options.dig(:stored_credential, :reason_type) == 'unscheduled'

        override_subsequent_auth_first = options.dig(:stored_credential_overrides, :subsequent_auth_first)
        override_subsequent_auth_transaction_id = options.dig(:stored_credential_overrides, :subsequent_auth_transaction_id)
        override_subsequent_auth_stored_cred = options.dig(:stored_credential_overrides, :subsequent_auth_stored_credential)

        xml.subsequentAuthFirst override_subsequent_auth_first.nil? ? stored_credential_subsequent_auth_first : override_subsequent_auth_first
        xml.subsequentAuthTransactionID override_subsequent_auth_transaction_id.nil? ? stored_credential_transaction_id : override_subsequent_auth_transaction_id
        xml.subsequentAuthStoredCredential override_subsequent_auth_stored_cred.nil? ? stored_credential_subsequent_auth_stored_cred : override_subsequent_auth_stored_cred
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
        xml.tag! 's:Envelope', {'xmlns:s' => 'http://schemas.xmlsoap.org/soap/envelope/'} do
          xml.tag! 's:Header' do
            xml.tag! 'wsse:Security', {'s:mustUnderstand' => '1', 'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'} do
              xml.tag! 'wsse:UsernameToken' do
                xml.tag! 'wsse:Username', @options[:login]
                xml.tag! 'wsse:Password', @options[:password], 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText'
              end
            end
          end
          xml.tag! 's:Body', {'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'} do
            xml.tag! 'requestMessage', {'xmlns' => "urn:schemas-cybersource-com:transaction-data-#{xsd_version}"} do
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

        Response.new(success, message, response,
          test: test?,
          authorization: authorization,
          fraud_review: in_fraud_review?(response),
          avs_result: { code: response[:avsCode] },
          cvv_result: response[:cvCode]
        )
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
         options[:currency], response[:subscriptionID]].join(';')
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
    end
  end
end
