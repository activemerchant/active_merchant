module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantSuiteGateway < Gateway
      self.live_url = 'https://www.merchantsuite.com/api/v3/'
      self.test_url = 'https://merchantsuite-uat.premier.com.au/api/v3/'

      self.supported_countries = ['AU']
      self.default_currency = 'AUD'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'https://www.merchantsuite.com/developerzone/v3/'
      self.display_name = 'Merchant Suite'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :username, :password, :membershipid)
        super
      end

      def headers
        credentials = @options[:username] + '|' + @options[:membershipid] + ':' + @options[:password]

        {
          'Content-Type' => 'application/json; charset=utf-8',
          'Authorization' => Base64.strict_encode64(credentials),
        }
      end

      def search_transaction(options)
        post = {
          SearchInput: {
            Action: options.fetch('action', 'payment')
          }
        }

        post[:SearchInput][:Amount] = options.fetch(:amount) if options.has_key?(:amount)
        post[:SearchInput][:AuthoriseID] = options.fetch(:authorise_id) if options.has_key?(:authorise_id)
        post[:SearchInput][:BankResponseCode] = options.fetch(:bank_response_code) if options.has_key?(:bank_response_code)
        post[:SearchInput][:PaymentReason] = options.fetch(:payment_reason) if options.has_key?(:payment_reason)
        post[:SearchInput][:CardType] = options.fetch(:card_type) if options.has_key?(:card_type)
        post[:SearchInput][:Reference1] = options.fetch(:reference_1) if options.has_key?(:reference_1)
        post[:SearchInput][:Reference2] = options.fetch(:reference_2) if options.has_key?(:reference_2)
        post[:SearchInput][:Reference3] = options.fetch(:reference_3) if options.has_key?(:reference_3)
        post[:SearchInput][:ExpiryDate] = options.fetch(:expdate) if options.has_key?(:expdate)
        post[:SearchInput][:FromDate] = options.fetch(:from_date) if options.has_key?(:from_date)
        post[:SearchInput][:ToDate] = options.fetch(:to_date) if options.has_key?(:to_date)
        post[:SearchInput][:MaskedCardNumber] = options.fetch(:masked_card_number) if options.has_key?(:masked_card_number)
        post[:SearchInput][:InternalNote] = options.fetch(:internal_note) if options.has_key?(:internal_note)
        post[:SearchInput][:RRN] = options.fetch(:rrn) if options.has_key?(:rrn)
        post[:SearchInput][:ReceiptNumber] = options.fetch(:receipt_number) if options.has_key?(:receipt_number)
        post[:SearchInput][:ResponseCode] = options.fetch(:response_code) if options.has_key?(:response_code)
        post[:SearchInput][:SettlementDate] = options.fetch(:settlement_date) if options.has_key?(:settlement_date)
        post[:SearchInput][:Source] = options.fetch(:source) if options.has_key?(:source)
        post[:SearchInput][:TxnNumber] = options.fetch(:txn_number) if options.has_key?(:txn_number)

        commit(:post, 'txns/search', post)
      end

      def purchase(money, payment, options={})
        post = {
          TxnReq: {
            Action: 'payment',
          }
        }

        add_invoice(post[:TxnReq], money, options)
        add_payment(post[:TxnReq], payment)
        add_customer_data(post[:TxnReq], options)
        add_references(post[:TxnReq], options)
        add_purchase_details(post[:TxnReq], options)

        commit(:post, 'txns', post)
      end

      def authorize(money, authorization, options={})
        post = {
          TxnReq: {
            Action: 'preauth',
          }
        }

        add_invoice(post[:TxnReq], money, options)
        add_payment(post[:TxnReq], authorization)
        add_customer_data(post[:TxnReq], options)
        add_references(post[:TxnReq], options)
        add_purchase_details(post[:TxnReq], options)

        commit(:post, 'txns', post)
      end

      def store(payment, options = {})
        options.deep_symbolize_keys!

        post = {
          TokenReq: {
            EmailAddress: options[:email]
          }
        }

        add_references(post[:TokenReq], options)
        add_payment(post[:TokenReq], payment)
        add_bank_details(post[:TokenReq], options)

        commit(:post, 'tokens', post)
      end

      def capture(money, authorization, options={})
        post = {
          TxnReq: {
            Action: 'capture',
            OriginalTxnNumber: authorization
          }
        }

        add_invoice(post[:TxnReq], money, options)
        add_customer_data(post[:TxnReq], options)
        add_references(post[:TxnReq], options)
        add_purchase_details(post[:TxnReq], options)

        commit(:post, 'txns', post)
      end

      def refund(money, authorization, options={})
        post = {
          TxnReq: {
            Action: 'refund',
            OriginalTxnNumber: authorization
          }
        }

        add_invoice(post[:TxnReq], money, options)
        add_customer_data(post[:TxnReq], options)
        add_references(post[:TxnReq], options)
        add_purchase_details(post[:TxnReq], options)

        commit(:post, 'txns', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization:\s)([A-Za-z0-9\-\._~\+\/]+=*)/, '\1[FILTERED]').
          gsub(/(CardDetails.+"CardNumber\\?\\?\\?":\\?\\?\\?")(\d+)/, '\1[FILTERED]').
          gsub(/(CardDetails.+"CVN\\?\\?\\?":\\?\\?\\?")(\d+)/, '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:Customer] = {
          ContactDetails: {
            EmailAddress: options[:email],
            FaxNumber: options.fetch(:fax_number, ''),
            HomePhoneNumber: options.fetch(:home_phone, ''),
            MobilePhoneNumber: options.fetch(:mobile_phone, ''),
            WorkPhoneNumber: options.fetch(:work_phone, '')
          },
          PersonalDetails: {
            DateOfBirth: options.fetch(:dob, ''),
            FirstName: options.fetch(:first_name, ''),
            LastName: options.fetch(:last_name, ''),
            MiddleName: options.fetch(:middle_name, ''),
            Salutation: options.fetch(:salutation, '')
          },
          CustomerNumber: options.fetch(:customer_number, ''),
          ExistingCustomer: options.fetch(:existing_customer, false)
        }

        add_address(post[:Customer], options[:address]) if options.has_key?(:address)
      end

      def add_address(post, address)
        post[:Address] = {
          AddressLine1: address[:address1],
          AddressLine2: address[:address2],
          AddressLine3: address[:address3],
          City: address[:city],
          CountryCode: address[:country],
          PostCode: address[:zip],
          State: address[:state]
        }
      end

      def add_invoice(post, money, options)
        post[:Amount] = amount(money).to_i
        post[:AmountOriginal] = options[:original_amount] if options[:original_amount]
        post[:AmountSurcharge] = options[:surcharge_amount] if options[:surcharge_amount]
        post[:Currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        if payment.is_a?(CreditCard)
          post[:CardDetails] = {
            CardHolderName: payment.name,
            CardNumber: payment.number,
            ExpiryDate: expdate(payment),
          }
          post[:CardDetails][:CVN] = payment.verification_value if payment.verification_value?
        else
          post[:CardDetails] = {
            CardNumber: payment
          }
        end
      end

      # TokenisationMode
      #   Surcharge amount for payment - this field is for information and
      #   reporting only and does not alter the value of the transaction.
      # Source
      #   api | callcentre | customerportal | internet | invoiceportal
      #   ishop | ivr | MySuite | mobilebackoffice | sftp | unknown
      # StoreCard
      #   Flag to indicate whether the cardholder agrees to save their card
      #   details.
      # SubType
      #   single | recurring
      # Type
      #   callcentre | cardpresent | ecommerce | internet | ivr | mailorder |
      #   telephoneorder
      #
      def add_purchase_details(post, options)
        post[:InternalNote] = options.fetch(:internal_note, '')
        post[:PaymentReason] = options.fetch(:payment_reason, '')
        post[:TokenisationMode] = options.fetch(:tokenisation_mode, 0)
        post[:SettlementDate] = options.fetch(:settlement_date, '')
        post[:Source] = options.fetch(:source, '')
        post[:StoreCard] = options.fetch(:store_card, false)
        post[:SubType] = options.fetch(:sub_type, 'single')
        post[:TestMode] = test?
        post[:Type] = options.fetch(:type, 'cardpresent')
      end

      # AcceptBADirectDebitTC: Set to true if the customer has agreed to the
      #   terms and conditions for tokenising their bank account details.
      def add_bank_details(post, options)
        post[:AcceptBADirectDebitTC] = options[:tokenise_bank_account_details] || true
        if %w(account_name account_number bsb_number).any? { |k| options.has_key?(k) }
          post[:BankAccountDetails] = {
            AccountName: options[:account_name],
            AccountNumber: options[:account_number],
            BSBNumber: options[:bsb_number]
          }
        end
      end

      def add_references(post, options)
        post[:Reference1] = options.fetch(:reference_1, "Default Reference1 Message")
        post[:Reference2] = options[:reference_2] if options.has_key?(:reference_2)
        post[:Reference3] = options[:reference_3] if options.has_key?(:reference_3)
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(verb, action, parameters)
        url = (test? ? test_url : live_url) + action
        response = parse(ssl_request(verb, url, post_data(verb, parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response.dig('APIResponse', 'ResponseText') == 'Success'
      end

      def message_from(response)
        response.dig('TokenResp', 'ResponseText') || response.dig('APIResponse', 'ResponseText')
      end

      def authorization_from(action, response)
        if action == 'tokens'
          response.dig('TokenResp', 'Token')
        elsif action == 'txns/search'
          response.dig('TokenResp', 'TxnRespList')
        else
          response.dig('TxnResp', 'TxnNumber') || response.dig('TxnResp', 'ReceiptNumber')
        end
      end

      def post_data(action, parameters = {})
        return nil if action == :get || parameters.nil?

        parameters.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          response.dig('APIResponse', 'ResponseCode') || response.dig('APIResponse', 'ResponseText')
        end
      end
    end
  end
end
