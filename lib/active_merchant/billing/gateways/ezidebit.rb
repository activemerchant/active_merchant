# frozen_string_literal: true

require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EzidebitGateway < Gateway
      include Empty

      self.test_url = 'https://api.demo.ezidebit.com.au/v3-5/'
      self.live_url = 'https://api.ezidebit.com.au/v3-5/'

      self.supported_countries = ['AU', 'NZ']
      self.default_currency = 'AUD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.getpayments.com/'
      self.display_name = 'Ezidebit'

      STANDARD_ERROR_CODE_MAPPING = {
        14 => STANDARD_ERROR_CODE[:invalid_number],
        54 => STANDARD_ERROR_CODE[:expired_card],
        55 => STANDARD_ERROR_CODE[:incorrect_pin],
        1 => STANDARD_ERROR_CODE[:card_declined],
        2 => STANDARD_ERROR_CODE[:card_declined],
        3 => STANDARD_ERROR_CODE[:processing_error],
        5 => STANDARD_ERROR_CODE[:card_declined],
        51 => STANDARD_ERROR_CODE[:card_declined],
        4 => STANDARD_ERROR_CODE[:pickup_card],
        7 => STANDARD_ERROR_CODE[:pickup_card],
        33 => STANDARD_ERROR_CODE[:pickup_card],
        34 => STANDARD_ERROR_CODE[:pickup_card],
        35 => STANDARD_ERROR_CODE[:pickup_card],
        36 => STANDARD_ERROR_CODE[:pickup_card],
        37 => STANDARD_ERROR_CODE[:pickup_card],
        96 => STANDARD_ERROR_CODE[:config_error],
        98 => STANDARD_ERROR_CODE[:config_error]
      }.freeze

      ENV_NS = { 'xmlns:soapenv' => 'http://schemas.xmlsoap.org/soap/envelope/', 'xmlns:px' => 'https://px.ezidebit.com.au/' }
      SOAP_ACTION_PCI_NS = 'https://px.ezidebit.com.au/IPCIService/'
      SOAP_ACTION_NONPCI_NS = 'https://px.ezidebit.com.au/INonPCIService/'

      def initialize(options={})
        requires!(options, :digital_key)
        super
      end

      def purchase(money, payment, options = {})
        request = build_soap_request do |xml|
          xml['px'].ProcessRealtimeCreditCardPayment do
            add_authentication(xml)
            add_payment(xml, payment)
            add_invoice(xml, money, options)
            add_customer_data(xml, options)
          end
        end

        commit('ProcessRealtimeCreditCardPayment', request, options)
      end

      # public
      #
      # tokenise a payment method. Ezidebit creates a customer and then
      # attaches a creditcard to said customer.
      # the authorization we return is the :customer_ref which is the
      # ID within Ezidebit for the customer record.
      def store(payment, options = {})
        MultiResponse.run do |r|
          r.process { add_customer_details(options) }
          # subsquent operations don't return this value so let's store it
          options[:customer_ref] = r.authorization
          r.process { add_card_to_customer(payment, options) }
        end        
      end

      # public
      #
      # Evergiving specific, not the classic ActiveMerchant
      # supported methods (there's no standard ARB/recurrence methods)
      # the authorization we return is the :customer_ref which is the
      # ID within Ezidebit for the customer record.
      def recurring(money, payment, options = {})
        MultiResponse.run do |r|
          r.process { add_customer_details(options) }
          # subsquent operations don't return this value so let's store it
          options[:customer_ref] = r.authorization
          r.process { add_card_to_customer(payment, options) }
          r.process { create_schedule(money, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<px:DigitalKey>)[^<]*(</px:DigitalKey>))i, '\1[FILTERED]\2').
          gsub(%r((<px:CreditCardNumber>)[^<]*(</px:CreditCardNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<px:CreditCardCCV>).+(</px:CreditCardCCV>))i, '\1[FILTERED]\2')
      end

      private

      # private
      # creates a schedule (recurring/subscription plan) for a customer
      # that was created
      def create_schedule(money, options = {})
        request = build_soap_request do |xml|
          xml['px'].CreateSchedule do
            add_authentication(xml)
            xml['px'].EziDebitCustomerID
            xml['px'].YourSystemReference options[:order_id]
            xml['px'].ScheduleStartDate options[:start_date]
            xml['px'].SchedulePeriodType options[:scheduler_period_type]
            xml['px'].DayOfWeek options[:day_of_week] unless empty?(options[:day_of_week])
            xml['px'].DayOfMonth options[:day_of_month]
            xml['px'].FirstWeekOfMonth options[:first_week_of_month] unless empty?(options[:first_week_of_month])
            xml['px'].SecondWeekOfMonth options[:second_week_of_month] unless empty?(options[:second_week_of_month])
            xml['px'].ThirdWeekOfMonth options[:third_week_of_month] unless empty?(options[:third_week_of_month])
            xml['px'].FourthWeekOfMonth options[:fourth_week_of_month] unless empty?(options[:fourth_week_of_month])
            xml['px'].PaymentAmountInCents amount(money)
            xml['px'].LimitToNumberOfPayments options[:limit_to_number_of_payments] || 0
            xml['px'].LimitToTotalAmountInCents options[:limit_to_total_amount_in_cents] || 0
            xml['px'].KeepManualPayments options[:keep_manual_payments] || 'YES'
            xml['px'].Username options[:username] unless empty?(options[:username])
          end
        end

        commit('CreateSchedule', request, options)
      end

      # private
      # adding a customer requires a vast number of details to identify a
      # customer (address, name, email, phone)
      def add_customer_details(options = {})
        request = build_soap_request do |xml|
          xml['px'].AddCustomer do
            add_authentication(xml)
            address = options[:billing_address] || options[:address]
            xml['px'].YourSystemReference options[:order_id]
            xml['px'].LastName options[:last_name]
            xml['px'].FirstName options[:first_name]
            xml['px'].AddressLine1 address[:address1] if address[:address1]
            xml['px'].AddressLine2 address[:address2] if address[:address2]
            xml['px'].AddressSuburb address[:city] if address[:city]
            xml['px'].AddressState address[:state] if address[:state]
            xml['px'].AddressPostCode address[:zip] if address[:zip]
            xml['px'].EmailAddress options[:email] unless empty?(options[:email])
            xml['px'].MobilePhoneNumber options[:mobile_phone] unless empty?(options[:mobile_phone])
            xml['px'].ContractStartDate options[:start_date]
            xml['px'].SmsPaymentReminder 'NO'
            xml['px'].SmsFailedNotification 'NO'
            xml['px'].SmsExpiredCard 'NO'
            xml['px'].Username options[:username] unless empty?(options[:username])
          end
        end

        commit('AddCustomer', request, options)
      end

      # private
      # when tokenising, we add the card to the customer via an edit
      # customer endpoint.
      def add_card_to_customer(payment, options = {})
        request = build_soap_request do |xml|
          xml['px'].EditCustomerCreditCard do
            add_authentication(xml)
            xml['px'].EziDebitCustomerID
            xml['px'].YourSystemReference options[:order_id]
            add_payment(xml, payment)
            xml['px'].Reactivate 'YES'
            xml['px'].Username options[:username] unless empty?(options[:username])
          end
        end

        commit('EditCustomerCreditCard', request, options)
      end

      # private
      # the documentation only refers to the use of the digital_key for
      # authentication
      def add_authentication(xml)
        xml['px'].DigitalKey @options[:digital_key]
      end

      # private
      # used for realtime creditcard payment, the customer name
      # is mandatory
      def add_customer_data(xml, options)
        xml['px'].CustomerName options[:customer_name]
      end

      # private
      # payment/amount details
      def add_invoice(xml, money, options)
        xml['px'].PaymentAmountInCents amount(money)
        xml['px'].PaymentReference options[:order_id] || SecureRandom.hex(10)
      end

      # private
      # credit card details for tokenisation and payments
      def add_payment(xml, payment)
        xml['px'].CreditCardNumber payment.number
        xml['px'].CreditCardExpiryMonth format(payment.month, :two_digits)
        xml['px'].CreditCardExpiryYear format(payment.year, :four_digits)
        xml['px'].CreditCardCCV payment.verification_value if payment.verification_value
        xml['px'].NameOnCreditCard payment.name
      end

      def parse(body, action)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!

        response = {}

        response[:response_code] = if (element = doc.at_xpath("//#{action}Result/Data/PaymentResultCode"))
          (empty?(element.content) ? nil : element.content.to_i)
        end

        response[:response_message] = if (element = doc.at_xpath("//#{action}Result/Data/PaymentResultText"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:bank_receipt_id] = if (element = doc.at_xpath("//#{action}Result/Data/BankReceiptID"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:exchange_payment_id] = if (element = doc.at_xpath("//#{action}Result/Data/ExchangePaymentID"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:approved] = if (element = doc.at_xpath("//#{action}Result/Data/PaymentResult"))
          (empty?(element.content) ? false : element.content)
        end

        response[:error_code] = if (element = doc.at_xpath("//#{action}Result/Error"))
          (empty?(element.content) ? false : element.content)
        end

        response[:error_message] = if (element = doc.at_xpath("//#{action}Result/ErrorMessage"))
          (empty?(element.content) ? false : element.content)
        end

        response[:customer_ref] = if (element = doc.at_xpath("//#{action}Result/Data/CustomerRef"))
          (empty?(element.content) ? false : element.content)
        end

        response[:result_data] = if (element = doc.at_xpath("//#{action}Result/Data"))
          (empty?(element.content) ? false : element.content)
        end

        response
      end

      # private
      # returns the corresponding header to send as a SOAPAction
      def soap_action_namespace(action)
        ns = if %w(AddCustomer CreateSchedule).include? action
               SOAP_ACTION_NONPCI_NS
             else
               SOAP_ACTION_PCI_NS
             end

        "#{ns}#{action}"
      end

      # private
      # builds the headers we will send with our HTTP request
      def headers(action)
        {
          'Content-Type' => 'text/xml',
          'SOAPAction'   => soap_action_namespace(action)
        }
      end

      # private
      # a way to select the correct URL to talk to
      def url(action)
        # Joy! AddCustomer or CreateSchedule do not use the same URL as the
        # payments or editing of the customer details to add the card
        endpoint = if %w(AddCustomer CreateSchedule).include? action
                     'nonpci'
                   else
                     'pci'
                   end

        url = test? ? test_url : live_url

        "#{url}#{endpoint}"
      end

      # private
      # yup ... calling Ezidebit from here
      def commit(action, xml, parameters)
        response = parse(ssl_post(url(action), xml, headers(action)), action)

        Response.new(
          success_from(response, action),
          message_from(response, action),
          response,
          authorization: authorization_from(response, action, parameters),
          test: test?,
          error_code: error_code_from(response, action)
        )
      end

      def success_from(response, action)
        if %w(EditCustomerCreditCard CreateSchedule).include? action
          response[:result_data] == 'S'
        else
          response[:error_code] == '0' && (response[:customer_ref].present? || response[:response_code] == 0)
        end
      end

      def message_from(response, action)
        if success_from(response, action)
          response[:response_message]
        else
          response[:error_message]
        end
      end

      # note for the `store` action, we use the `:order_id` that we pass
      # as the authorisation, since that's a reference that's searchable
      # via the admin ui
      def authorization_from(response, action, options)
        if %w(EditCustomerCreditCard CreateSchedule).include? action
          # these two actions do not return any information except success
          # or failure ... and since we call them always after the AddCustomer
          # we have to set the value in the options hash to access it here
          options[:customer_ref]
        elsif action == 'AddCustomer'
          response[:customer_ref]
        else
          [response[:bank_receipt_id], response[:exchange_payment_id]].join('|')
        end
      end

      def build_soap_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['soapenv'].Envelope(ENV_NS) do
            xml['soapenv'].Header
            xml['soapenv'].Body do
              yield(xml)
            end
          end
        end

        builder.to_xml
      end

      def error_code_from(response, action)
        STANDARD_ERROR_CODE_MAPPING.fetch(response[:response_code], 1) unless success_from(response, action)
      end
    end
  end
end
