require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EwayRapidGateway < Gateway
      self.test_url = "https://api.sandbox.ewaypayments.com/"
      self.live_url = "https://api.ewaypayments.com/"

      self.money_format = :cents
      self.supported_countries = ["AU"]
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      self.homepage_url = "http://www.eway.com.au/"
      self.display_name = "eWAY Rapid 3.1"
      self.default_currency = "AUD"

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      # Public: Run a purchase transaction.
      #
      # amount         - The monetary amount of the transaction in cents.
      # payment_method - The payment method or nil if :customer_token is provided
      # options        - A standard ActiveMerchant options hash:
      #                  :transaction_type - One of: Purchase (default), MOTO
      #                                      or Recurring
      #                  :order_id         - A merchant-supplied identifier for the
      #                                      transaction (optional).
      #                  :customer_token   - The customer token to use for TokenPayments (optional).
      #                  :description      - A merchant-supplied description of the
      #                                      transaction (optional).
      #                  :currency         - Three letter currency code for the
      #                                      transaction (default: "AUD")
      #                  :billing_address  - Standard ActiveMerchant address hash
      #                                      (optional).
      #                  :shipping_address - Standard ActiveMerchant address hash
      #                                      (optional).
      #                  :ip               - The ip of the consumer initiating the
      #                                      transaction (optional).
      #                  :application_id   - A string identifying the application
      #                                      submitting the transaction
      #                                      (default: "https://github.com/Shopify/active_merchant")
      #
      # Returns an ActiveMerchant::Billing::Response object where authorization is set to the Transaction ID
      def purchase(amount, payment_method, options={})
        method = options[:customer_token] ? 'TokenPayment' : 'ProcessPayment'
        params = {}
        add_metadata(params, options)
        add_invoice(params, amount, options)
        add_customer_data(params, payment_method, options)
        commit(url_for('Transaction'), params)
      end

      # Public: Refund a transaction.
      #
      # money          - The monetary amount of the transaction in cents
      # identification - The transaction id which is returned in the
      #                  authorization of the successful purchase transaction
      # options        - A standard ActiveMerchant options hash:
      #
      # Returns an ActiveMerchant::Billing::Response object
      def refund(money, identification, options = {})
        request = build_xml_request('Refund') do |doc|
          add_metadata(doc, options)
          add_invoice(doc, money, options)
          add_customer_data(doc, payment_method, options)
        end
        commit(url_for('DirectPayment'), request)
      end

      # Public: Store card details and return a valid token
      #
      # payment_method - The payment method or nil if :customer_token is provided
      # options        - A supplemented ActiveMerchant options hash:
      #                  :order_id         - A merchant-supplied identifier for the
      #                                      transaction (optional).
      #                  :billing_address  - Standard ActiveMerchant address hash
      #                                      (required).
      #                  :ip               - The ip of the consumer initiating the
      #                                      transaction (optional).
      #                  :application_id   - A string identifying the application
      #                                      submitting the transaction
      #                                      (default: "https://github.com/Shopify/active_merchant")
      #
      # Returns an ActiveMerchant::Billing::Response object where the authorization
      # is the customer_token on success
      def store(payment_method, options = {})
        requires!(options, :billing_address)
        request = build_xml_request('CreateTokenCustomer') do |doc|
          add_metadata(doc, options)
          add_invoice(doc, 0, options)
          add_customer_data(doc, payment_method, options)
        end
        commit(url_for('DirectPayment'), request, 'customer_tokencustomerid')
      end

      # Public: Update a customer's data
      #
      # customer_token - The customer token returned in the authorization of
      #                  a successful store transaction.
      # payment_method - The payment method or nil if :customer_token is provided
      # options        - A supplemented ActiveMerchant options hash:
      #                  :order_id         - A merchant-supplied identifier for the
      #                                      transaction (optional).
      #                  :billing_address  - Standard ActiveMerchant address hash
      #                                      (optional).
      #                  :ip               - The ip of the consumer initiating the
      #                                      transaction (optional).
      #                  :application_id   - A string identifying the application
      #                                      submitting the transaction
      #                                      (default: "https://github.com/Shopify/active_merchant")
      # Returns an ActiveMerchant::Billing::Response object
      def update(customer_token, payment_method, options = {})
        request = build_xml_request('UpdateTokenCustomer') do |doc|
          add_metadata(doc, options)
          add_invoice(doc, 0, options)
          add_customer_data(doc, payment_method, options)
        end
        commit(url_for('DirectPayment'), request)
      end

      private

      def add_metadata(params, options)
        params['RedirectUrl'] = options[:redirect_url] || 'http://example.com'
        params['CustomerIP'] = options[:ip] if options[:ip]
        params['Method'] = options[:request_method] || "ProcessPayment"
        params['TransactionType'] = options[:transaction_type] || 'Purchase'
        params['DeviceID'] = options[:application_id] || application_id
      end

      def add_invoice(params, money, options)
        refund_transaction_id = options[:refund_transaction_id]
        type = refund_transaction_id ? 'Refund' : 'Payment'
        currency_code = options[:currency] || currency(money)
        params[type] = fields = {
          'TotalAmount' => localized_amount(money, currency_code),
          'InvoiceReference' => options[:order_id],
          'InvoiceDescription' => options[:description],
          'CurrencyCode' => currency_code,
        }
        # must include the original transaction id for refunds
        fields['TransactionID'] = refund_transaction_id if refund_transaction_id
      end

      def add_customer_data(params, credit_card, options)
        params['Customer'] = customer = {}
        add_address(customer, (options[:billing_address] || options[:address]), {:email => options[:email]})
        customer['CardDetails'] = card_details = {}
        add_credit_card(card_details, credit_card, options)
        params['ShippingAddress'] = shipping_address = {}
        add_address(shipping_address, options[:shipping_address], {:skip_company => true})
      end

      def add_address(params, address, options={})
        return unless address
        if name = address[:name]
          parts = name.split(/\s+/)
          params['FirstName'] = parts.shift if parts.size > 1
          params['LastName'] = parts.join(" ")
        end
        params['Title'] = address[:title]
        params['CompanyName'] = address[:company] unless options[:skip_company]
        params['Street1'] = address[:address1]
        params['Street2'] = address[:address2]
        params['City'] = address[:city]
        params['State'] = address[:state]
        params['PostalCode'] = address[:zip]
        params['Country'] = address[:country].to_s.downcase
        params['Phone'] = address[:phone]
        params['Fax'] = address[:fax]
        params['Email'] = options[:email]
      end

      def add_credit_card(params, credit_card, options)
        return unless credit_card
        params['Name'] = credit_card.name
        params['Number'] = credit_card.number
        params['ExpiryMonth'] = "%02d" % credit_card.month if credit_card.month
        params['ExpiryYear'] = "%02d" % credit_card.year if credit_card.year
        params['CVN'] = credit_card.verification_value
      end

      def url_for(action)
        (test? ? test_url : live_url) + action
      end

      def commit(url, params, authorization_type = :transaction)
        headers = {
          "Authorization" => ("Basic " + Base64.strict_encode64(@options[:login].to_s + ":" + @options[:password].to_s).chomp),
          "Content-Type" => "application/json"
        }
        request = params.to_json
        raw = parse(ssl_post(url, request, headers))

        succeeded = success?(raw)
        ActiveMerchant::Billing::Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => authorization_from(raw, authorization_type),
          :test => test?,
          :avs_result => avs_result_from(raw),
          :cvv_result => cvv_result_from(raw)
        )
      rescue ActiveMerchant::ResponseError => e
        return ActiveMerchant::Billing::Response.new(false, e.response.message, {:status_code => e.response.code}, :test => test?)
      end

      def parse(data)
        JSON.parse(data)
      end

      def success?(response)
        if response['Errors']
          false
        elsif response['ResponseCode'] == "00"
          true
        elsif response['TransactionStatus']
          (response['TransactionStatus'] == "true")
        else
          true
        end
      end

      def message_from(succeeded, response)
        if response['Errors']
          (MESSAGES[response['Errors']] || response['Errors'])
        elsif response[:responsecode]
          ActiveMerchant::Billing::EwayGateway::MESSAGES[response['ResponseCode']]
        elsif response['ResponseMessage']
          (MESSAGES[response['ResponseMessage']] || response['ResponseMessage'])
        elsif succeeded
          "Succeeded"
        else
          "Failed"
        end
      end

      def authorization_from(response, type)
        if type == :transaction
          response['TransactionID']
        elsif type == :customer_token
          response['Customer']['TokenCustomerID'] rescue nil
        else
          raise "Unknown authorization type: #{type}"
        end
      end

      def avs_result_from(response)
        code = case response[:verification_address]
        when "Valid"
          "M"
        when "Invalid"
          "N"
        else
          "I"
        end
        {:code => code}
      end

      def cvv_result_from(response)
        case response[:verification_cvn]
        when "Valid"
          "M"
        when "Invalid"
          "N"
        else
          "P"
        end
      end

      MESSAGES = {
        'V6000' => 'Validation error',
        'V6001' => 'Invalid CustomerIP',
        'V6002' => 'Invalid DeviceID',
        'V6003' => 'Invalid Request PartnerID',
        'V6004' => 'Invalid Request Method',
        'V6010' => 'Invalid TransactionType, account not certified for eCome only MOTO or Recurring available',
        'V6011' => 'Invalid Payment TotalAmount',
        'V6012' => 'Invalid Payment InvoiceDescription',
        'V6013' => 'Invalid Payment InvoiceNumber',
        'V6014' => 'Invalid Payment InvoiceReference',
        'V6015' => 'Invalid Payment CurrencyCode',
        'V6016' => 'Payment Required',
        'V6017' => 'Payment CurrencyCode Required',
        'V6018' => 'Unknown Payment CurrencyCode',
        'V6021' => 'EWAY_CARDHOLDERNAME Required',
        'V6022' => 'EWAY_CARDNUMBER Required',
        'V6023' => 'EWAY_CARDCVN Required',
        'V6033' => 'Invalid Expiry Date',
        'V6034' => 'Invalid Issue Number',
        'V6035' => 'Invalid Valid From Date',
        'V6040' => 'Invalid TokenCustomerID',
        'V6041' => 'Customer Required',
        'V6042' => 'Customer FirstName Required',
        'V6043' => 'Customer LastName Required',
        'V6044' => 'Customer CountryCode Required',
        'V6045' => 'Customer Title Required',
        'V6046' => 'TokenCustomerID Required',
        'V6047' => 'RedirectURL Required',
        'V6051' => 'Invalid Customer FirstName',
        'V6052' => 'Invalid Customer LastName',
        'V6053' => 'Invalid Customer CountryCode',
        'V6058' => 'Invalid Customer Title',
        'V6059' => 'Invalid RedirectURL',
        'V6060' => 'Invalid TokenCustomerID',
        'V6061' => 'Invalid Customer Reference',
        'V6062' => 'Invalid Customer CompanyName',
        'V6063' => 'Invalid Customer JobDescription',
        'V6064' => 'Invalid Customer Street1',
        'V6065' => 'Invalid Customer Street2',
        'V6066' => 'Invalid Customer City',
        'V6067' => 'Invalid Customer State',
        'V6068' => 'Invalid Customer PostalCode',
        'V6069' => 'Invalid Customer Email',
        'V6070' => 'Invalid Customer Phone',
        'V6071' => 'Invalid Customer Mobile',
        'V6072' => 'Invalid Customer Comments',
        'V6073' => 'Invalid Customer Fax',
        'V6074' => 'Invalid Customer URL',
        'V6075' => 'Invalid ShippingAddress FirstName',
        'V6076' => 'Invalid ShippingAddress LastName',
        'V6077' => 'Invalid ShippingAddress Street1',
        'V6078' => 'Invalid ShippingAddress Street2',
        'V6079' => 'Invalid ShippingAddress City',
        'V6080' => 'Invalid ShippingAddress State',
        'V6081' => 'Invalid ShippingAddress PostalCode',
        'V6082' => 'Invalid ShippingAddress Email',
        'V6083' => 'Invalid ShippingAddress Phone',
        'V6084' => 'Invalid ShippingAddress Country',
        'V6085' => 'Invalid ShippingAddress ShippingMethod',
        'V6086' => 'Invalid ShippingAddress Fax ',
        'V6091' => 'Unknown Customer CountryCode',
        'V6092' => 'Unknown ShippingAddress CountryCode',
        'V6100' => 'Invalid EWAY_CARDNAME',
        'V6101' => 'Invalid EWAY_CARDEXPIRYMONTH',
        'V6102' => 'Invalid EWAY_CARDEXPIRYYEAR',
        'V6103' => 'Invalid EWAY_CARDSTARTMONTH',
        'V6104' => 'Invalid EWAY_CARDSTARTYEAR',
        'V6105' => 'Invalid EWAY_CARDISSUENUMBER',
        'V6106' => 'Invalid EWAY_CARDCVN',
        'V6107' => 'Invalid EWAY_ACCESSCODE',
        'V6108' => 'Invalid CustomerHostAddress',
        'V6109' => 'Invalid UserAgent',
        'V6110' => 'Invalid EWAY_CARDNUMBER',
        'V6111' => 'Unauthorised API Access, Account Not PCI Certified'
      }
    end
  end
end
