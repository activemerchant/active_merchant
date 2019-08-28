require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information on the Secure Trading visit
    # {SecureTraining}[https://docs.securetrading.com]
    #
    class SecureTradingGateway < Gateway
      self.live_url = 'https://webservices.securetrading.net:443/xml/'

      self.supported_countries = ['GB', 'US']
      self.default_currency = 'GBP'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.securetrading.com/'
      self.display_name = 'Secure Trading Gateway'

      STANDARD_ERROR_CODE_MAPPING = {
        '10103' => STANDARD_ERROR_CODE[:incorrect_number],
        '31001' => STANDARD_ERROR_CODE[:invalid_number],
        '31002' => STANDARD_ERROR_CODE[:expired_card],
        '31003' => STANDARD_ERROR_CODE[:expired_card],
        '31004' => STANDARD_ERROR_CODE[:expired_card],
        '31009' => STANDARD_ERROR_CODE[:processing_error],
        '70000' => STANDARD_ERROR_CODE[:card_declined],
      }.freeze

      CARD_BRAND_MAP = {
        'master'            => 'MASTERCARD',
        'american_express'  => 'AMEX',
      }.freeze

      def initialize(options={})
        requires!(options, :api_key, :user_id, :site_id)
        @api_key = options[:api_key]
        @user_id = options[:user_id]
        @site_reference = options[:site_id]
        super
      end

      def build_xml_request(action)
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8')
        builder.__send__('requestblock', { version: '3.67' }) do |doc|
          doc.alias @user_id
          doc.request type: action do
            yield(doc)
          end
        end
        builder.doc.root.to_xml
      end

      def authorize(money, payment, options={})
        post = build_xml_request('ACCOUNTCHECK') do |xml|
          add_operation(xml, 'authonly', options)
          add_merchant(xml, options)
          add_billing_data(xml, payment, 0, options)
        end

        commit('authonly', post)
      end
      alias_method :store, :authorize

      def purchase(money, payment_method, options={})
        post = build_xml_request('AUTH') do |xml|
          add_operation(xml, 'purchase', options)
          add_merchant(xml, options)
          add_billing_data(xml, payment_method, money, options)
          add_customer(xml, options)
          add_settlement(xml, options)
        end

        commit('purchase', post)       
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]')
          .gsub(%r((<pan>\d{6})\d+(\d{4}</pan>)), '\1[FILTERED]\2')
          .gsub(%r((<securitycode>).+(</securitycode>)), '\1[FILTERED]\2')
          .gsub(%r((<alias>).+(</alias>)), '\1[FILTERED]\2')
          .gsub(%r((<sitereference>).+(</sitereference>)), '\1[FILTERED]\2')
      end

      private
      def add_address(xml, address)
        if address.present?
          xml.town address[:city]
          xml.postcode address[:zip]
          xml.premise address[:address1].gsub(/\D/, '')
          xml.street address[:address1]
          xml.country address[:country]
        end
      end

      def add_billing_data(xml, payment, money, options = {})
        xml.billing do
          xml.amount money, currencycode: options[:currency]
          xml.email options[:email]

          add_address(xml, options[:address] || options[:billing_address])

          xml.name do
            xml.prefix options[:title] #  (e.g. Mr,Miss,Dr).
            xml.first options[:first_name]
            xml.middle options[:middle_name]
            xml.last options[:last_name]
          end

          # phone_type options: H = Home | M = Mobile | W = Work
          if options[:phone_number]
            xml.telephone options[:phone_number], type: options[:phone_type] || 'H'
          end

          if payment.present?
            add_payment(xml, payment, options)
          end
        end
      end

      def add_customer(xml, options = {})
        if options[:customer].present?
          xml.email options[:email]
          add_address(xml, options[:customer][:address])
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_merchant(xml, options = {})
        xml.merchant do
          xml.orderreference options[:unique_identifier] || options[:order_id]
        end
      end

      def add_payment(xml, credit_card, options)
        xml.payment type: card_brand(credit_card) do
          xml.expirydate exp_date(credit_card)
          xml.securitycode credit_card.verification_value
          xml.pan credit_card.number
        end
      end

      def card_brand(card)
        CARD_BRAND_MAP.fetch(super.downcase, super.upcase)
      end

      def exp_date(credit_card)
        format(credit_card.month, :two_digits) + '/' + format(credit_card.year, :four_digits)
      end

      def add_operation(xml, action, options = {})
        xml.operation do
          xml.sitereference @site_reference

          # "PRE" or "FINAL". (For split shipments, this must be set to "PRE")
          xml.authmethod 'FINAL'

          # CARDSTORE (allow store)
          # CFT (allow refund AKA. Payouts)
          # RECUR (for processing recurring payments)
          # ECOM (E-commerce)
          #
          xml.accounttypedescription account_type(action)

          xml.credentialsonfile get_credential_on_file_number(action, options)

          if options[:parent_transaction_reference].present?
            xml.parenttransactionreference options[:parent_transaction_reference]
          end
        end
      end


      # '1' identify that credentials are going to be stored for later
      # '2' Customer Initiated Transaction (CIT) from previously-stored credentials
      #
      def get_credential_on_file_number(action, options)
        if action == 'purchase' && options[:parent_transaction_reference].present?
          '2'
        else
          '1'
        end
      end

      # Settlement is a process that follows authorisation. Secure Trading
      # submit a file to the acquiring bank, requesting that authorised funds
      # are transferred into your bank account. You can defer these transactions
      # if you wish by submitting a specific date in the settleduedate field.
      #
      # note: you cannot specify a date that is more than 7 days in the future
      #
      # +settle status+
      #   0  Automatic (default value when element is not submited)
      #   1  Manual
      #   2  Suspended
      # 100  Settled (only supported by certain acquiering banks)
      #
      def add_settlement(xml, options = {})
        if options[:settle_due_date].present?
          xml.settlement do 
            xml.settleduedate options[:settle_due_date]
            xml.settlestatus options[:settle_status] || '100'
          end
        end
      end

      def parse(body)
        response = {}
        doc = Nokogiri::XML(body)

        response_element = doc.at_xpath('//responseblock')
        response[:response_code] = response_element.at_xpath('response').attr('type')
        response[:request_reference] = response_element.at_xpath('requestreference').content
        response[:transaction_reference] = response_element.at_xpath('response/transactionreference').try(:content)
        
        error_element = response_element.at_xpath('response/error')
        response[:error_message] = error_element.at_xpath('message').content
        response[:error_code] = error_element.at_xpath('code').content
        response[:error_data] = error_element.at_xpath('data').try(:content)
        
        response[:authcode] = response_element.at_xpath('response/authcode').try(:content)

        response
      end

      def commit(action, parameters)
        response = parse(ssl_post(live_url, parameters, headers(parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def headers(parameters)
        {
          'Authorization' => "Basic #{@api_key}",
          'Content-Type' => 'application/xml',
          'Content-length' => "#{parameters.size}"
        }
      end

      def success_from(response)
        response[:error_message] == 'Ok' && response[:error_code] == '0' &&
          ['AUTH', 'ACCOUNTCHECK'].include?(response[:response_code])
      end

      def message_from(response)
        response[:response_code]
      end

      def authorization_from(response)
        response[:transaction_reference] 
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response[:error_code]] ||
            response.values_at(:error_code, :error_message, :error_data).compact.join(' ')
        end
      end

      # each Account Type support different request types, depending of what
      # action we want to perform we have to set the account type
      # https://docs.securetrading.com/document/toolbox/accounttypedescription
      #
      #  account type | supported request types
      #  --------------------------------------
      #  CARDSTORE    | STORE
      #  ECOM         | ACCOUNTCHECK, AUTH, REFUND
      #  CFT          | REFUND
      #  RECUR        | AUTH, SUBSCRIPTION
      #
      def account_type(action)
        case action
          when 'store'  then 'CARDSTORE'
          when 'refund' then 'CFT'
          else 'ECOM'   # Actions: authonly, purchase
        end
      end
    end
  end
end
