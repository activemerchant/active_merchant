module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # See the remote and mocked unit test files for example usage.  Pay special
    # attention to the contents of the options hash.
    #
    # Initial setup instructions can be found in
    # http://cybersource.com/support_center/implementation/downloads/soap_api/SOAP_toolkits.pdf
    #
    # Debugging
    # If you experience an issue with this gateway be sure to examine the
    # transaction information from a general transaction search inside the
    # CyberSource Business Center for the full error messages including field
    # names.
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
    class CyberSourceGateway < Gateway
      self.test_url = 'https://ics2wstest.ic3.com/commerce/1.x/transactionProcessor'
      self.live_url = 'https://ics2ws.ic3.com/commerce/1.x/transactionProcessor'

      XSD_VERSION = "1.69"

      # visa, master, american_express, discover
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.supported_countries = %w(US BR CA CN DK FI FR DE JP MX NO SE GB SG)
      self.default_currency = 'USD'
      self.homepage_url = 'http://www.cybersource.com'
      self.display_name = 'CyberSource'

      # map credit card to the CyberSource expected representation
      @@credit_card_codes = {
        :visa  => '001',
        :master => '002',
        :american_express => '003',
        :discover => '004'
      }

      # map response codes to something humans can read
      @@response_codes = {
        :r100 => "Successful transaction",
        :r101 => "Request is missing one or more required fields" ,
        :r102 => "One or more fields contains invalid data",
        :r150 => "General failure",
        :r151 => "The request was received but a server time-out occurred",
        :r152 => "The request was received, but a service timed out",
        :r200 => "The authorization request was approved by the issuing bank but declined by CyberSource because it did not pass the AVS check",
        :r201 => "The issuing bank has questions about the request",
        :r202 => "Expired card",
        :r203 => "General decline of the card",
        :r204 => "Insufficient funds in the account",
        :r205 => "Stolen or lost card",
        :r207 => "Issuing bank unavailable",
        :r208 => "Inactive card or card not authorized for card-not-present transactions",
        :r209 => "American Express Card Identifiction Digits (CID) did not match",
        :r210 => "The card has reached the credit limit",
        :r211 => "Invalid card verification number",
        :r221 => "The customer matched an entry on the processor's negative file",
        :r230 => "The authorization request was approved by the issuing bank but declined by CyberSource because it did not pass the card verification check",
        :r231 => "Invalid account number",
        :r232 => "The card type is not accepted by the payment processor",
        :r233 => "General decline by the processor",
        :r234 => "A problem exists with your CyberSource merchant configuration",
        :r235 => "The requested amount exceeds the originally authorized amount",
        :r236 => "Processor failure",
        :r237 => "The authorization has already been reversed",
        :r238 => "The authorization has already been captured",
        :r239 => "The requested transaction amount must match the previous transaction amount",
        :r240 => "The card type sent is invalid or does not correlate with the credit card number",
        :r241 => "The request ID is invalid",
        :r242 => "You requested a capture, but there is no corresponding, unused authorization record.",
        :r243 => "The transaction has already been settled or reversed",
        :r244 => "The bank account number failed the validation check",
        :r246 => "The capture or credit is not voidable because the capture or credit information has already been submitted to your processor",
        :r247 => "You requested a credit for a capture that was previously voided",
        :r250 => "The request was received, but a time-out occurred with the payment processor",
        :r254 => "Your CyberSource account is prohibited from processing stand-alone refunds",
        :r255 => "Your CyberSource account is not configured to process the service in the country you specified"
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

      # Request an authorization for an amount from CyberSource
      #
      # You must supply an :order_id in the options hash
      def authorize(money, creditcard_or_reference, options = {})
        requires!(options,  :order_id)
        setup_address_hash(options)
        commit(build_auth_request(money, creditcard_or_reference, options), options )
      end

      def auth_reversal(money, identification, options = {})
        commit(build_auth_reversal_request(money, identification, options), options)
      end

      # Capture an authorization that has previously been requested
      def capture(money, authorization, options = {})
        setup_address_hash(options)
        commit(build_capture_request(money, authorization, options), options)
      end

      # Purchase is an auth followed by a capture
      # You must supply an order_id in the options hash
      # options[:pinless_debit_card] => true # attempts to process as pinless debit card
      def purchase(money, payment_method_or_reference, options = {})
        requires!(options, :order_id)
        setup_address_hash(options)
        commit(build_purchase_request(money, payment_method_or_reference, options), options)
      end

      def void(identification, options = {})
        commit(build_void_request(identification, options), options)
      end

      def refund(money, identification, options = {})
        commit(build_refund_request(money, identification, options), options)
      end

      # Adds credit to a subscription (stand alone credit).
      def credit(money, reference, options = {})
        requires!(options, :order_id)
        commit(build_credit_request(money, reference, options), options)
      end

      # Stores a customer subscription/profile with type "on-demand".
      # To charge the card while creating a profile, pass
      # options[:setup_fee] => money
      def store(payment_method, options = {})
        requires!(options, :order_id)
        setup_address_hash(options)
        commit(build_create_subscription_request(payment_method, options), options)
      end

      # Updates a customer subscription/profile
      def update(reference, creditcard, options = {})
        requires!(options, :order_id)
        setup_address_hash(options)
        commit(build_update_subscription_request(reference, creditcard, options), options)
      end

      # Removes a customer subscription/profile
      def unstore(reference, options = {})
        requires!(options, :order_id)
        commit(build_delete_subscription_request(reference, options), options)
      end

      # Retrieves a customer subscription/profile
      def retrieve(reference, options = {})
        requires!(options, :order_id)
        commit(build_retrieve_subscription_request(reference, options), options)
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
        commit(build_tax_calculation_request(creditcard, options), options)
      end

      # Determines if a card can be used for Pinless Debit Card transactions
      def validate_pinless_debit_card(creditcard, options = {})
        requires!(options, :order_id)
        commit(build_validate_pinless_debit_request(creditcard,options), options)
      end

      private

      # Create all address hash key value pairs so that we still function if we
      # were only provided with one or two of them
      def setup_address_hash(options)
        options[:billing_address] = options[:billing_address] || options[:address] || {}
        options[:shipping_address] = options[:shipping_address] || {}
      end

      def build_auth_request(money, creditcard_or_reference, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_payment_method_or_subscription(xml, money, creditcard_or_reference, options)
        add_auth_service(xml)
        add_business_rules_data(xml)
        xml.target!
      end

      def build_tax_calculation_request(creditcard, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_address(xml, creditcard, options[:billing_address], options, false)
        add_address(xml, creditcard, options[:shipping_address], options, true)
        add_line_item_data(xml, options)
        add_purchase_data(xml, 0, false, options)
        add_tax_service(xml)
        add_business_rules_data(xml)
        xml.target!
      end

      def build_capture_request(money, authorization, options)
        order_id, request_id, request_token = authorization.split(";")
        options[:order_id] = order_id

        xml = Builder::XmlMarkup.new :indent => 2
        add_purchase_data(xml, money, true, options)
        add_capture_service(xml, request_id, request_token)
        add_business_rules_data(xml)
        xml.target!
      end

      def build_purchase_request(money, payment_method_or_reference, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_payment_method_or_subscription(xml, money, payment_method_or_reference, options)
        if !payment_method_or_reference.is_a?(String) && card_brand(payment_method_or_reference) == 'check'
          add_check_service(xml)
        else
          add_purchase_service(xml, options)
          add_business_rules_data(xml) unless options[:pinless_debit_card]
        end
        xml.target!
      end

      def build_void_request(identification, options)
        order_id, request_id, request_token = identification.split(";")
        options[:order_id] = order_id

        xml = Builder::XmlMarkup.new :indent => 2
        add_void_service(xml, request_id, request_token)
        xml.target!
      end

      def build_auth_reversal_request(money, identification, options)
        order_id, request_id, request_token = identification.split(";")
        options[:order_id] = order_id
        xml = Builder::XmlMarkup.new :indent => 2
        add_purchase_data(xml, money, true, options)
        add_auth_reversal_service(xml, request_id, request_token)
        xml.target!
      end

      def build_refund_request(money, identification, options)
        order_id, request_id, request_token = identification.split(";")
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
        default_subscription_params = {:frequency => "on-demand", :amount => 0, :automatic_renew => false}
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
            add_check_service(xml, options)
          else
            add_purchase_service(xml, options)
          end
        end
        add_subscription_create_service(xml, options)
        add_business_rules_data(xml)
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
        add_business_rules_data(xml)
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

      def build_validate_pinless_debit_request(creditcard,options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_creditcard(xml, creditcard)
        add_validate_pinless_debit_service(xml)
        xml.target!
      end

      def add_business_rules_data(xml)
        xml.tag! 'businessRules' do
          xml.tag!('ignoreAVSResult', 'true') if @options[:ignore_avs]
          xml.tag!('ignoreCVResult', 'true') if @options[:ignore_cvv]
        end
      end

      def add_line_item_data(xml, options)
        options[:line_items].each_with_index do |value, index|
          xml.tag! 'item', {'id' => index} do
            xml.tag! 'unitPrice', amount(value[:declared_value])
            xml.tag! 'quantity', value[:quantity]
            xml.tag! 'productCode', value[:code] || 'shipping_only'
            xml.tag! 'productName', value[:description]
            xml.tag! 'productSKU', value[:sku]
          end
        end
      end

      def add_merchant_data(xml, options)
        xml.tag! 'merchantID', @options[:login]
        xml.tag! 'merchantReferenceCode', options[:order_id]
        xml.tag! 'clientLibrary' ,'Ruby Active Merchant'
        xml.tag! 'clientLibraryVersion',  VERSION
        xml.tag! 'clientEnvironment' , RUBY_PLATFORM
      end

      def add_purchase_data(xml, money = 0, include_grand_total = false, options={})
        xml.tag! 'purchaseTotals' do
          xml.tag! 'currency', options[:currency] || currency(money)
          xml.tag!('grandTotalAmount', amount(money))  if include_grand_total
        end
      end

      def add_address(xml, payment_method, address, options, shipTo = false)
        xml.tag! shipTo ? 'shipTo' : 'billTo' do
          xml.tag! 'firstName',             payment_method.first_name             if payment_method
          xml.tag! 'lastName',              payment_method.last_name              if payment_method
          xml.tag! 'street1',               address[:address1]
          xml.tag! 'street2',               address[:address2]                unless address[:address2].blank?
          xml.tag! 'city',                  address[:city]
          xml.tag! 'state',                 address[:state]
          xml.tag! 'postalCode',            address[:zip]
          xml.tag! 'country',               address[:country]
          xml.tag! 'company',               address[:company]                 unless address[:company].blank?
          xml.tag! 'companyTaxID',          address[:companyTaxID]            unless address[:company_tax_id].blank?
          xml.tag! 'phoneNumber',           address[:phone]                   unless address[:phone].blank?
          xml.tag! 'email',                 options[:email]
          xml.tag! 'driversLicenseNumber',  options[:drivers_license_number]  unless options[:drivers_license_number].blank?
          xml.tag! 'driversLicenseState',   options[:drivers_license_state]   unless options[:drivers_license_state].blank?
        end
      end

      def add_creditcard(xml, creditcard)
        xml.tag! 'card' do
          xml.tag! 'accountNumber', creditcard.number
          xml.tag! 'expirationMonth', format(creditcard.month, :two_digits)
          xml.tag! 'expirationYear', format(creditcard.year, :four_digits)
          xml.tag!('cvNumber', creditcard.verification_value) unless (@options[:ignore_cvv] || creditcard.verification_value.blank? )
          xml.tag! 'cardType', @@credit_card_codes[card_brand(creditcard).to_sym]
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

      def add_auth_service(xml)
        xml.tag! 'ccAuthService', {'run' => 'true'}
      end

      def add_capture_service(xml, request_id, request_token)
        xml.tag! 'ccCaptureService', {'run' => 'true'} do
          xml.tag! 'authRequestID', request_id
          xml.tag! 'authRequestToken', request_token
        end
      end

      def add_purchase_service(xml, options)
        if options[:pinless_debit_card]
          xml.tag! 'pinlessDebitService', {'run' => 'true'}
        else
          xml.tag! 'ccAuthService', {'run' => 'true'}
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
            _, subscription_id, _ = reference.split(";")
            xml.tag! 'subscriptionID',  subscription_id
          end

          xml.tag! 'status',            options[:subscription][:status]                         if options[:subscription][:status]
          xml.tag! 'amount',            options[:subscription][:amount]                         if options[:subscription][:amount]
          xml.tag! 'numberOfPayments',  options[:subscription][:occurrences]                    if options[:subscription][:occurrences]
          xml.tag! 'automaticRenew',    options[:subscription][:automatic_renew]                if options[:subscription][:automatic_renew]
          xml.tag! 'frequency',         options[:subscription][:frequency]                      if options[:subscription][:frequency]
          xml.tag! 'startDate',         options[:subscription][:start_date].strftime("%Y%m%d")  if options[:subscription][:start_date]
          xml.tag! 'endDate',           options[:subscription][:end_date].strftime("%Y%m%d")    if options[:subscription][:end_date]
          xml.tag! 'approvalRequired',  options[:subscription][:approval_required] || false
          xml.tag! 'event',             options[:subscription][:event]                          if options[:subscription][:event]
          xml.tag! 'billPayment',       options[:subscription][:bill_payment]                   if options[:subscription][:bill_payment]
        end
      end

      def add_creditcard_payment_method(xml)
        xml.tag! 'subscription' do
          xml.tag! 'paymentMethod', "credit card"
        end
      end

      def add_check_payment_method(xml)
        xml.tag! 'subscription' do
          xml.tag! 'paymentMethod', "check"
        end
      end

      def add_payment_method_or_subscription(xml, money, payment_method_or_reference, options)
        if payment_method_or_reference.is_a?(String)
          add_purchase_data(xml, money, true, options)
          add_subscription(xml, options, payment_method_or_reference)
        elsif card_brand(payment_method_or_reference) == 'check'
          add_address(xml, payment_method_or_reference, options[:billing_address], options)
          add_purchase_data(xml, money, true, options)
          add_check(xml, payment_method_or_reference)
        else
          add_address(xml, payment_method_or_reference, options[:billing_address], options)
          add_purchase_data(xml, money, true, options)
          add_creditcard(xml, payment_method_or_reference)
        end
      end

      def add_validate_pinless_debit_service(xml)
        xml.tag!'pinlessDebitValidateService', {'run' => 'true'}
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
            xml.tag! 's:Body', {'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'} do
              xml.tag! 'requestMessage', {'xmlns' => "urn:schemas-cybersource-com:transaction-data-#{XSD_VERSION}"} do
                add_merchant_data(xml, options)
                xml << body
              end
            end
          end
        xml.target!
      end

      # Contact CyberSource, make the SOAP request, and parse the reply into a
      # Response object
      def commit(request, options)
        response = parse(ssl_post(test? ? self.test_url : self.live_url, build_request(request, options)))

        success = response[:decision] == "ACCEPT"
        message = @@response_codes[('r' + response[:reasonCode]).to_sym] rescue response[:message]
        authorization = success ? [ options[:order_id], response[:requestID], response[:requestToken] ].compact.join(";") : nil

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
        if root = REXML::XPath.first(xml, "//c:replyMessage")
          root.elements.to_a.each do |node|
            case node.name
            when 'c:reasonCode'
              reply[:message] = reply(node.text)
            else
              parse_element(reply, node)
            end
          end
        elsif root = REXML::XPath.first(xml, "//soap:Fault")
          parse_element(reply, root)
          reply[:message] = "#{reply[:faultcode]}: #{reply[:faultstring]}"
        end
        return reply
      end

      def parse_element(reply, node)
        if node.has_elements?
          node.elements.each{|e| parse_element(reply, e) }
        else
          if node.parent.name =~ /item/
            parent = node.parent.name + (node.parent.attributes["id"] ? "_" + node.parent.attributes["id"] : '')
            reply[(parent + '_' + node.name).to_sym] = node.text
          else
            reply[node.name.to_sym] = node.text
          end
        end
        return reply
      end
    end
  end
end
