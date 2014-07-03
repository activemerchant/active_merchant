require 'i18n/core_ext/string/interpolate'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # For more information on the Vindicia Gateway please visit their {website}[http://vindicia.com/]
    #
    # The login and password are not the username and password you use to
    # login to the Vindicia Merchant Portal.
    #
    # ==== Recurring Billing
    #
    # AutoBills are an feature of Vindicia's API that allows for creating and managing subscriptions.
    #
    # For more information about Vindicia's API and various other services visit their {Resource Center}[http://www.vindicia.com/resources/index.html]
    class VindiciaGateway < Gateway
      self.supported_countries = %w{US CA GB AU MX BR DE KR CN HK}
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.vindicia.com/'
      self.display_name = 'Vindicia'

      class_attribute :test_url, :live_url

      self.test_url = "https://soap.prodtest.sj.vindicia.com/soap.pl"
      self.live_url = "http://soap.vindicia.com/soap.pl"

      # Creates a new VindiciaGateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- Vindicia SOAP login (REQUIRED)
      # * <tt>:password</tt> -- Vindicia SOAP password (REQUIRED)
      # * <tt>:api_version</tt> -- Vindicia API Version - defaults to 3.6 (OPTIONAL)
      # * <tt>:account_id</tt> -- Account Id which all transactions will be run against. (REQUIRED)
      # * <tt>:transaction_prefix</tt> -- Prefix to order id for one-time transactions - defaults to 'X' (OPTIONAL
      # * <tt>:min_chargeback_probability</tt> -- Minimum score for chargebacks - defaults to 65 (OPTIONAL)
      # * <tt>:cvn_success</tt> -- Array of valid CVN Check return values - defaults to [M, P] (OPTIONAL)
      # * <tt>:avs_success</tt> -- Array of valid AVS Check return values - defaults to [X, Y, A, W, Z] (OPTIONAL)
      def initialize(options = {})
        requires!(options, :login, :password, :account_id)
        super

        @account_id = options[:account_id]

        @transaction_prefix = options[:transaction_prefix] || "X"

        @min_chargeback_probability = options[:min_chargeback_probability] || 65
        @cvn_success = options[:cvn_success] || %w{M P}
        @avs_success = options[:avs_success] || %w{X Y A W Z}

        @allowed_authorization_statuses = %w{Authorized}
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, creditcard, options = {})
        response = authorize(money, creditcard, options)
        return response if !response.success? || response.fraud_review?

        capture(money, response.authorization, options)
      end

      # Performs an authorization, which reserves the funds on the customer's credit card, but does not
      # charge the card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, creditcard, options = {})
        vindicia_transaction = authorize_transaction(money, creditcard, options)
        response = check_transaction(vindicia_transaction)

        # if this response is under fraud review because of our AVS/CVV checks void the transaction
        if !response.success? && response.fraud_review? && !response.authorization.blank?
          void_response = void([vindicia_transaction[:transaction][:merchantTransactionId]], options)
          if void_response.success?
            return response
          else
            return void_response
          end
        end

        response
      end

      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>identification</tt> -- The authorization returned from the previous authorize request.
      def capture(money, identification, options = {})
        response = post(:capture) do |xml|
          add_hash(xml, transactions: [{ merchantTransactionId: identification }])
        end

        if response[:return][:returnCode] != '200' || response[:qtyFail].to_i > 0
          return fail(response)
        end

        success(response, identification)
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>identification</tt> - The authorization returned from the previous authorize request.
      # * <tt>options</tt> - Extra options (currently only :ip used)
      def void(identification, options = {})
        response = post(:cancel) do |xml|
          add_hash(xml, transactions: [{
            account: {merchantAccountId: @account_id},
            merchantTransactionId: identification,
            sourceIp: options[:ip]
          }])
        end

        if response[:return][:returnCode] == '200' && response[:qtyFail].to_i == 0
          success(response, identification)
        else
          fail(response)
        end
      end

      # Perform a recurring billing, which is essentially a purchase and autobill setup in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:product_sku</tt> -- The subscription product's sku
      # * <tt>:autobill_prefix</tt> -- Prefix to order id for subscriptions - defaults to 'A' (OPTIONAL)
      def recurring(money, creditcard, options={})
        ActiveMerchant.deprecated RECURRING_DEPRECATION_MESSAGE

        options[:recurring] = true
        @autobill_prefix = options[:autobill_prefix] || "A"

        response = authorize(money, creditcard, options)
        return response if !response.success? || response.fraud_review?

        capture_resp = capture(money, response.authorization, options)
        return capture_resp if !response.success?

        # Setting up a recurring AutoBill requires an associated product
        requires!(options, :product_sku)
        autobill_response = check_subscription(authorize_subscription(options.merge(:product_sku => options[:product_sku])))

        if autobill_response.success?
          autobill_response
        else
          # If the AutoBill fails to set-up, void the transaction and return it as the response
          void_response = void(capture_resp.authorization, options)
          if void_response.success?
            return autobill_response
          else
            return void_response
          end
        end
      end

      private

      def add_hash(xml, hash)
        hash.each do |k,v|
          add_element(xml, k, v)
        end
      end

      def add_array(xml, elem, val)
        val.each do |v|
          add_element(xml, elem, v)
        end
      end

      def add_element(xml, elem, val)
        if val.is_a?(Hash)
          xml.tag!(elem.to_s.camelize(:lower)) do |env|
            add_hash(env, val)
          end
        elsif val.is_a?(Array)
          add_array(xml, elem, val)
        else
          xml.tag!(elem.to_s.camelize(:lower), val.to_s)
        end
      end

      def post(action, kind="Transaction")
        xml = Builder::XmlMarkup.new
        xml.instruct!(:xml, :encoding => "UTF-8")
        xml.env :Envelope,
          "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
          "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
          "xmlns:tns" => "http://soap.vindicia.com/v3_6/#{kind}",
          "xmlns:env" => "http://schemas.xmlsoap.org/soap/envelope/" do

          xml.env :Body do
            xml.tns action.to_sym do
              xml.auth do
                xml.tag! :login, @options[:login]
                xml.tag! :password, @options[:password]
                xml.tag! :version, "3.6"
              end

              yield(xml)
            end
          end
        end

        url = (test? ? self.test_url : self.live_url)
        parse(ssl_post(url, xml.target!, "Content-Type" => "text/xml"))
      end

      def parse(response)
        # Vindicia always returns in the form of request_type_response => { actual_response }
        Hash.from_xml(response)["Envelope"]["Body"].values.first.with_indifferent_access
      end

      def check_transaction(vindicia_transaction)
        if vindicia_transaction[:return][:returnCode] == '200'
          status_log = vindicia_transaction[:transaction][:statusLog].first
          if status_log[:creditCardStatus]
            avs = status_log[:creditCardStatus][:avsCode]
            cvn = status_log[:creditCardStatus][:cvnCode]
          end

          if @allowed_authorization_statuses.include?(status_log[:status]) &&
            check_cvn(cvn) && check_avs(avs)

            success(vindicia_transaction,
                    vindicia_transaction[:transaction][:merchantTransactionId],
                    avs, cvn)
          else
            # If the transaction is authorized, but it didn't pass our AVS/CVV checks send the authorization along so
            # that is gets voided. Otherwise, send no authorization.
            fail(vindicia_transaction, avs, cvn, false,
                 @allowed_authorization_statuses.include?(status_log[:status]) ? vindicia_transaction[:transaction][:merchantTransactionId] : "")
          end
        else
          # 406 = Chargeback risk score is higher than minChargebackProbability, transaction not authorized.
          fail(vindicia_transaction, nil, nil, vindicia_transaction[:return][:return_code] == '406')
        end
      end

      def authorize_transaction(money, creditcard, options)
        parameters = {
          :amount => amount(money),
          :currency => options[:currency] || currency(money)
        }

        add_account_data(parameters, options)
        add_customer_data(parameters, options)
        add_payment_source(parameters, creditcard, options)

        post(:auth) do |xml|
          add_hash(xml, transaction: parameters, minChargebackProbability: @min_chargeback_probability)
        end
      end

      def add_account_data(parameters, options)
        parameters[:account] = { :merchantAccountId => @account_id }
        parameters[:sourceIp] = options[:ip] if options[:ip]
      end

      def add_customer_data(parameters, options)
        parameters[:merchantTransactionId] = transaction_id(options[:order_id])
        parameters[:shippingAddress] = convert_am_address_to_vindicia(options[:shipping_address])

        # Transaction items must be provided for tax purposes
        requires!(options, :line_items)
        parameters[:transactionItems] = options[:line_items]

        if options[:recurring]
          parameters[:nameValues] = [{:name => 'merchantAutoBillIdentifier', :value => autobill_id(options[:order_id])}]
        end
      end

      def add_payment_source(parameters, creditcard, options)
        parameters[:sourcePaymentMethod] = {
          :type => 'CreditCard',
          :creditCard => { :account => creditcard.number, :expirationDate => "%4d%02d" % [creditcard.year, creditcard.month] },
          :accountHolderName => creditcard.name,
          :nameValues => [{ :name => 'CVN', :value => creditcard.verification_value }],
          :billingAddress => convert_am_address_to_vindicia(options[:billing_address] || options[:address]),
          :customerSpecifiedType => creditcard.brand.capitalize,
          :active => !!options[:recurring]
        }
      end

      def authorize_subscription(options)
        parameters = {}

        add_account_data(parameters, options)
        add_subscription_information(parameters, options)

        post(:update, "AutoBill") do |xml|
          add_hash(xml, autobill: parameters, validatePaymentMethod: false, minChargebackProbability: 100)
        end
      end

      def check_subscription(vindicia_transaction)
        if vindicia_transaction[:return][:returnCode] == '200'
          if vindicia_transaction[:autobill] && vindicia_transaction[:autobill][:status] == "Active"
            success(vindicia_transaction,
                    vindicia_transaction[:autobill][:merchantAutoBillId])
          else
            fail(vindicia_transaction)
          end
        else
          fail(vindicia_transaction)
        end
      end

      def add_subscription_information(parameters, options)
        requires!(options, :product_sku)

        if options[:shipping_address]
          parameters[:account][:shipping_address] = options[:shipping_address]
        end

        parameters[:merchantAutoBillId] = autobill_id(options[:order_id])
        parameters[:product] = { :merchantProductId => options[:product_sku] }
      end

      def check_avs(avs)
        avs.blank? || @avs_success.include?(avs)
      end

      def check_cvn(cvn)
        cvn.blank? || @cvn_success.include?(cvn)
      end

      def success(response, authorization, avs_code = nil, cvn_code = nil)
        ActiveMerchant::Billing::Response.new(true, response[:return][:returnString], response,
                                              { :fraud_review => false, :authorization => authorization, :test => test?,
                                                :avs_result => { :code => avs_code }, :cvv_result => cvn_code })
      end

      def fail(response, avs_code = nil, cvn_code = nil, fraud_review = false, authorization = "")
        ActiveMerchant::Billing::Response.new(false, response[:return][:returnString], response,
                                              { :fraud_review => fraud_review || !authorization.blank?,
                                                :authorization => authorization, :test => test?,
                                                :avs_result => { :code => avs_code }, :cvv_result => cvn_code })

      end

      def autobill_id(order_id)
        "#{@autobill_prefix}#{order_id}"
      end

      def transaction_id(order_id)
        "#{@transaction_prefix}#{order_id}"
      end

      # Converts valid ActiveMerchant address hash to proper Vindicia format
      def convert_am_address_to_vindicia(address)
        return if address.nil?

        convs = { :address1 => :addr1, :address2 => :addr2,
          :state => :district, :zip => :postalCode }

        vindicia_address = {}
        address.each do |key, val|
          vindicia_address[convs[key] || key] = val
        end
        vindicia_address
      end
    end
  end
end
