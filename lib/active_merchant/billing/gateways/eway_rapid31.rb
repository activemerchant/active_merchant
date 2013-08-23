require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EwayRapid31Gateway < Gateway
      self.test_url = 'https://api.sandbox.ewaypayments.com/'
      self.live_url = 'https://api.ewaypayments.com/'

      self.money_format     = :cents
      self.default_currency = 'AUD'

      self.supported_countries = ['AU', 'NZ', 'GB']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'http://www.eway.com.au'
      self.display_name = 'eWAY Rapid 3.1'

      def initialize(options = {})
        requires!(options, :login, :password)

        super
      end

      def purchase(money, credit_card_or_token, options = {})
        requires!(options, :billing_address)

        post = {}
        post[:Payment] ||= {}

        add_invoice(post[:Payment], options)
        add_amount(post[:Payment], money, options)
        add_credit_card(post, credit_card_or_token)
        add_customer_data(post, options)
        add_metadata(post, options)

        commit('Transaction', post)
      end

      def store(credit_card, options = {})
        requires!(options, :billing_address)

        post = {}

        add_credit_card(post, credit_card)
        add_customer_data(post, options)

        commit('Customer', post)
      end

      def refund(money, identification, options = {})
        post = {}
        post[:Refund] ||= {}
        post[:Refund][:TransactionID] = identification.to_s

        add_invoice(post[:Refund], options)
        add_amount(post[:Refund], money, options)
        add_customer_data(post, options)
        add_metadata(post, options)

        commit("Transaction/#{identification}/Refund", post)
      end

      def update(token, credit_card, options = {})
        post = {}
        post[:Customer] ||= {}
        post[:Customer][:TokenCustomerID] = token.to_s

        add_customer_data(post, options)
        add_credit_card(post, credit_card)
        add_metadata(post, options)

        commit('Customer', post, :put)
      end

      private

      def url_for(endpoint)
        (test? ? test_url : live_url) + endpoint
      end

      def add_amount(post, money, options)
        post ||= {}
        post[:TotalAmount]  = amount(money).to_i
        post[:CurrencyCode] = options[:currency] || currency(money)
      end

      def add_customer_data(post, options)
        post[:Customer] ||= {}
        post[:Customer].merge! translated_address_hash(post, (options[:billing_address] || options[:address]), { :email => options[:email] })

        if options[:shipping_address]
          post[:ShippingAddress] = translated_address_hash(post, options[:shipping_address])
          post[:ShippingAddress].reject! { |field| [:Fax, :CompanyName, :Mobile, :Title].include?(:field) }
        end
      end

      def translated_address_hash(post, address, options)
        return unless address

        output = {}

        if name = address[:name]
          parts = name.split(/\s+/)

          output[:FirstName] = parts.shift if parts.size > 1
          output[:LastName]  = parts.join(' ')
        end

        output[:Title]       = address[:title].to_s
        output[:CompanyName] = address[:company]
        output[:Street1]     = address[:address1]
        output[:Street2]     = address[:address2]
        output[:City]        = address[:city]
        output[:State]       = address[:state]
        output[:PostalCode]  = address[:zip]
        output[:Country]     = address[:country].to_s.downcase
        output[:Phone]       = address[:phone]
        output[:Mobile]      = address[:mobile].to_s
        output[:Fax]         = address[:fax]
        output[:Email]       = options[:email] if options[:email]

        output
      end

      def add_invoice(post, options)
        post ||= {}
        post[:InvoiceReference]   = options[:order_id]
        post[:InvoiceDescription] = options[:description]
      end

      def add_credit_card(post, credit_card_or_token)
        post[:Customer] ||= {}

        if credit_card_or_token.is_a?(String) || credit_card_or_token.is_a?(Integer)
          post[:Customer][:TokenCustomerID] = credit_card_or_token.to_s
        else
          post[:Customer][:CardDetails] ||= {}
          post[:Customer][:CardDetails][:Name]        = credit_card_or_token.name
          post[:Customer][:CardDetails][:Number]      = credit_card_or_token.number
          post[:Customer][:CardDetails][:ExpiryMonth] = sprintf('%02d', credit_card_or_token.month)
          post[:Customer][:CardDetails][:ExpiryYear]  = credit_card_or_token.year.to_s[2,2]
          post[:Customer][:CardDetails][:CVN]         = credit_card_or_token.verification_value.to_s
        end
      end

      def add_metadata(post, options)
        post[:CustomerIP]      = options[:ip] if options[:ip]
        post[:DeviceID]        = options[:application_id] || application_id
        post[:TransactionType] = options[:transaction_type] if options[:transaction_type].present?
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, post, method = :post)
        headers = {
          'Content-Type'  => 'application/json; charset=utf-8',
          'Authorization' => 'Basic ' + Base64.strict_encode64(@options[:login].to_s + ':' + @options[:password].to_s).chomp
        }

        response  = parse(ssl_request(method, url_for(action), post.to_json, headers))
        succeeded = success?(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          :authorization => authorization_from(response),
          :test => test?,
          :avs_result => avs_result_from(response),
          :cvv_result => cvv_result_from(response)
        )
      rescue ActiveMerchant::ResponseError => e
        Response.new(false, e.response.message, { :status_code => e.response.code}, :test => test?)
      end

      def success?(response)
        if !response['Errors'].blank?
          false
        elsif ['00', '08', '10', '11', '16'].include?(response['ResponseCode'])
          true
        elsif response.key?('TransactionStatus')
          response['TransactionStatus'] == true
        else
          true
        end
      end

      def message_from(succeeded, response)
        if response['Errors']
          MESSAGES[response['Errors']] || response['Errors']
        elsif response['ResponseCode']
          ActiveMerchant::Billing::EwayGateway::MESSAGES[response['ResponseCode']]
        elsif response['ResponseMessage']
          MESSAGES[response['ResponseMessage']] || response['ResponseMessage']
        elsif succeeded
          'Succeeded'
        else
          'Failed'
        end
      end

      def authorization_from(response)
        response['AuthorisationCode'] || token_from(response)
      end

      def token_from(response)
        customer_params = response['Customer']
        customer_params.is_a?(Hash) ? customer_params['TokenCustomerID'] : nil
      end

      def avs_result_from(response)
        return if response['Verification'].nil?

        code = case response['Verification']['Address']
               when 0 then 'M'
               when 1 then 'N'
               else 'I'
               end

        { :code => code }
      end

      def cvv_result_from(response)
        return if response['Verification'].nil?

        case response['Verification']['CVN']
        when 0 then 'M'
        when 1 then 'N'
        else 'P'
        end
      end

      MESSAGES = {
              'V6000' => 'Validation error',
              'V6001' => 'Invalid CustomerIP',
              'V6002' => 'Invalid DeviceID',
              'V6003' => 'Invalid Request PartnerID',
              'V6004' => 'Invalid Request Method',
              'V6010' => 'Invalid Payment Type, account not certified for eCom only MOTO or Recurring available',
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
              'V6111' => 'Unauthorised API Access, Account Not PCI Certified',
              'V6112' => 'Redundant Card Details Other Than Expiry Year and Month',
              'V6113' => 'Invalid Transaction for Refund',
              'V6114' => 'Gateway Validation Error',
              'V6115' => 'Invalid DirectRefundRequest, TransactionID',
              'V6116' => 'Invalid card data on original transactionID',
              'V6117' => 'Invalid CreateAccessCodeSharedRequest, FooterText',
              'V6118' => 'Invalid CreateAccessCodeSharedRequest, HeaderText',
              'V6119' => 'Invalid CreateAccessCodeSharedRequest, Language',
              'V6120' => 'Invalid CreateAccessCodeSharedRequest, LogoUrl'
            }
    end
  end
end
