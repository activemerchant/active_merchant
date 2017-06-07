require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayULatamGateway < Gateway
      self.test_url = 'https://stg.api.payulatam.com/payments-api/4.0/service.cgi'
      self.live_url = 'https://api.payulatam.com/payments-api/4.0/service.cgi'

      QUERIES_API_TEST_URL = 'https://stg.api.payulatam.com/reports-api/4.0/service.cgi'
      QUERIES_API_LIVE_URL = 'https://api.payulatam.com/reports-api/4.0/service.cgi'

      self.supported_countries = %w(BR AR CO MX PA PE)
      self.default_currency    = 'USD'
      # Depends on the country, see http://docs.payulatam.com/integracion-con-api/api-de-pagos-2/medios-de-pago-por-pais/
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'http://www.payulatam.net/'
      self.display_name = 'PayU'

      ORDER_STATUS = {
          :NEW         => 'The order has been created',
          :IN_PROGRESS => 'The order is being processed',
          :AUTHORIZED  => 'The last transaction of the order has been approved',
          :CAPTURED    => 'The last transaction of the capture process has been approved',
          :CANCELLED   => 'The last transaction of the order has been canceled',
          :DECLINED    => 'The last transaction of the order has been declined',
          :REFUNDED    => 'The last transaction of the order has been refunded'
      }

      TRANSACTION_STATUS = {
          :APPROVED  => 'Transaction approved',
          :DECLINED  => 'Transaction declined',
          :ERROR     => 'Error in the processing of the transaction',
          :EXPIRED   => 'Transaction expired',
          :PENDING   => 'Transaction is pending or in validation',
          :SUBMITTED => 'Transaction sent to the bank and for some reason has not finish processing. Only applies to API reports'
      }

      QUOTAS = {
          :'1' => 'Payment on site',
          :'2' => 'Business funding',
          :'3' => 'Payment network funding'
      }

      RESPONSE_CODE = {
          :ERROR                                               => 'There was an error in the process/transaction',
          :APPROVED                                            => 'The transaction was approved',
          :ANTIFRAUD_REJECTED                                  => 'The transaction was rejected by the anti-fraud module',
          :PAYMENT_NETWORK_REJECTED                            => 'The payment network has rejected the transaction',
          :ENTITY_DECLINED                                     => 'The transaction has been declined by the bank or there has been an error with the payment network',
          :INTERNAL_PAYMENT_PROVIDER_ERROR                     => 'An error has occurred within the system of the payment network',
          :INACTIVE_PAYMENT_PROVIDER                           => 'The payment provide is not currently activated for your account',
          :DIGITAL_CERTIFICATE_NOT_FOUND                       => 'The payment network has reported an error in the authentication of the transaction',
          :INVALID_EXPIRATION_DATE_OR_SECURITY_CODE            => 'The security code or expiration date is invalid',
          :INSUFFICIENT_FUNDS                                  => 'The account does not have sufficient funds for this transaction',
          :CREDIT_CARD_NOT_AUTHORIZE_FOR_INTERNET_TRANSACTIONS => 'The credit card is not authorized for internet transactions',
          :INVALID_TRANSACTION                                 => 'The payment network has reported that this transaction is not valid',
          :INVALID_CARD                                        => 'Invalid card',
          :EXPIRED_CARD                                        => 'Expired card',
          :RESTRICTED_CARD                                     => 'This card has been restricted for purchases',
          :CONTACT_THE_ENTITY                                  => 'Please contact your bank',
          :REPEAT_TRANSACTION                                  => 'Please attempt the transaction again',
          :ENTITY_MESSAGING_ERROR                              => 'The financial network has reported an error in their communication with the bank',
          :BANK_UNREACHABLE                                    => 'The bank is unable to be reached at this time',
          :EXCEEDED_AMOUNT                                     => 'This transaction has exceeded the limit set by the bank',
          :NOT_ACCEPTED_TRANSACTION                            => 'This transaction was not accepted by the bank',
          :ERROR_CONVERTING_TRANSACTION_AMOUNTS                => 'An error has occurred in the currency conversion process',
          :EXPIRED_TRANSACTION                                 => 'The transaction has expired',
          :PENDING_TRANSACTION_REVIEW                          => 'The transaction was been stopped and must be revised, this may occur because of security filters',
          :PENDING_TRANSACTION_CONFIRMATION                    => 'The transaction is pending confirmation',
          :PENDING_TRANSACTION_TRANSMISSION                    => 'The transaction is pending communication with the payment network. Normally this only occurs in cases of cash payment',
          :PAYMENT_NETWORK_BAD_RESPONSE                        => 'This message is communicated when connection with the payment network is inconsistent',
          :PAYMENT_NETWORK_NO_CONNECTION                       => 'A connection with the payment network is unavailable',
          :PAYMENT_NETWORK_NO_RESPONSE                         => 'The payment network has not responded',
          :FIX_NOT_REQUIRED                                    => 'Clinical transactions: Internal code only',
          :AUTOMATICALLY_FIXED_AND_SUCCESS_REVERSAL            => 'Clinical transactions: Internal code only',
          :AUTOMATICALLY_FIXED_AND_UNSUCCESS_REVERSAL          => 'Clinical transactions: Internal code only',
          :AUTOMATIC_FIXED_NOT_SUPPORTED                       => 'Clinical transactions: Internal code only',
          :NOT_FIXED_FOR_ERROR_STATE                           => 'Clinical transactions: Internal code only',
          :ERROR_FIXING_AND_REVERSING                          => 'Clinical transactions: Internal code only',
          :ERROR_FIXING_INCOMPLETE_DATA                        => 'Clinical transactions: Internal code only'
      }

      SECURITY_CODE = {
          :'0' => 'Not provided',
          :'1' => 'Provided',
          :'2' => 'Unreadable',
          :'9' => 'Non-existent'
      }

      SUPPORTED_CURRENCIES = %w(ARS BRL COP MXN PEN USD)

      SUPPORTED_LANGUAGES = %w(en es pt)

      TRANSACTION_SOURCE = {
          :WEB    => 'Online Transaction (E-commerce)',
          :MOTO   => 'Mail Order Telephone Order',
          :RETAIL => 'Retail',
          :MOBILE => 'Mobile transaction'
      }

      def initialize(options={})
        requires!(options, :merchant_id, :api_login, :api_key, :country_account_id)
        super
      end

      def store(payment, options = {})
        requires!(options, :language)
        commit(:store, nil, payment, nil, options)
      end

      def purchase(money, payment, options={})
        requires!(options, :order_id, :language, :description)
        commit(:purchase, money, payment, nil, options)
      end

      def authorize(money, payment, options={})
        requires!(options, :order_id, :language, :description)
        commit(:authorize, money, payment, nil, options)
      end

      def capture(money, authorization, options={})
        requires!(options, :order_id)
        commit(:capture, money, nil, authorization, options)
      end

      def refund(money, authorization, options={})
        requires!(options, :order_id)
        commit(:refund, money, nil, authorization, options)
      end

      def void(authorization, options={})
        requires!(options, :order_id)
        commit(:void, nil, nil, authorization, options)
      end

      private

      def commit(action, money, payment_method_or_reference, authorization, options = {})
        amount   = amount(money)
        currency = options[:currency] || currency(money)
        options  = options.clone
        post     = {}

        if [:authorize, :purchase].include?(action)
          options[:command]          = 'SUBMIT_TRANSACTION'
          options[:transaction_type] = (action == :authorize ? 'AUTHORIZATION' : 'AUTHORIZATION_AND_CAPTURE')
          build_auth_or_purchase_request(post, amount, currency, payment_method_or_reference, options)
        elsif [:capture, :refund, :void].include?(action)
          options[:command]          = 'SUBMIT_TRANSACTION'
          options[:transaction_type] = action.to_s.upcase
          build_capture_void_or_refund_request(post, amount, currency, payment_method_or_reference, authorization, options)
        elsif action == :store
          options[:command] = 'CREATE_TOKEN'
          build_store_request(post, amount, currency, payment_method_or_reference, authorization, options)
        end

        url      = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(post), headers(options)))

        Response.new(success_from(response),
                     message_from(response),
                     response,
                     authorization: authorization_from(response),
                     test:          test?)
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        {
            'error' => "Invalid response received from the PayU Latam API: #{body.inspect}"
        }
      end

      def success_from(response)
        response['code'] == 'SUCCESS' && (!response['creditCardToken'].nil? || (!response['transactionResponse'].nil? && response['transactionResponse']['state'] == 'APPROVED'))
      end

      def message_from(response)
        msg = nil
        unless response['transactionResponse'].nil?
          if response['transactionResponse']['responseCode']
            msg = RESPONSE_CODE[response['transactionResponse']['responseCode'].to_sym]
          else
            msg = response['transactionResponse']['state']
          end
        end
        msg = (response['error'] ? response['error'] : 'Successful transaction') if msg.blank?
        msg
      end

      def authorization_from(response)
        return nil unless success_from(response)
        # Store call
        return response['creditCardToken']['creditCardTokenId'] if response['creditCardToken']
        [response['transactionResponse']['orderId'], response['transactionResponse']['transactionId'], response['transactionResponse']['authorizationCode']].compact.join(';')
      end

      def build_auth_or_purchase_request(post, amount, currency, payment_method_or_reference, options = {})
        add_common_params(post, options)
        add_transaction_for_auth_or_purchase_request(post, amount, currency, payment_method_or_reference, options)
      end

      def build_capture_void_or_refund_request(post, amount, currency, payment_method_or_reference, authorization, options = {})
        add_common_params(post, options)
        add_transaction_for_capture_void_or_refund_request(post, amount, currency, payment_method_or_reference, authorization, options)
      end

      def build_store_request(post, amount, currency, payment_method_or_reference, authorization, options = {})
        add_common_params(post, options)
        add_credit_card_token_for_store_request(post, amount, currency, payment_method_or_reference, authorization, options)
      end

      def add_common_params(post, options = {})
        post[:language] ||= options[:language] || 'en'
        post[:command]  ||= options[:command] || 'SUBMIT_TRANSACTION'
        post[:test]     = test? ? 'true' : 'false'
        post[:merchant] = {
            :apiLogin => options[:api_login] || @options[:api_login],
            :apiKey   => options[:api_key] || @options[:api_key]
        }
      end

      def add_transaction_for_auth_or_purchase_request(post, amount, currency, payment_method_or_reference, options = {})
        post[:transaction] ||= {}

        add_transaction_order(post, amount, currency, payment_method_or_reference, options)
        add_transaction_order_shipping_address(post, amount, currency, payment_method_or_reference, options)
        add_transaction_order_buyer(post, amount, currency, payment_method_or_reference, options)
        add_transaction_order_additional_values(post, amount, currency, payment_method_or_reference, options)
        add_transaction_credit_card(post, amount, currency, payment_method_or_reference, options)
        add_transaction_payer(post, amount, currency, payment_method_or_reference, options)
        add_transaction_extra_parameters(post, amount, currency, payment_method_or_reference, options)

        # For authorization and capture: AUTHORIZATION_AND_CAPTURE. For authorization: AUTHORIZATION. Required
        post[:transaction][:type]                      ||= options[:transaction_type]
        # The payment method. Required
        post[:transaction][:paymentMethod]             ||= (options[:payment_method] || (card_brand(payment_method_or_reference).upcase unless payment_method_or_reference.is_a? String))
        # The transaction source
        post[:transaction][:source]                    ||= options[:source] if options[:source]
        # Expiration date of the transaction. For example: 2014-01-10’T’13:00:00. Applies only for cash payment methods
        post[:transaction][:expirationDate]            ||= options[:expiration_date] if options[:expiration_date]
        # The session ID of the device on which the transaction takes place
        post[:transaction][:deviceSessionId]           ||= options[:session_id] if options[:session_id]
        # The IP address of the connection where the transaction took place
        post[:transaction][:ipAddress]                 ||= options[:ip] if options[:ip]
        # The cookie stored on the device where the transaction takes place
        post[:transaction][:cookie]                    ||= options[:cookie] if options[:cookie]
        # The user agent of the browser where the transaction takes place
        post[:transaction][:userAgent]                 ||= options[:user_agent] if options[:user_agent]
        # It is mandatory only if your PayU account from Brazil is associated with a bank account in another country
        post[:transaction][:termsAndConditionsAcepted] ||= options[:terms_and_conditions_accepted] if options[:terms_and_conditions_accepted]
        # Undocumented
        post[:transaction][:paymentCountry]            ||= options[:payment_country]
        # The stored token
        post[:transaction][:creditCardTokenId]         ||= payment_method_or_reference if payment_method_or_reference.is_a? String
      end

      def add_transaction_order(post, amount, currency, payment_method_or_reference, options = {})
        # The order data. Required
        post[:transaction][:order]                 ||= {}

        # The identifier of the account. Required
        post[:transaction][:order][:accountId]     ||= (options[:country_account_id] || @options[:country_account_id])
        # The reference code of the order. Represents the identifier of the transaction in the commercial system.
        # It must be unique for each transaction.	Required
        post[:transaction][:order][:referenceCode] ||= options[:order_id]
        # The order description. Required
        post[:transaction][:order][:description]   ||= options[:description]
        # The language used in the system emails sent to the merchant and the customer. Required
        post[:transaction][:order][:language]      ||= options[:language]
        # The notification or confirmation URL of the order
        post[:transaction][:order][:notifyUrl]     ||= options[:notify_url] if options[:notify_url]
        # Partner ID used within PayU
        post[:transaction][:order][:partnerId]     ||= options[:partner_id] if options[:partner_id]
        # The signature associated with order
        post[:transaction][:order][:signature]     ||= (options[:signature] || signature(amount, currency, options))
      end

      def signature(amount, currency, options = {})
        raw = "#{options[:api_key] || @options[:api_key]}~#{options[:merchant_id] || @options[:merchant_id]}~#{options[:order_id]}~#{amount}~#{currency}"
        Digest::MD5.hexdigest(raw)
      end

      def add_transaction_order_shipping_address(post, amount, currency, payment_method_or_reference, options = {})
        address                                                   = (options[:shipping_address] || {})

        # The shipping address of the order
        post[:transaction][:order][:shippingAddress]              ||= {}

        # First line of the shipping address
        post[:transaction][:order][:shippingAddress][:street1]    ||= address[:address1] if address[:address1]
        # Second line of the shipping address
        post[:transaction][:order][:shippingAddress][:street2]    ||= address[:address2] if address[:address2]
        # City of the shipping address
        post[:transaction][:order][:shippingAddress][:city]       ||= address[:city] if address[:city]
        # State or department of the shipping address. For brazil send only two characters. Example: If it's Sao Paulo send SP.
        post[:transaction][:order][:shippingAddress][:state]      ||= address[:state] if address[:state]
        # Country of the shipping address
        post[:transaction][:order][:shippingAddress][:country]    ||= address[:country] if address[:country]
        # Postal code of the shipping address
        post[:transaction][:order][:shippingAddress][:postalCode] ||= address[:zip] if address[:zip]
        # Telephone number associated with the shipping address
        post[:transaction][:order][:shippingAddress][:phone]      ||= address[:phone] if address[:phone]
      end

      def add_transaction_order_buyer(post, amount, currency, payment_method_or_reference, options = {})
        address                                                           = (options[:shipping_address] || options[:billing_address] || {})

        # Buyer information
        post[:transaction][:order][:buyer]                                ||= {}

        # Identifier of the buyer in the merchant’s system
        post[:transaction][:order][:buyer][:merchantBuyerId]              ||= options[:user_id] if options[:user_id]
        # Buyer’s full name. Required in Brazil
        post[:transaction][:order][:buyer][:fullName]                     ||= (address[:name] || (payment_method_or_reference.last_name if payment_method_or_reference.respond_to? :last_name))
        # Buyer’s email address
        post[:transaction][:order][:buyer][:emailAddress]                 ||= options[:email] if options[:email]
        # Buyer’s contact telephone number
        post[:transaction][:order][:buyer][:contactPhone]                 ||= address[:phone]
        # Identification number of the buyer. For Brazil, you must use the CPF. Required in Brazil
        post[:transaction][:order][:buyer][:dniNumber]                    ||= options[:buyer_dni_number] if options[:buyer_dni_number]
        # CNPJ identification number if buyer is a company in Brazil.	Required in Brazil
        post[:transaction][:order][:buyer][:cnpj]                         ||= options[:buyer_cnpj] if options[:buyer_cnpj]

        # Buyer’s shipping address. Required in Brazil
        post[:transaction][:order][:buyer][:shippingAddress]              ||= {}
        # Additional line for shipping address of the buyer. Required in Brazil
        post[:transaction][:order][:buyer][:shippingAddress][:street1]    ||= address[:address1] if address[:address1]
        # City of the shipping address of the buyer. Required in Brazil
        post[:transaction][:order][:buyer][:shippingAddress][:city]       ||= address[:city] if address[:city]
        # State of the shipping address of the buyer. Required in Brazil
        post[:transaction][:order][:buyer][:shippingAddress][:state]      ||= address[:state] if address[:state]
        # Country of the shipping address of the buyer. Required in Brazil
        post[:transaction][:order][:buyer][:shippingAddress][:country]    ||= address[:country] if address[:country]
        # Postal code of the shipping address of the buyer. For Brazil you must use the CEP. Required in Brazil
        post[:transaction][:order][:buyer][:shippingAddress][:postalCode] ||= address[:zip] if address[:zip]
        # Telephone of the buyer’s shipping address. Required in Brazil
        post[:transaction][:order][:buyer][:shippingAddress][:phone]      ||= address[:phone] if address[:phone]
      end

      def add_transaction_order_additional_values(post, amount, currency, payment_method_or_reference, options = {})
        # Values or amounts associated with the order. In this field you can set an amount per ticket.
        post[:transaction][:order][:additionalValues]                       ||= {}

        # The type of amount: TX_VALUE, TX_TAX, TX_TAX_RETURN_BASE, TX_ADDITIONAL_VALUE
        post[:transaction][:order][:additionalValues][:TX_VALUE]            ||= {}
        # The value. For example: 1000.00
        post[:transaction][:order][:additionalValues][:TX_VALUE][:value]    ||= amount if amount
        # The ISO currency code associated with the amount
        post[:transaction][:order][:additionalValues][:TX_VALUE][:currency] ||= currency if currency
      end

      def add_transaction_credit_card(post, amount, currency, payment_method_or_reference, options = {})
        # The data of the credit card used
        post[:transaction][:creditCard]                      ||= {}

        # The number of the credit card used. Required
        post[:transaction][:creditCard][:number]             ||= payment_method_or_reference.number if payment_method_or_reference.respond_to? :number
        # The security code found on the back of the credit card (CVC2, CVV2, CID)
        post[:transaction][:creditCard][:securityCode]       ||= (options[:security_code] || (payment_method_or_reference.verification_value if payment_method_or_reference.respond_to? :verification_value))
        # The date of expiration of the card. Format YYYY/MM. Required
        post[:transaction][:creditCard][:expirationDate]     ||= "#{format(payment_method_or_reference.year, :four_digits)}/#{format(payment_method_or_reference.month, :two_digits)}" if payment_method_or_reference.respond_to? :year
        # The name of the credit card holder.	Required
        post[:transaction][:creditCard][:name]               ||= payment_method_or_reference.last_name if payment_method_or_reference.respond_to? :last_name
        # The name of the bank that issued the credit card
        post[:transaction][:creditCard][:issuerBank]         ||= options[:issuer] if options[:issuer]
        # Allows processing of credit card transactions without the security code cvv2. Available only for accounts active in Brazil. Requires prior PayU authorization before use.
        post[:transaction][:creditCard][:processWithoutCvv2] ||= (options[:ignore_cvv] || (@options[:ignore_cvv] ? 'true' : 'false'))
      end

      def add_transaction_payer(post, amount, currency, payment_method_or_reference, options = {})
        address                                                  = (options[:payer_billing_address] || {})

        # The information of the payer
        post[:transaction][:payer]                               ||= {}
        # The identifier of the payer in the commercial system
        post[:transaction][:payer][:merchantPayerId]             ||= options[:payer_user_id] if options[:payer_user_id]
        # The complete name of the payer. Required
        post[:transaction][:payer][:fullName]                    ||= (address[:name] || (payment_method_or_reference.last_name if payment_method_or_reference.respond_to? :last_name))

        # The billing address
        post[:transaction][:payer][:billingAddress]              ||= {}
        # The first line of the billing address
        post[:transaction][:payer][:billingAddress][:street1]    ||= address[:address1] if address[:address1]
        # The second line of the billing address
        post[:transaction][:payer][:billingAddress][:street2]    ||= address[:address2] if address[:address2]
        # The city of the billing address
        post[:transaction][:payer][:billingAddress][:city]       ||= address[:city] if address[:city]
        # The state or department of the billing address
        post[:transaction][:payer][:billingAddress][:state]      ||= address[:state] if address[:state]
        # The country of the billing address
        post[:transaction][:payer][:billingAddress][:country]    ||= address[:country] if address[:country]
        # The postal code of the billing address
        post[:transaction][:payer][:billingAddress][:postalCode] ||= address[:zip] if address[:zip]
        # The telephone number associated with the billing address
        post[:transaction][:payer][:billingAddress][:phone]      ||= address[:phone] if address[:phone]

        # The email of the payer
        post[:transaction][:payer][:emailAddress]                ||= options[:payer_email] if options[:payer_email]
        # The telephone number of the payer
        post[:transaction][:payer][:contactPhone]                ||= address[:phone] if address[:phone]
        # The identification number of the payer. Required in Brazil
        post[:transaction][:payer][:dniNumber]                   ||= options[:payer_dni_number] if options[:payer_dni_number]
      end

      def add_transaction_extra_parameters(post, amount, currency, payment_method_or_reference, options = {})
        # Additional parameters or data associated with a transaction. These parameters may vary according to the means of payment or transaction preferences
        post[:transaction][:extraParameters]                       ||= {}
        post[:transaction][:extraParameters][:INSTALLMENTS_NUMBER] ||= (options[:installments_number] || 1)
      end

      def add_transaction_for_capture_void_or_refund_request(post, amount, currency, payment_method_or_reference, authorization, options = {})
        order_id, transaction_id, authorization_code = authorization.split(';')

        # The transaction data. Required
        post[:transaction]                           ||= {}

        # The order data. Required
        post[:transaction][:order]                   ||= {}
        # The ID of the transaction associated with the order
        post[:transaction][:order][:id]              ||= order_id

        # Use CAPTURE, VOID for cancellation, and REFUND
        post[:transaction][:type]                    ||= options[:transaction_type]
        # The identifier of the related transaction. Required
        # If the current transaction is CAPTURE or VOID, the identifier of the transaction is sent as AUTHORIZATION.
        # If the current transaction is REFUND, the identifier of the transaction is sent as AUTHORIZATION_AND_CAPTURE or CAPTURE.
        post[:transaction][:parentTransactionId]     = transaction_id
      end

      def add_credit_card_token_for_store_request(post, amount, currency, payment_method_or_reference, authorization, options = {})
        post[:creditCardToken]                        ||= {}

        # Unique identifier of the payer in the shop
        post[:creditCardToken][:payerId]              ||= options[:payer_user_id] if options[:payer_user_id]
        # Cardholder data must be filled out as they appear on the credit card
        post[:creditCardToken][:name]                 ||= payment_method_or_reference.last_name if payment_method_or_reference.respond_to? :last_name
        # Client identification number
        post[:creditCardToken][:identificationNumber] ||= options[:identification_number] if options[:identification_number]
        # Ex. Visa, MasterCard, American Express, etc.
        post[:creditCardToken][:paymentMethod]        ||= (options[:payment_method] || card_brand(payment_method_or_reference).upcase)
        # Number of credit card
        post[:creditCardToken][:number]               ||= payment_method_or_reference.number if payment_method_or_reference.respond_to? :number
        # Expiration date of the credit card
        post[:creditCardToken][:expirationDate]       ||= "#{format(payment_method_or_reference.year, :four_digits)}/#{format(payment_method_or_reference.month, :two_digits)}" if payment_method_or_reference.respond_to? :year
      end

      def post_data(params)
        params.nil? ? '{}' : params.to_json
      end

      def headers(options)
        {
            'Accept'       => 'application/json',
            'Content-Type' => 'application/json; charset=utf-8',
        }
      end
    end
  end
end
