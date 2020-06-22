module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CtPaymentGateway < Gateway
      self.test_url = 'https://test.ctpaiement.ca/v1/'
      self.live_url = 'https://www.ctpaiement.com/v1/'

      self.supported_countries = %w[US CA]
      self.default_currency = 'CAD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club]

      self.homepage_url = 'http://www.ct-payment.com/'
      self.display_name = 'CT Payment'

      STANDARD_ERROR_CODE_MAPPING = {
        '14' => STANDARD_ERROR_CODE[:invalid_number],
        '05' => STANDARD_ERROR_CODE[:card_declined],
        'M6' => STANDARD_ERROR_CODE[:card_declined],
        '9068' => STANDARD_ERROR_CODE[:incorrect_number],
        '9067' => STANDARD_ERROR_CODE[:incorrect_number]
      }
      CARD_BRAND = {
        'american_express' => 'A',
        'master' => 'M',
        'diners_club' => 'I',
        'visa' => 'V',
        'discover' => 'O'
      }

      def initialize(options={})
        requires!(options, :api_key, :company_number, :merchant_number)
        super
      end

      def purchase(money, payment, options={})
        requires!(options, :order_id)
        post = {}
        add_terminal_number(post, options)
        add_money(post, money)
        add_operator_id(post, options)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        payment.is_a?(String) ? commit('purchaseWithToken', post) : commit('purchase', post)
      end

      def authorize(money, payment, options={})
        requires!(options, :order_id)
        post = {}
        add_money(post, money)
        add_terminal_number(post, options)
        add_operator_id(post, options)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        payment.is_a?(String) ? commit('preAuthorizationWithToken', post) : commit('preAuthorization', post)
      end

      def capture(money, authorization, options={})
        requires!(options, :order_id)
        post = {}
        add_invoice(post, money, options)
        add_money(post, money)
        add_customer_data(post, options)
        transaction_number, authorization_number, invoice_number = split_authorization(authorization)
        post[:OriginalTransactionNumber] = transaction_number
        post[:OriginalAuthorizationNumber] = authorization_number
        post[:OriginalInvoiceNumber] = invoice_number

        commit('completion', post)
      end

      def refund(money, authorization, options={})
        requires!(options, :order_id)
        post = {}
        add_invoice(post, money, options)
        add_money(post, money)
        add_customer_data(post, options)
        transaction_number, _, invoice_number = split_authorization(authorization)
        post[:OriginalTransactionNumber] = transaction_number
        post[:OriginalInvoiceNumber] = invoice_number

        commit('refundWithoutCard', post)
      end

      def credit(money, payment, options={})
        requires!(options, :order_id)
        post = {}
        add_terminal_number(post, options)
        add_money(post, money)
        add_operator_id(post, options)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        payment.is_a?(String) ? commit('refundWithToken', post) : commit('refund', post)
      end

      def void(authorization, options={})
        post = {}
        post[:InputType] = 'I'
        post[:LanguageCode] = 'E'
        transaction_number, _, invoice_number = split_authorization(authorization)
        post[:OriginalTransactionNumber] = transaction_number
        post[:OriginalInvoiceNumber] = invoice_number
        add_operator_id(post, options)
        add_customer_data(post, options)

        commit('void', post)
      end

      def verify(credit_card, options={})
        requires!(options, :order_id)
        post = {}
        add_terminal_number(post, options)
        add_operator_id(post, options)
        add_invoice(post, 0, options)
        add_payment(post, credit_card)
        add_address(post, credit_card, options)
        add_customer_data(post, options)

        commit('verifyAccount', post)
      end

      def store(credit_card, options={})
        requires!(options, :email)
        post = {
          LanguageCode: 'E',
          Name: credit_card.name.rjust(50, ' '),
          Email: options[:email].rjust(240, ' ')
        }
        add_operator_id(post, options)
        add_payment(post, credit_card)
        add_customer_data(post, options)

        commit('recur/AddUser', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((&?auth-api-key=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?payload=)[a-zA-Z%0-9=]+)i, '\1[FILTERED]').
          gsub(%r((&?token:)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?cardNumber:)[^&]*)i, '\1[FILTERED]')
      end

      private

      def add_terminal_number(post, options)
        post[:MerchantTerminalNumber] = options[:merchant_terminal_number] || ' ' * 5
      end

      def add_money(post, money)
        post[:Amount] = money.to_s.rjust(11, '0')
      end

      def add_operator_id(post, options)
        post[:OperatorID] = options[:operator_id] || '0' * 8
      end

      def add_customer_data(post, options)
        post[:CustomerNumber] = options[:customer_number] || '0' * 8
      end

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:CardHolderAddress] = "#{address[:address1]} #{address[:address2]} #{address[:city]} #{address[:state]}".rjust(20, ' ')
          post[:CardHolderPostalCode] = address[:zip].gsub(/\s+/, '').rjust(9, ' ')
        end
      end

      def add_invoice(post, money, options)
        post[:CurrencyCode] = options[:currency] || (currency(money) if money)
        post[:InvoiceNumber] = options[:order_id].rjust(12, '0')
        post[:InputType] = 'I'
        post[:LanguageCode] = 'E'
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          post[:Token] = split_authorization(payment)[3].strip
        else
          post[:CardType] = CARD_BRAND[payment.brand] || ' '
          post[:CardNumber] = payment.number.rjust(40, ' ')
          post[:ExpirationDate] = expdate(payment)
          post[:Cvv2Cvc2Number] = payment.verification_value
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def split_authorization(authorization)
        authorization.split(';')
      end

      def commit_raw(action, parameters)
        url = (test? ? test_url : live_url) + action
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['avsStatus']),
          cvv_result: CVVResult.new(response['cvv2Cvc2Status']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def commit(action, parameters)
        if action == 'void'
          commit_raw(action, parameters)
        else
          MultiResponse.run(true) do |r|
            r.process { commit_raw(action, parameters) }
            r.process {
              split_auth = split_authorization(r.authorization)
              auth = (action.include?('recur') ? split_auth[4] : split_auth[0])
              action.include?('recur') ? commit_raw('recur/ack', {ID: auth}) : commit_raw('ack', {TransactionNumber: auth})
            }
          end
        end
      end

      def success_from(response)
        return true if response['returnCode'] == '  00'
        return true if response['returnCode'] == 'true'
        return true if response['recurReturnCode'] == '  00'

        return false
      end

      def message_from(response)
        response['errorDescription'] || response['terminalDisp']&.strip
      end

      def authorization_from(response)
        "#{response['transactionNumber']};#{response['authorizationNumber']};"\
        "#{response['invoiceNumber']};#{response['token']};#{response['id']}"
      end

      def post_data(action, parameters = {})
        parameters[:CompanyNumber] = @options[:company_number]
        parameters[:MerchantNumber] = @options[:merchant_number]
        parameters = parameters.collect do |key, value|
          "#{key}=#{value}" unless value.nil? || value.empty?
        end.join('&')
        payload = Base64.strict_encode64(parameters)
        "auth-api-key=#{@options[:api_key]}&payload=#{payload}".strip
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['returnCode'].strip || response['recurReturnCode'.strip]] unless success_from(response)
      end
    end
  end
end
