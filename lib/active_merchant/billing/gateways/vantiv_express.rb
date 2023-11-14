require 'nokogiri'
require 'securerandom'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VantivExpressGateway < Gateway
      self.test_url = 'https://certtransaction.elementexpress.com'
      self.live_url = 'https://transaction.elementexpress.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb]

      self.homepage_url = 'http://www.elementps.com'
      self.display_name = 'Element'

      SERVICE_TEST_URL = 'https://certservices.elementexpress.com'
      SERVICE_LIVE_URL = 'https://services.elementexpress.com'

      NETWORK_TOKEN_TYPE = {
        apple_pay: 2,
        google_pay: 1
      }

      CARD_PRESENT_CODE = {
        'Unknown' => 1,
        'Present' => 2,
        'NotPresent' => 3
      }

      MARKET_CODE = {
        'AutoRental' => 1,
        'DirectMarketing' => 2,
        'ECommerce' => 3,
        'FoodRestaurant' => 4,
        'HotelLodging' => 5,
        'Petroleum' => 6,
        'Retail' => 7,
        'QSR' => 8,
        'Grocery' => 9
      }

      PAYMENT_TYPE = {
        'NotUsed' => 0,
        'Recurring' => 1,
        'Installment' => 2,
        'CardHolderInitiated' => 3,
        'CredentialOnFile' => 4
      }

      REVERSAL_TYPE = {
        'System' => 0,
        'Full' => 1,
        'Partial' => 2
      }

      SUBMISSION_TYPE = {
        'NotUsed' => 0,
        'Initial' => 1,
        'Subsequent' => 2,
        'Resubmission' => 3,
        'ReAuthorization' => 4,
        'DelayedCharges' => 5,
        'NoShow' => 6
      }

      LODGING_PPC = {
        'NonParticipant' => 0,
        'DollarLimit500' => 1,
        'DollarLimit1000' => 2,
        'DollarLimit1500' => 3
      }

      LODGING_SPC = {
        'Default' => 0,
        'Sale' => 1,
        'NoShow' => 2,
        'AdvanceDeposit' => 3
      }

      LODGING_CHARGE_TYPE = {
        'Default' => 0,
        'Restaurant' => 1,
        'GiftShop' => 2
      }

      TERMINAL_TYPE = {
        'Unknown' => 0,
        'PointOfSale' => 1,
        'ECommerce' => 2,
        'MOTO' => 3,
        'FuelPump' => 4,
        'ATM' => 5,
        'Voice' => 6,
        'Mobile' => 7,
        'WebSiteGiftCard' => 8
      }

      CARD_HOLDER_PRESENT_CODE = {
        'Default' => 0,
        'Unknown' => 1,
        'Present' => 2,
        'NotPresent' => 3,
        'MailOrder' => 4,
        'PhoneOrder' => 5,
        'StandingAuth' => 6,
        'ECommerce' => 7
      }

      CARD_INPUT_CODE = {
        'Default' => 0,
        'Unknown' => 1,
        'MagstripeRead' => 2,
        'ContactlessMagstripeRead' => 3,
        'ManualKeyed' => 4,
        'ManualKeyedMagstripeFailure' => 5,
        'ChipRead' => 6,
        'ContactlessChipRead' => 7,
        'ManualKeyedChipReadFailure' => 8,
        'MagstripeReadChipReadFailure' => 9,
        'MagstripeReadNonTechnicalFallback' => 10
      }

      CVV_PRESENCE_CODE = {
        'UseDefault' => 0,
        'NotProvided' => 1,
        'Provided' => 2,
        'Illegible' => 3,
        'CustomerIllegible' => 4
      }

      TERMINAL_CAPABILITY_CODE = {
        'Default' => 0,
        'Unknown' => 1,
        'NoTerminal' => 2,
        'MagstripeReader' => 3,
        'ContactlessMagstripeReader' => 4,
        'KeyEntered' => 5,
        'ChipReader' => 6,
        'ContactlessChipReader' => 7
      }

      TERMINAL_ENVIRONMENT_CODE = {
        'Default' => 0,
        'NoTerminal' => 1,
        'LocalAttended' => 2,
        'LocalUnattended' => 3,
        'RemoteAttended' => 4,
        'RemoteUnattended' => 5,
        'ECommerce' => 6
      }

      def initialize(options = {})
        requires!(options, :account_id, :account_token, :application_id, :acceptor_id, :application_name, :application_version)
        super
      end

      def purchase(money, payment, options = {})
        action = payment.is_a?(Check) ? 'CheckSale' : 'CreditCardSale'
        eci = payment.is_a?(NetworkTokenizationCreditCard) ? parse_eci(payment) : nil

        request = build_xml_request do |xml|
          xml.send(action, xmlns: live_url) do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, money, options, eci)
            add_terminal(xml, options, eci)
            add_address(xml, options)
            add_lodging(xml, options)
          end
        end

        commit(request, money, payment)
      end

      def authorize(money, payment, options = {})
        eci = payment.is_a?(NetworkTokenizationCreditCard) ? parse_eci(payment) : nil

        request = build_xml_request do |xml|
          xml.CreditCardAuthorization(xmlns: live_url) do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, money, options, eci)
            add_terminal(xml, options, eci)
            add_address(xml, options)
            add_lodging(xml, options)
          end
        end

        commit(request, money, payment)
      end

      def capture(money, authorization, options = {})
        trans_id, _, eci = authorization.split('|')
        options[:trans_id] = trans_id

        request = build_xml_request do |xml|
          xml.CreditCardAuthorizationCompletion(xmlns: live_url) do
            add_credentials(xml)
            add_transaction(xml, money, options, eci)
            add_terminal(xml, options, eci)
          end
        end

        commit(request, money)
      end

      def refund(money, authorization, options = {})
        trans_id, _, eci = authorization.split('|')
        options[:trans_id] = trans_id

        request = build_xml_request do |xml|
          xml.CreditCardReturn(xmlns: live_url) do
            add_credentials(xml)
            add_transaction(xml, money, options, eci)
            add_terminal(xml, options, eci)
          end
        end

        commit(request, money)
      end

      def credit(money, payment, options = {})
        eci = payment.is_a?(NetworkTokenizationCreditCard) ? parse_eci(payment) : nil

        request = build_xml_request do |xml|
          xml.CreditCardCredit(xmlns: live_url) do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, money, options, eci)
            add_terminal(xml, options, eci)
          end
        end

        commit(request, money, payment)
      end

      def void(authorization, options = {})
        trans_id, trans_amount, eci = authorization.split('|')
        options.merge!({ trans_id: trans_id, trans_amount: trans_amount, reversal_type: 1 })

        request = build_xml_request do |xml|
          xml.CreditCardReversal(xmlns: live_url) do
            add_credentials(xml)
            add_transaction(xml, trans_amount, options, eci)
            add_terminal(xml, options, eci)
          end
        end

        commit(request, trans_amount)
      end

      def store(payment, options = {})
        request = build_xml_request do |xml|
          xml.PaymentAccountCreate(xmlns: SERVICE_LIVE_URL) do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_payment_account(xml, payment, options[:payment_account_reference_number] || SecureRandom.hex(20))
            add_address(xml, options)
          end
        end

        commit(request, payment, nil, :store)
      end

      def verify(payment, options = {})
        eci = payment.is_a?(NetworkTokenizationCreditCard) ? parse_eci(payment) : nil

        request = build_xml_request do |xml|
          xml.CreditCardAVSOnly(xmlns: live_url) do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, 0, options, eci)
            add_terminal(xml, options, eci)
            add_address(xml, options)
          end
        end

        commit(request)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<AccountToken>).+?(</AccountToken>))i, '\1[FILTERED]\2').
          gsub(%r((<CardNumber>).+?(</CardNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<CVV>).+?(</CVV>))i, '\1[FILTERED]\2').
          gsub(%r((<AccountNumber>).+?(</AccountNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<RoutingNumber>).+?(</RoutingNumber>))i, '\1[FILTERED]\2')
      end

      private

      def add_credentials(xml)
        xml.Credentials do
          xml.AccountID @options[:account_id]
          xml.AccountToken @options[:account_token]
          xml.AcceptorID @options[:acceptor_id]
        end
        xml.Application do
          xml.ApplicationID @options[:application_id]
          xml.ApplicationName @options[:application_name]
          xml.ApplicationVersion @options[:application_version]
        end
      end

      def add_payment_method(xml, payment)
        if payment.is_a?(String)
          add_payment_account_id(xml, payment)
        elsif payment.is_a?(Check)
          add_echeck(xml, payment)
        elsif payment.is_a?(NetworkTokenizationCreditCard)
          add_network_tokenization_card(xml, payment)
        else
          add_credit_card(xml, payment)
        end
      end

      def add_payment_account(xml, payment, payment_account_reference_number)
        xml.PaymentAccount do
          xml.PaymentAccountType payment_account_type(payment)
          xml.PaymentAccountReferenceNumber payment_account_reference_number
        end
      end

      def add_payment_account_id(xml, payment)
        xml.PaymentAccount do
          xml.PaymentAccountID payment
        end
      end

      def add_transaction(xml, money, options = {}, network_token_eci = nil)
        xml.Transaction do
          xml.ReversalType REVERSAL_TYPE[options[:reversal_type]] || options[:reversal_type] if options[:reversal_type]
          xml.TransactionID options[:trans_id] if options[:trans_id]
          xml.TransactionAmount amount(money.to_i) if money
          xml.MarketCode market_code(money, options, network_token_eci) if options[:market_code] || money
          xml.ReferenceNumber options[:order_id].present? ? options[:order_id][0, 50] : SecureRandom.hex(20)
          xml.TicketNumber options[:ticket_number] || rand(1..999999)
          xml.MerchantSuppliedTransactionID options[:merchant_supplied_transaction_id] if options[:merchant_supplied_transaction_id]
          xml.PaymentType PAYMENT_TYPE[options[:payment_type]] || options[:payment_type] if options[:payment_type]
          xml.SubmissionType SUBMISSION_TYPE[options[:submission_type]] || options[:submission_type] if options[:submission_type]
          xml.DuplicateCheckDisableFlag 1 if options[:duplicate_check_disable_flag].to_s == 'true' || options[:duplicate_override_flag].to_s == 'true'
        end
      end

      def parse_eci(payment)
        eci = payment.eci
        eci[0] == '0' ? eci.sub!(/^0/, '') : eci
      end

      def market_code(money, options, network_token_eci)
        return 3 if network_token_eci

        MARKET_CODE[options[:market_code]] || options[:market_code] || 0
      end

      def add_lodging(xml, options)
        if options[:lodging]
          lodging = parse_lodging(options[:lodging])
          xml.ExtendedParameters do
            xml.Lodging do
              xml.LodgingAgreementNumber lodging[:agreement_number] if lodging[:agreement_number]
              xml.LodgingCheckInDate lodging[:check_in_date] if lodging[:check_in_date]
              xml.LodgingCheckOutDate lodging[:check_out_date] if lodging[:check_out_date]
              xml.LodgingRoomAmount lodging[:room_amount] if lodging[:room_amount]
              xml.LodgingRoomTax lodging[:room_tax] if lodging[:room_tax]
              xml.LodgingNoShowIndicator lodging[:no_show_indicator] if lodging[:no_show_indicator]
              xml.LodgingDuration lodging[:duration] if lodging[:duration]
              xml.LodgingCustomerName lodging[:customer_name] if lodging[:customer_name]
              xml.LodgingClientCode lodging[:client_code] if lodging[:client_code]
              xml.LodgingExtraChargesDetail lodging[:extra_charges_detail] if lodging[:extra_charges_detail]
              xml.LodgingExtraChargesAmounts lodging[:extra_charges_amounts] if lodging[:extra_charges_amounts]
              xml.LodgingPrestigiousPropertyCode lodging[:prestigious_property_code] if lodging[:prestigious_property_code]
              xml.LodgingSpecialProgramCode lodging[:special_program_code] if lodging[:special_program_code]
              xml.LodgingChargeType lodging[:charge_type] if lodging[:charge_type]
            end
          end
        end
      end

      def add_terminal(xml, options, network_token_eci = nil)
        options = parse_terminal(options)

        xml.Terminal do
          xml.TerminalID options[:terminal_id] || '01'
          xml.TerminalType options[:terminal_type] if options[:terminal_type]
          xml.CardPresentCode options[:card_present_code] || 0
          xml.CardholderPresentCode options[:card_holder_present_code] || 0
          xml.CardInputCode options[:card_input_code] || 0
          xml.CVVPresenceCode options[:cvv_presence_code] || 0
          xml.TerminalCapabilityCode options[:terminal_capability_code] || 0
          xml.TerminalEnvironmentCode options[:terminal_environment_code] || 0
          xml.MotoECICode network_token_eci || 7
          xml.PartialApprovedFlag options[:partial_approved_flag] if options[:partial_approved_flag]
        end
      end

      def add_credit_card(xml, payment)
        xml.Card do
          xml.CardNumber payment.number
          xml.ExpirationMonth format(payment.month, :two_digits)
          xml.ExpirationYear format(payment.year, :two_digits)
          xml.CardholderName "#{payment.first_name} #{payment.last_name}"
          xml.CVV payment.verification_value
        end
      end

      def add_echeck(xml, payment)
        xml.DemandDepositAccount do
          xml.AccountNumber payment.account_number
          xml.RoutingNumber payment.routing_number
          xml.DDAAccountType payment.account_type == 'checking' ? 0 : 1
        end
      end

      def add_network_tokenization_card(xml, payment)
        xml.Card do
          xml.CardNumber payment.number
          xml.ExpirationMonth format(payment.month, :two_digits)
          xml.ExpirationYear format(payment.year, :two_digits)
          xml.CardholderName "#{payment.first_name} #{payment.last_name}"
          xml.Cryptogram payment.payment_cryptogram
          xml.WalletType NETWORK_TOKEN_TYPE[payment.source]
        end
      end

      def add_address(xml, options)
        address = address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address]

        if address || shipping_address
          xml.Address do
            if address
              address[:email] ||= options[:email]

              xml.BillingAddress1 address[:address1] if address[:address1]
              xml.BillingAddress2 address[:address2] if address[:address2]
              xml.BillingCity address[:city] if address[:city]
              xml.BillingState address[:state] if address[:state]
              xml.BillingZipcode address[:zip] if address[:zip]
              xml.BillingEmail address[:email] if address[:email]
              xml.BillingPhone address[:phone_number] if address[:phone_number]
            end

            if shipping_address
              xml.ShippingAddress1 shipping_address[:address1] if shipping_address[:address1]
              xml.ShippingAddress2 shipping_address[:address2] if shipping_address[:address2]
              xml.ShippingCity shipping_address[:city] if shipping_address[:city]
              xml.ShippingState shipping_address[:state] if shipping_address[:state]
              xml.ShippingZipcode shipping_address[:zip] if shipping_address[:zip]
              xml.ShippingEmail shipping_address[:email] if shipping_address[:email]
              xml.ShippingPhone shipping_address[:phone_number] if shipping_address[:phone_number]
            end
          end
        end
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        root = doc.root.xpath('//response/*')

        root = doc.root.xpath('//Response/*') if root.empty?

        root.each do |node|
          if node.elements.empty?
            response[node.name.downcase] = node.text
          else
            node_name = node.name.downcase
            response[node_name] = {}

            node.elements.each do |childnode|
              response[node_name][childnode.name.downcase] = childnode.text
            end
          end
        end

        response
      end

      def parse_lodging(lodging)
        lodging[:prestigious_property_code] = LODGING_PPC[lodging[:prestigious_property_code]] || lodging[:prestigious_property_code] if lodging[:prestigious_property_code]
        lodging[:special_program_code] = LODGING_SPC[lodging[:special_program_code]] || lodging[:special_program_code] if lodging[:special_program_code]
        lodging[:charge_type] = LODGING_CHARGE_TYPE[lodging[:charge_type]] || lodging[:charge_type] if lodging[:charge_type]

        lodging
      end

      def parse_terminal(options)
        options[:terminal_type] = TERMINAL_TYPE[options[:terminal_type]] || options[:terminal_type]
        options[:card_present_code] = CARD_PRESENT_CODE[options[:card_present_code]] || options[:card_present_code]
        options[:card_holder_present_code] = CARD_HOLDER_PRESENT_CODE[options[:card_holder_present_code]] || options[:card_holder_present_code]
        options[:card_input_code] = CARD_INPUT_CODE[options[:card_input_code]] || options[:card_input_code]
        options[:cvv_presence_code] = CVV_PRESENCE_CODE[options[:cvv_presence_code]] || options[:cvv_presence_code]
        options[:terminal_capability_code] = TERMINAL_CAPABILITY_CODE[options[:terminal_capability_code]] || options[:terminal_capability_code]
        options[:terminal_environment_code] = TERMINAL_ENVIRONMENT_CODE[options[:terminal_environment_code]] || options[:terminal_environment_code]

        options
      end

      def commit(xml, amount = nil, payment = nil, action = nil)
        response = parse(ssl_post(url(action), xml, headers))
        success = success_from(response)

        Response.new(
          success,
          message_from(response),
          response,
          authorization: authorization_from(action, response, amount, payment),
          avs_result: success ? avs_from(response) : nil,
          cvv_result: success ? cvv_from(response) : nil,
          test: test?
        )
      end

      def authorization_from(action, response, amount, payment)
        return response.dig('paymentaccount', 'paymentaccountid') if action == :store

        if response['transaction']
          authorization = "#{response.dig('transaction', 'transactionid')}|#{amount}"
          authorization << "|#{parse_eci(payment)}" if payment.is_a?(NetworkTokenizationCreditCard)
          authorization
        end
      end

      def success_from(response)
        response['expressresponsecode'] == '0'
      end

      def message_from(response)
        response['expressresponsemessage']
      end

      def avs_from(response)
        AVSResult.new(code: response['card']['avsresponsecode']) if response['card']
      end

      def cvv_from(response)
        CVVResult.new(response['card']['cvvresponsecode']) if response['card']
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          yield(xml)
        end

        builder.to_xml
      end

      def payment_account_type(payment)
        return 0 unless payment.is_a?(Check)

        if payment.account_type == 'checking'
          1
        elsif payment.account_type == 'savings'
          2
        else
          3
        end
      end

      def url(action)
        if action == :store
          test? ? SERVICE_TEST_URL : SERVICE_LIVE_URL
        else
          test? ? test_url : live_url
        end
      end

      def headers
        {
          'Content-Type' => 'text/xml'
        }
      end
    end
  end
end
