module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Initial setup instructions can be found in
    # http://cybersource.com/support_center/implementation/downloads/soap_api/SOAP_toolkits.pdf
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

      XSD_VERSION = '1.153'

      # Constants for p12 cert auth
      WSU_NS = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'.freeze
      WSSE_NS = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'.freeze
      SOAP_NS = 'http://schemas.xmlsoap.org/soap/envelope/'.freeze
      DS_NS = 'http://www.w3.org/2000/09/xmldsig#'.freeze

      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :dankort, :maestro]
      self.supported_countries = %w(US BR CA CN DK FI FR DE IN JP MX NO SE GB SG LB ZA)

      self.default_currency = 'USD'
      self.currencies_without_fractions = %w(JPY)

      self.homepage_url = 'http://www.cybersource.com'
      self.display_name = 'CyberSource'

      @@credit_card_codes = {
        :visa  => '001',
        :master => '002',
        :american_express => '003',
        :discover => '004',
        :diners_club => '005',
        :jcb => '007',
        :dankort => '034',
        :maestro => '042'
      }

      @@response_codes = {
        :r100 => 'Successful transaction',
        :r101 => 'Request is missing one or more required fields',
        :r102 => 'One or more fields contains invalid data',
        :r150 => 'General failure',
        :r151 => 'The request was received but a server time-out occurred',
        :r152 => 'The request was received, but a service timed out',
        :r200 => 'The authorization request was approved by the issuing bank but declined by CyberSource because it did not pass the AVS check',
        :r201 => 'The issuing bank has questions about the request',
        :r202 => 'Expired card',
        :r203 => 'General decline of the card',
        :r204 => 'Insufficient funds in the account',
        :r205 => 'Stolen or lost card',
        :r207 => 'Issuing bank unavailable',
        :r208 => 'Inactive card or card not authorized for card-not-present transactions',
        :r209 => 'American Express Card Identifiction Digits (CID) did not match',
        :r210 => 'The card has reached the credit limit',
        :r211 => 'Invalid card verification number',
        :r221 => "The customer matched an entry on the processor's negative file",
        :r230 => 'The authorization request was approved by the issuing bank but declined by CyberSource because it did not pass the card verification check',
        :r231 => 'Invalid account number',
        :r232 => 'The card type is not accepted by the payment processor',
        :r233 => 'General decline by the processor',
        :r234 => 'A problem exists with your CyberSource merchant configuration',
        :r235 => 'The requested amount exceeds the originally authorized amount',
        :r236 => 'Processor failure',
        :r237 => 'The authorization has already been reversed',
        :r238 => 'The authorization has already been captured',
        :r239 => 'The requested transaction amount must match the previous transaction amount',
        :r240 => 'The card type sent is invalid or does not correlate with the credit card number',
        :r241 => 'The request ID is invalid',
        :r242 => 'You requested a capture, but there is no corresponding, unused authorization record.',
        :r243 => 'The transaction has already been settled or reversed',
        :r244 => 'The bank account number failed the validation check',
        :r246 => 'The capture or credit is not voidable because the capture or credit information has already been submitted to your processor',
        :r247 => 'You requested a credit for a capture that was previously voided',
        :r250 => 'The request was received, but a time-out occurred with the payment processor',
        :r254 => 'Your CyberSource account is prohibited from processing stand-alone refunds',
        :r255 => 'Your CyberSource account is not configured to process the service in the country you specified',
        :r475 => 'The customer is enrolled in payer authentication. Authenticate the cardholder before continuing with the transaction.',
        :r476 => 'The customer cannot be authenticated'
      }

      # These are the options that can be used when creating a new CyberSource
      # Gateway object.
      #
      # :login =>  your username
      #
      # :password =>  the transaction key you generated in the Business Center
      #
      # :p12_certificate => the contents of your .p12 file
      #
      # :p12_certificate_password => the password you set on your .p12 file
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
        requires!(options, :login, :password, :p12_certificate, :p12_certificate_password)
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
      # options[:source_type] => 'check' for stored ACH purchases
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

      # Adds credit to a subscription (stand alone credit).
      def credit(money, reference, options = {})
        commit(build_credit_request(money, reference, options), :credit, money, options)
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
        requires!(options,  :line_items)
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
          :address1 => 'Unspecified',
          :city => 'Unspecified',
          :state => 'NC',
          :zip => '00000',
          :country => 'US'
        }
        options[:billing_address] = options[:billing_address] || options[:address] || default_address
        options[:shipping_address] = options[:shipping_address] || {}
      end

      def build_auth_request(money, creditcard_or_reference, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_payment_method_or_subscription(xml, money, creditcard_or_reference, options)
        add_decision_manager_fields(xml, options)
        add_mdd_fields(xml, options)
        add_auth_service(xml, creditcard_or_reference, options)
        add_threeds_services(xml, options)
        add_payment_network_token(xml) if network_tokenization?(creditcard_or_reference)
        add_business_rules_data(xml, creditcard_or_reference, options)
        add_stored_credential_subsequent_auth(xml, options)
        add_stored_credential_options(xml, options)
        xml.target!
      end

      def build_tax_calculation_request(creditcard, options)
        xml = Builder::XmlMarkup.new :indent => 2
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

        xml = Builder::XmlMarkup.new :indent => 2
        add_purchase_data(xml, money, true, options)
        add_capture_service(xml, request_id, request_token)
        add_business_rules_data(xml, authorization, options)
        xml.target!
      end

      def build_purchase_request(money, payment_method_or_reference, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_payment_method_or_subscription(xml, money, payment_method_or_reference, options)
        add_decision_manager_fields(xml, options)
        add_mdd_fields(xml, options)
        if !payment_method_or_reference.is_a?(String) && card_brand(payment_method_or_reference) == 'check' || options[:source_type] == 'check'
          add_check_service(xml)
        else
          add_purchase_service(xml, payment_method_or_reference, options)
          add_threeds_services(xml, options)
          add_payment_network_token(xml) if network_tokenization?(payment_method_or_reference)
          add_business_rules_data(xml, payment_method_or_reference, options) unless options[:pinless_debit_card]
        end
        add_stored_credential_subsequent_auth(xml, options)
        add_stored_credential_options(xml, options)
        xml.target!
      end

      def build_void_request(identification, options)
        order_id, request_id, request_token, action, money, currency  = identification.split(';')
        options[:order_id] = order_id

        xml = Builder::XmlMarkup.new :indent => 2
        if action == 'capture'
          add_void_service(xml, request_id, request_token)
        else
          add_purchase_data(xml, money.to_i, true, options.merge(:currency => currency || default_currency))
          add_auth_reversal_service(xml, request_id, request_token)
        end
        xml.target!
      end

      def build_refund_request(money, identification, options)
        order_id, request_id, request_token = identification.split(';')
        options[:order_id] = order_id

        xml = Builder::XmlMarkup.new :indent => 2
        add_purchase_data(xml, money, true, options)
        add_credit_service(xml, request_id, request_token)

        xml.target!
      end

      def build_credit_request(money, reference, options)
        xml = Builder::XmlMarkup.new :indent => 2

        add_purchase_data(xml, money, true, options)
        add_subscription(xml, options, reference)
        add_credit_service(xml)

        xml.target!
      end

      def build_create_subscription_request(payment_method, options)
        default_subscription_params = {:frequency => 'on-demand', :amount => 0, :automatic_renew => false}
        options[:subscription] = default_subscription_params.update(
          options[:subscription] || {}
        )

        xml = Builder::XmlMarkup.new :indent => 2
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
        xml = Builder::XmlMarkup.new :indent => 2
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
        xml = Builder::XmlMarkup.new :indent => 2
        add_subscription(xml, options, reference)
        add_subscription_delete_service(xml, options)
        xml.target!
      end

      def build_retrieve_subscription_request(reference, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_subscription(xml, options, reference)
        add_subscription_retrieve_service(xml, options)
        xml.target!
      end

      def build_validate_pinless_debit_request(creditcard, options)
        xml = Builder::XmlMarkup.new :indent => 2
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
        xml.tag! 'clientLibraryVersion',  VERSION
        xml.tag! 'clientEnvironment', RUBY_PLATFORM
        add_merchant_descriptor(xml, options)
      end

      def add_merchant_descriptor(xml, options)
        return unless options[:merchant_descriptor]

        xml.tag! 'invoiceHeader' do
          xml.tag! 'merchantDescriptor', options[:merchant_descriptor]
        end
      end

      def add_purchase_data(xml, money = 0, include_grand_total = false, options={})
        xml.tag! 'purchaseTotals' do
          xml.tag! 'currency', options[:currency] || currency(money)
          xml.tag!('grandTotalAmount', localized_amount(money, options[:currency] || default_currency))  if include_grand_total
        end
      end

      def add_address(xml, payment_method, address, options, shipTo = false)
        xml.tag! shipTo ? 'shipTo' : 'billTo' do
          xml.tag! 'firstName',             payment_method.first_name             if payment_method
          xml.tag! 'lastName',              payment_method.last_name              if payment_method
          xml.tag! 'street1',               address[:address1]
          xml.tag! 'street2',               address[:address2]
          xml.tag! 'city',                  address[:city]
          xml.tag! 'state',                 address[:state]
          xml.tag! 'postalCode',            address[:zip]
          xml.tag! 'country',               lookup_country_code(address[:country]) unless address[:country].blank?
          xml.tag! 'company',               address[:company]                 unless address[:company].blank?
          xml.tag! 'companyTaxID',          address[:companyTaxID]            unless address[:company_tax_id].blank?
          xml.tag! 'phoneNumber',           address[:phone]                   unless address[:phone].blank?
          xml.tag! 'email',                 options[:email] || 'null@cybersource.com'
          xml.tag! 'ipAddress',             options[:ip]                      unless options[:ip].blank? || shipTo
          xml.tag! 'driversLicenseNumber',  options[:drivers_license_number]  unless options[:drivers_license_number].blank?
          xml.tag! 'driversLicenseState',   options[:drivers_license_state]   unless options[:drivers_license_state].blank?
        end
      end

      def add_address_ip_fields(xml, options)
        return if options[:ip].blank?

        xml.tag! 'billTo' do
          xml.tag! 'ipAddress', options[:ip]
        end
      end

      def add_creditcard(xml, creditcard)
        xml.tag! 'card' do
          xml.tag!('accountNumber', creditcard.number) unless creditcard.number.blank?
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
            check_for_stored_cred_commerce_indicator(xml, options)
          end
        end
      end

      def check_for_stored_cred_commerce_indicator(xml, options)
        return unless options[:stored_credential]
        if commerce_indicator(options)
          xml.tag!('commerceIndicator', commerce_indicator(options))
        end
      end

      def commerce_indicator(options)
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

        case card_brand(payment_method).to_sym
        when :visa
          xml.tag! 'ccAuthService', {'run' => 'true'} do
            xml.tag!('cavv', payment_method.payment_cryptogram)
            xml.tag!('commerceIndicator', 'vbv')
            xml.tag!('xid', payment_method.payment_cryptogram)
          end
        when :mastercard
          xml.tag! 'ucaf' do
            xml.tag!('authenticationData', payment_method.payment_cryptogram)
            xml.tag!('collectionIndicator', '2')
          end
          xml.tag! 'ccAuthService', {'run' => 'true'} do
            xml.tag!('commerceIndicator', 'spa')
          end
        when :american_express
          cryptogram = Base64.decode64(payment_method.payment_cryptogram)
          xml.tag! 'ccAuthService', {'run' => 'true'} do
            xml.tag!('cavv', Base64.encode64(cryptogram[0...20]))
            xml.tag!('commerceIndicator', 'aesk')
            xml.tag!('xid', Base64.encode64(cryptogram[20...40]))
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
        end
      end

      def add_purchase_service(xml, payment_method, options)
        if options[:pinless_debit_card]
          xml.tag! 'pinlessDebitService', {'run' => 'true'}
        else
          add_auth_service(xml, payment_method, options)
          xml.tag! 'ccCaptureService', {'run' => 'true'}
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

          xml.tag! 'status',            options[:subscription][:status]                         if options[:subscription][:status]
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
          add_address_ip_fields(xml, options)
          add_purchase_data(xml, money, true, options)
          add_subscription(xml, options, payment_method_or_reference)
        elsif card_brand(payment_method_or_reference) == 'check'
          add_address(xml, payment_method_or_reference, options[:billing_address], options)
          add_purchase_data(xml, money, true, options)
          add_check(xml, payment_method_or_reference)
        else
          add_address(xml, payment_method_or_reference, options[:billing_address], options)
          add_address(xml, payment_method_or_reference, options[:shipping_address], options, true)
          add_purchase_data(xml, money, true, options)
          add_creditcard(xml, payment_method_or_reference)
        end
      end

      def add_validate_pinless_debit_service(xml)
        xml.tag! 'pinlessDebitValidateService', {'run' => 'true'}
      end

      def add_threeds_services(xml, options)
        xml.tag! 'payerAuthEnrollService', {'run' => 'true'} do
          xml.tag! 'authenticationTransactionID', options[:authentication_transaction_id] if options[:authentication_transaction_id]
          xml.tag! 'referenceID', options[:reference_id] if options[:reference_id]
        end if options[:payer_auth_enroll_service]

        if options[:payer_auth_validate_service]
          xml.tag! 'payerAuthValidateService', {'run' => 'true'} do
            xml.tag! 'signedPARes', options[:pares] if options[:pares]
            xml.tag! 'authenticationTransactionID', options[:authentication_transaction_id] if options[:authentication_transaction_id]
          end
        end
      end

      def lookup_country_code(country_field)
        country_code = Country.find(country_field) rescue nil
        country_code&.code(:alpha2)
      end

      # Temporary fix, revert and cherry-pick commits from the upstream AM
      def add_stored_credential_subsequent_auth(xml, options = {})
        return unless options[:stored_credential]

        xml.tag! 'subsequentAuth', 'true' if options.dig(:stored_credential, :initiator) == 'merchant'
      end

      # Temporary fix, revert and cherry-pick commits from the upstream AM
      def add_stored_credential_options(xml, options = {})
        return unless options[:stored_credential]

        xml.tag! 'subsequentAuthFirst', 'true' if options.dig(:stored_credential, :initial_transaction)
        network_transaction_id = options.dig(:stored_credential, :network_transaction_id)

        xml.tag! 'subsequentAuthTransactionID', network_transaction_id if network_transaction_id && options.dig(:stored_credential, :initiator) == 'merchant'
      end

      # Where we actually build the full SOAP request using builder
      def build_request(body, options)
        xml = Builder::XmlMarkup.new :indent => 2
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
          xml.tag! 's:Body', {
            'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
            'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
            'xmlns:wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd',
            'wsu:Id' => 'Body'
          } do
            xml.tag! 'requestMessage', { 'xmlns' => "urn:schemas-cybersource-com:transaction-data-#{XSD_VERSION}" } do
              add_merchant_data(xml, options)
              xml << body
            end
          end
        end
        if @options[:p12_certificate].present? && @options[:p12_certificate_password].present?
          doc = parse_xml(xml)
          security_element = initialize_security_element(doc)
          add_security_token(doc, security_element)
          signature_element = create_signature_element(doc, security_element)
          sign_info = build_and_add_signed_info(doc, signature_element)
          sign_and_add_signature_value(doc, signature_element, sign_info)
          add_key_information(doc, signature_element)
          doc.to_xml
        else
          xml.target!
        end
      end

      def parse_xml(xml)
        Nokogiri::XML(xml.target!)
      end

      def initialize_security_element(doc)
        security_element = doc.at_xpath('//wsse:Security', 'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd')
        security_element.children.remove
        security_element
      end

      def add_security_token(doc, security_element)
        token_element = generate_security_token(doc)
        security_element.add_child(token_element)
      end

      def create_signature_element(doc, security_element)
        signature_element = doc.create_element('ds:Signature')
        signature_element.add_namespace('ds', DS_NS)
        security_element.add_child(signature_element)
        signature_element
      end

      def build_and_add_signed_info(doc, signature_element)
        sign_info = build_signed_info(doc, ['Body'])
        signature_element.add_child(sign_info)
        sign_info
      end

      def sign_and_add_signature_value(doc, signature_element, sign_info)
        signature = @private_key.sign(
          OpenSSL::Digest.new('SHA256'),
          canonicalize_node(sign_info)
        )
        signature_value = doc.create_element('ds:SignatureValue')
        signature_value.content = Base64.strict_encode64(signature)
        signature_element.add_child(signature_value)
      end

      def add_key_information(doc, signature_element)
        key_info = doc.create_element('ds:KeyInfo')
        security_token_reference = doc.create_element('wsse:SecurityTokenReference')
        reference = doc.create_element('wsse:Reference')
        reference['URI'] = '#X509Token'
        security_token_reference.add_child(reference)
        key_info.add_child(security_token_reference)
        signature_element.add_child(key_info)
      end

      def generate_security_token(doc)
        decoded_p12_cert =  Base64.decode64(@options[:p12_certificate])
        cert = OpenSSL::PKCS12.new(decoded_p12_cert, @options[:p12_certificate_password])
        @private_key = cert.key
        certificate = cert.certificate.to_pem

        pubcert_lines = certificate.lines.map(&:strip) # Split and trim each line
        pubcert_lines.shift # Remove "-----BEGIN CERTIFICATE-----"
        pubcert_lines.pop while pubcert_lines.last.to_s.strip.empty? # Remove empty lines
        pubcert_lines.pop if pubcert_lines.last == '-----END CERTIFICATE-----' # Remove "-----END CERTIFICATE-----"
        pub_cert = pubcert_lines.join # Join without line breaks

        token = doc.create_element('wsse:BinarySecurityToken', pub_cert)
        token['xmlns:wsse'] = WSSE_NS
        token['ValueType'] = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3'
        token['EncodingType'] = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary'
        token['wsu:Id'] = 'X509Token'
        token.set_attribute('xmlns:wsu', WSU_NS)
        token
      rescue OpenSSL::PKCS12::PKCS12Error => e
        raise ArgumentError, "Invalid p12 certificate or password provided: #{e.message}"
      end

      def build_signed_info(dom_document, ids)
        xpath = Nokogiri::XML::XPathContext.new(dom_document)
        xpath.register_ns('SOAP-ENV', SOAP_NS)
        xpath.register_ns('wsu', WSU_NS)
        xpath.register_ns('wsse', WSSE_NS)
        xpath.register_ns('ds', DS_NS)

        signed_info = Nokogiri::XML::Node.new('ds:SignedInfo', dom_document)
        signed_info.add_namespace_definition('ds', DS_NS)

        canonicalization_method = Nokogiri::XML::Node.new('ds:CanonicalizationMethod', dom_document)
        canonicalization_method['Algorithm'] = 'http://www.w3.org/2001/10/xml-exc-c14n#'
        signed_info.add_child(canonicalization_method)

        signature_method = Nokogiri::XML::Node.new('ds:SignatureMethod', dom_document)
        signature_method['Algorithm'] = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
        signed_info.add_child(signature_method)

        ids.each do |id|
          nodes = xpath.evaluate("//*[(@wsu:Id='#{id}')]")
          next if nodes.empty?

          node = nodes.first
          canonicalized = canonicalize_node(node)

          reference_element = Nokogiri::XML::Node.new('ds:Reference', dom_document)
          reference_element['URI'] = "##{id}"

          transforms = Nokogiri::XML::Node.new('ds:Transforms', dom_document)
          transform_element = Nokogiri::XML::Node.new('ds:Transform', dom_document)
          transform_element['Algorithm'] = 'http://www.w3.org/2001/10/xml-exc-c14n#'
          transforms.add_child(transform_element)
          reference_element.add_child(transforms)

          digest_method = Nokogiri::XML::Node.new('ds:DigestMethod', dom_document)
          digest_method['Algorithm'] = 'http://www.w3.org/2001/04/xmlenc#sha256'
          reference_element.add_child(digest_method)

          digest_value = Digest::SHA256.digest(canonicalized)
          digest_value_node = Nokogiri::XML::Node.new('ds:DigestValue', dom_document)
          digest_value_node.content = Base64.strict_encode64(digest_value)
          reference_element.add_child(digest_value_node)

          signed_info.add_child(reference_element)
        end
        signed_info
      end

      def canonicalize_node(node)
        node.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
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

        success = response[:decision] == 'ACCEPT'

        response_code = ('r' + response.fetch(:reasonCode,'')).to_sym
        # CyberSource sometimes returns a REJECT with reason_code 100.
        # Set message to 'Failure' instead of 'Successful transaction' in that case.
        message = (!success && response_code == :r100) ? "Failure" : @@response_codes[response_code] rescue response[:message]

        # if a <soap::Fault> is in the return xml there wont be a reasonCode
        if !success && @@response_codes[response_code].nil?
          message = response[:message]
        end

        authorization = success ? authorization_from(response, action, amount, options) : nil

        Response.new(success, message, response,
          :test => test?,
          :authorization => authorization,
          :avs_result => { :code => response[:avsCode] },
          :cvv_result => response[:cvCode]
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
          if node.parent.name =~ /item/
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
    end
  end
end
