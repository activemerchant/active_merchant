require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EwayRapidGateway < Gateway
      self.test_url = "https://api.sandbox.ewaypayments.com/"
      self.live_url = "https://api.ewaypayments.com/"

      self.money_format = :cents
      self.supported_countries = ['AU', 'NZ', 'GB']
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
      # payment_method - The payment method or authorization token returned from store.
      # options        - A standard ActiveMerchant options hash:
      #                  :transaction_type - One of: Purchase (default), MOTO
      #                                      or Recurring.  For stored card payments (aka - TokenPayments),
      #                                      this must be either MOTO or Recurring.
      #                  :order_id         - A merchant-supplied identifier for the
      #                                      transaction (optional).
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
      # Returns an ActiveMerchant::Billing::Response object where authorization is the Transaction ID on success
      def purchase(amount, payment_method, options={})
        params = {}
        add_metadata(params, options)
        add_invoice(params, amount, options)
        add_customer_data(params, options)
        add_credit_card(params, payment_method, options)
        commit(url_for('Transaction'), params)
      end

      def authorize(amount, payment_method, options={})
        params = {}
        add_metadata(params, options)
        add_invoice(params, amount, options)
        add_customer_data(params, options)
        add_credit_card(params, payment_method, options)
        commit(url_for('Authorisation'), params)
      end

      def capture(amount, identification, options = {})
        params = {}
        add_metadata(params, options)
        add_invoice(params, amount, options)
        add_reference(params, identification)
        commit(url_for("CapturePayment"), params)
      end

      def void(identification, options = {})
        params = {}
        add_reference(params, identification)
        commit(url_for("CancelAuthorisation"), params)
      end

      # Public: Refund a transaction.
      #
      # amount         - The monetary amount of the transaction in cents
      # identification - The transaction id which is returned in the
      #                  authorization of the successful purchase transaction
      # options        - A standard ActiveMerchant options hash:
      #                  :order_id         - A merchant-supplied identifier for the
      #                                      transaction (optional).
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
      # Returns an ActiveMerchant::Billing::Response object
      def refund(amount, identification, options = {})
        params = {}
        add_metadata(params, options)
        add_invoice(params, amount, options, "Refund")
        add_reference(params["Refund"], identification)
        add_customer_data(params, options)
        commit(url_for("Transaction/#{identification}/Refund"), params)
      end

      # Public: Store card details and return a valid token
      #
      # payment_method - The payment method or nil if :customer_token is provided
      # options        - A supplemented ActiveMerchant options hash:
      #                  :order_id         - A merchant-supplied identifier for the
      #                                      transaction (optional).
      #                  :description      - A merchant-supplied description of the
      #                                      transaction (optional).
      #                  :billing_address  - Standard ActiveMerchant address hash
      #                                      (required).
      #                  :ip               - The ip of the consumer initiating the
      #                                      transaction (optional).
      #                  :application_id   - A string identifying the application
      #                                      submitting the transaction
      #                                      (default: "https://github.com/Shopify/active_merchant")
      #
      # Returns an ActiveMerchant::Billing::Response object where the authorization is the customer_token on success
      def store(payment_method, options = {})
        requires!(options, :billing_address)
        params = {}
        add_metadata(params, options)
        add_invoice(params, 0, options)
        add_customer_data(params, options)
        add_credit_card(params, payment_method, options)
        params['Method'] = 'CreateTokenCustomer'
        commit(url_for("Transaction"), params)
      end

      # Public: Update a customer's data
      #
      # customer_token - The customer token returned in the authorization of
      #                  a successful store transaction.
      # payment_method - The payment method or nil if :customer_token is provided
      # options        - A supplemented ActiveMerchant options hash:
      #                  :order_id         - A merchant-supplied identifier for the
      #                                      transaction (optional).
      #                  :description      - A merchant-supplied description of the
      #                                      transaction (optional).
      #                  :billing_address  - Standard ActiveMerchant address hash
      #                                      (optional).
      #                  :ip               - The ip of the consumer initiating the
      #                                      transaction (optional).
      #                  :application_id   - A string identifying the application
      #                                      submitting the transaction
      #                                      (default: "https://github.com/Shopify/active_merchant")
      #
      # Returns an ActiveMerchant::Billing::Response object where the authorization is the customer_token on success
      def update(customer_token, payment_method, options = {})
        params = {}
        add_metadata(params, options)
        add_invoice(params, 0, options)
        add_customer_data(params, options)
        add_credit_card(params, payment_method, options)
        add_customer_token(params, customer_token)
        params['Method'] = 'UpdateTokenCustomer'
        commit(url_for("Transaction"), params)
      end

      private

      def add_metadata(params, options)
        params['RedirectUrl'] = options[:redirect_url] || 'http://example.com'
        params['CustomerIP'] = options[:ip] if options[:ip]
        params['TransactionType'] = options[:transaction_type] || 'Purchase'
        params['DeviceID'] = options[:application_id] || application_id
      end

      def add_invoice(params, money, options, key = "Payment")
        currency_code = options[:currency] || currency(money)
        params[key] = {
          'TotalAmount' => localized_amount(money, currency_code),
          'InvoiceReference' => truncate(options[:order_id]),
          'InvoiceDescription' => truncate(options[:description], 64),
          'CurrencyCode' => currency_code,
        }
      end

      def add_reference(params, reference)
        params['TransactionID'] = reference
      end

      def add_customer_data(params, options)
        params['Customer'] ||= {}
        add_address(params['Customer'], (options[:billing_address] || options[:address]), {:email => options[:email]})
        params['ShippingAddress'] = {}
        add_address(params['ShippingAddress'], options[:shipping_address], {:skip_company => true})
      end

      def add_address(params, address, options={})
        return unless address

        if address[:name]
          parts = address[:name].split(/\s+/)
          params['FirstName'] = parts.shift if parts.size > 1
          params['LastName'] = parts.join(" ")
        end
        params['Title'] = address[:title]
        params['CompanyName'] = address[:company] unless options[:skip_company]
        params['Street1'] = truncate(address[:address1])
        params['Street2'] = truncate(address[:address2])
        params['City'] = truncate(address[:city])
        params['State'] = address[:state]
        params['PostalCode'] = address[:zip]
        params['Country'] = address[:country].to_s.downcase
        params['Phone'] = address[:phone]
        params['Fax'] = address[:fax]
        params['Email'] = options[:email]
      end

      def add_credit_card(params, credit_card, options)
        return unless credit_card
        params['Customer'] ||= {}
        if credit_card.respond_to? :number
          params['Method'] = 'ProcessPayment'
          card_details = params['Customer']['CardDetails'] = {}
          card_details['Name'] = truncate(credit_card.name)
          card_details['Number'] = credit_card.number
          card_details['ExpiryMonth'] = "%02d" % (credit_card.month || 0)
          card_details['ExpiryYear'] = "%02d" % (credit_card.year || 0)
          card_details['CVN'] = credit_card.verification_value
        else
          params['Method'] = 'TokenPayment'
          add_customer_token(params, credit_card)
        end
      end

      def add_customer_token(params, token)
        params['Customer'] ||= {}
        params['Customer']['TokenCustomerID'] = token
      end

      def url_for(action)
        (test? ? test_url : live_url) + action
      end

      def commit(url, params)
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
          :authorization => authorization_from(raw),
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
        if response['ResponseCode'] == "00"
          true
        elsif response['TransactionStatus']
          (response['TransactionStatus'] == true)
        elsif response["Succeeded"]
          (response["Succeeded"] == true)
        else
          false
        end
      end

      def parse_errors(message)
        errors = message.split(',').collect{|code| MESSAGES[code.strip]}.flatten.join(',')
        errors.presence || message
      end

      def message_from(succeeded, response)
        if response['Errors']
          parse_errors(response['Errors'])
        elsif response['ResponseMessage']
          parse_errors(response['ResponseMessage'])
        elsif response['ResponseCode']
          ActiveMerchant::Billing::EwayGateway::MESSAGES[response['ResponseCode']]
        elsif succeeded
          "Succeeded"
        else
          "Failed"
        end
      end

      def authorization_from(response)
        # Note: TransactionID is always null for store requests, but TokenCustomerID is also sent back for purchase from
        # stored card transactions so we give precendence to TransactionID
        response['TransactionID'] || response['Customer']['TokenCustomerID']
      end

      def avs_result_from(response)
        verification = response['Verification'] || {}
        code = case verification['Address']
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
        verification = response['Verification'] || {}
        case verification['CVN']
        when "Valid"
          "M"
        when "Invalid"
          "N"
        else
          "P"
        end
      end

      def truncate(value, max_size = 50)
        return nil unless value
        value.to_s[0, max_size]
      end

      MESSAGES = {
        'A2000' => 'Transaction Approved Successful',
        'A2008' => 'Honour With Identification Successful',
        'A2010' => 'Approved For Partial Amount Successful',
        'A2011' => 'Approved, VIP Successful',
        'A2016' => 'Approved, Update Track 3 Successful',
        'D4401' => 'Refer to Issuer Failed',
        'D4402' => 'Refer to Issuer, special  Failed',
        'D4403' => 'No Merchant Failed',
        'D4404' => 'Pick Up Card  Failed',
        'D4405' => 'Do Not Honour Failed',
        'D4406' => 'Error   Failed',
        'D4407' => 'Pick Up Card, Special Failed',
        'D4409' => 'Request In Progress Failed',
        'D4412' => 'Invalid Transaction Failed',
        'D4413' => 'Invalid Amount  Failed',
        'D4414' => 'Invalid Card Number Failed',
        'D4415' => 'No Issuer Failed',
        'D4419' => 'Re-enter Last Transaction Failed',
        'D4421' => 'No Action Taken Failed',
        'D4422' => 'Suspected Malfunction Failed',
        'D4423' => 'Unacceptable Transaction Fee  Failed',
        'D4425' => 'Unable to Locate Record On File Failed',
        'D4430' => 'Format Error  Failed ',
        'D4431' => 'Bank Not Supported By Switch  Failed',
        'D4433' => 'Expired Card, Capture Failed ',
        'D4434' => 'Suspected Fraud, Retain Card  Failed',
        'D4435' => 'Card Acceptor, Contact Acquirer, Retain Card  Failed',
        'D4436' => 'Restricted Card, Retain Card  Failed',
        'D4437' => 'Contact Acquirer Security Department, Retain Card Failed',
        'D4438' => 'PIN Tries Exceeded, Capture Failed',
        'D4439' => 'No Credit Account Failed',
        'D4440' => 'Function Not Supported  Failed',
        'D4441' => 'Lost Card Failed',
        'D4442' => 'No Universal Account  Failed',
        'D4443' => 'Stolen Card Failed',
        'D4444' => 'No Investment Account Failed',
        'D4451' => 'Insufficient Funds  Failed',
        'D4452' => 'No Cheque Account Failed',
        'D4453' => 'No Savings Account  Failed',
        'D4454' => 'Expired Card  Failed',
        'D4455' => 'Incorrect PIN Failed',
        'D4456' => 'No Card Record  Failed',
        'D4457' => 'Function Not Permitted to Cardholder  Failed',
        'D4458' => 'Function Not Permitted to Terminal  Failed',
        'D4459' => 'Suspected Fraud Failed',
        'D4460' => 'Acceptor Contact Acquirer Failed',
        'D4461' => 'Exceeds Withdrawal Limit  Failed',
        'D4462' => 'Restricted Card Failed',
        'D4463' => 'Security Violation  Failed',
        'D4464' => 'Original Amount Incorrect Failed',
        'D4466' => 'Acceptor Contact Acquirer, Security Failed',
        'D4467' => 'Capture Card  Failed',
        'D4475' => 'PIN Tries Exceeded  Failed',
        'D4482' => 'CVV Validation Error  Failed',
        'D4490' => 'Cut off In Progress Failed',
        'D4491' => 'Card Issuer Unavailable Failed',
        'D4492' => 'Unable To Route Transaction Failed',
        'D4493' => 'Cannot Complete, Violation Of The Law Failed',
        'D4494' => 'Duplicate Transaction Failed',
        'D4496' => 'System Error  Failed',
        'D4497' => 'MasterPass Error  Failed',
        'D4498' => 'PayPal Create Transaction Error Failed',
        'D4499' => 'Invalid Transaction for Auth/Void Failed',
        'S5000' => 'System Error',
        'S5085' => 'Started 3dSecure',
        'S5086' => 'Routed 3dSecure',
        'S5087' => 'Completed 3dSecure',
        'S5088' => 'PayPal Transaction Created',
        'S5099' => 'Incomplete (Access Code in progress/incomplete)',
        'S5010' => 'Unknown error returned by gateway',
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
        'V6045' => 'Customer Title Required ',
        'V6046' => 'TokenCustomerID Required',
        'V6047' => 'RedirectURL Required',
        'V6048' => 'Invalid Checkout URL',
        'V6051' => 'Invalid Customer FirstName',
        'V6052' => 'Invalid Customer LastName',
        'V6053' => 'Invalid Customer CountryCode',
        'V6058' => 'Invalid Customer Title ',
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
        'V6069' => 'Invalid Customer Email ',
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
        'V6086' => 'Invalid ShippingAddress Fax',
        'V6091' => 'Unknown Customer CountryCode',
        'V6092' => 'Unknown ShippingAddress CountryCode',
        'V6100' => 'Invalid EWAY_CARDNAME',
        'V6101' => 'Invalid EWAY_CARDEXPIRYMONTH',
        'V6102' => 'Invalid EWAY_CARDEXPIRYYEAR ',
        'V6103' => 'Invalid EWAY_CARDSTARTMONTH',
        'V6104' => 'Invalid EWAY_CARDSTARTYEAR',
        'V6105' => 'Invalid EWAY_CARDISSUENUMBER ',
        'V6106' => 'Invalid EWAY_CARDCVN',
        'V6107' => 'Invalid EWAY_ACCESSCODE',
        'V6108' => 'Invalid CustomerHostAddress',
        'V6109' => 'Invalid UserAgent',
        'V6110' => 'Invalid EWAY_CARDNUMBER',
        'V6111' => 'Unauthorised API Access, Account Not PCI Certified',
        'V6112' => 'Redundant card details other than expiry year and month',
        'V6113' => 'Invalid transaction for refund',
        'V6114' => 'Gateway validation error',
        'V6115' => 'Invalid DirectRefundRequest, Transaction ID',
        'V6116' => 'Invalid card data on original TransactionID',
        'V6117' => 'Invalid CreateAccessCodeSharedRequest, FooterText',
        'V6118' => 'Invalid CreateAccessCodeSharedRequest, HeaderText',
        'V6119' => 'Invalid CreateAccessCodeSharedRequest, Language',
        'V6120' => 'Invalid CreateAccessCodeSharedRequest, LogoUrl ',
        'V6121' => 'Invalid TransactionSearch, Filter Match Type',
        'V6122' => 'Invalid TransactionSearch, Non numeric Transaction ID',
        'V6123' => 'Invalid TransactionSearch,no TransactionID or AccessCode specified',
        'V6124' => 'Invalid Line Items. The line items have been provided however the totals do not match the TotalAmount field',
        'V6125' => 'Selected Payment Type not enabled',
        'V6126' => 'Invalid encrypted card number, decryption failed',
        'V6127' => 'Invalid encrypted cvn, decryption failed',
        'V6128' => 'Invalid Method for Payment Type',
        'V6129' => 'Transaction has not been authorised for Capture/Cancellation',
        'V6130' => 'Generic customer information error ',
        'V6131' => 'Generic shipping information error',
        'V6132' => 'Transaction has already been completed or voided, operation not permitted',
        'V6133' => 'Checkout not available for Payment Type',
        'V6134' => 'Invalid Auth Transaction ID for Capture/Void',
        'V6135' => 'PayPal Error Processing Refund',
        'V6140' => 'Merchant account is suspended',
        'V6141' => 'Invalid PayPal account details or API signature',
        'V6142' => 'Authorise not available for Bank/Branch',
        'V6150' => 'Invalid Refund Amount',
        'V6151' => 'Refund amount greater than original transaction',
        'V6152' => 'Original transaction already refunded for total amount',
        'V6153' => 'Card type not support by merchant',
      }
    end
  end
end
