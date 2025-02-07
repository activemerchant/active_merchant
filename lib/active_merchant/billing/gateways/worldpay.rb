require 'nokogiri'

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class WorldpayGateway < Gateway
      self.test_url = 'https://secure-test.worldpay.com/jsp/merchant/xml/paymentService.jsp'
      self.live_url = 'https://secure.worldpay.com/jsp/merchant/xml/paymentService.jsp'

      self.default_currency = 'GBP'
      self.money_format = :cents
      self.supported_countries = %w(AD AE AG AI AL AM AO AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BM BN BO BR BS BT BW
                                    BY BZ CA CC CF CH CK CL CM CN CO CR CV CX CY CZ DE DJ DK DO DZ EC EE EG EH ES ET FI FJ FK
                                    FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GT GU GW GY HK HM HN HR HT HU ID IE IL
                                    IM IN IO IS IT JE JM JO JP KE KG KH KI KM KN KR KW KY KZ LA LC LI LK LS LT LU LV MA MC MD
                                    ME MG MH MK ML MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ
                                    OM PA PE PF PH PK PL PN PR PT PW PY QA RE RO RS RU RW SA SB SC SE SG SI SK SL SM SN ST SV
                                    SZ TC TD TF TG TH TJ TK TM TO TR TT TV TW TZ UA UG US UY UZ VA VC VE VI VN VU WF WS YE YT
                                    ZA ZM)
      self.supported_cardtypes = %i[visa master american_express discover jcb maestro elo naranja cabal unionpay patagonia_365]
      self.currencies_without_fractions = %w(HUF IDR JPY KRW BEF XOF XAF XPF GRD GNF ITL LUF MGA MGF PYG PTE RWF ESP TRL VND KMF)
      self.currencies_with_three_decimal_places = %w(BHD KWD OMR TND LYD JOD IQD)
      self.homepage_url = 'http://www.worldpay.com/'
      self.display_name = 'Worldpay Global'

      NETWORK_TOKEN_TYPE = {
        apple_pay: 'APPLEPAY',
        google_pay: 'GOOGLEPAY',
        network_token: 'NETWORKTOKEN'
      }

      AVS_CODE_MAP = {
        'A' => 'M', # Match
        'B' => 'P', # Postcode matches, address not verified
        'C' => 'Z', # Postcode matches, address does not match
        'D' => 'B', # Address matched; postcode not checked
        'E' => 'I', # Address and postal code not checked
        'F' => 'A', # Address matches, postcode does not match
        'G' => 'C', # Address does not match, postcode not checked
        'H' => 'I', # Address and postcode not provided
        'I' => 'C', # Address not checked postcode does not match
        'J' => 'C' # Address and postcode does not match
      }

      CVC_CODE_MAP = {
        'A' => 'M', # CVV matches
        'B' => 'P', # Not provided
        'C' => 'P', # Not checked
        'D' => 'N' # Does not match
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment_method, options = {})
        MultiResponse.run do |r|
          r.process { authorize(money, payment_method, options) }
          r.process { capture(money, r.authorization, options.merge(authorization_validated: true)) } unless options[:skip_capture]
        end
      end

      def authorize(money, payment_method, options = {})
        requires!(options, :order_id)
        payment_details = payment_details(payment_method, options)
        if options[:account_funding_transaction]
          aft_request(money, payment_method, payment_details.merge(**options))
        else
          authorize_request(money, payment_method, payment_details.merge(options))
        end
      end

      def capture(money, authorization, options = {})
        authorization = order_id_from_authorization(authorization.to_s)
        MultiResponse.run do |r|
          r.process { inquire_request(authorization, options, 'AUTHORISED', 'CAPTURED') } unless options[:authorization_validated]
          if r.params
            authorization_currency = r.params['amount_currency_code']
            options = options.merge(currency: authorization_currency) if authorization_currency.present?
          end
          r.process { capture_request(money, authorization, options) }
        end
      end

      def void(authorization, options = {})
        authorization = order_id_from_authorization(authorization.to_s)
        MultiResponse.run do |r|
          r.process { inquire_request(authorization, options, 'AUTHORISED') } unless options[:authorization_validated]
          r.process { cancel_request(authorization, options) }
        end
      end

      def refund(money, authorization, options = {})
        authorization = order_id_from_authorization(authorization.to_s)
        success_criteria = %w(CAPTURED SETTLED SETTLED_BY_MERCHANT SENT_FOR_REFUND)
        success_criteria.push('AUTHORIZED') if options[:cancel_or_refund]
        response = MultiResponse.run do |r|
          r.process { inquire_request(authorization, options, *success_criteria) } unless options[:authorization_validated]
          r.process { refund_request(money, authorization, options) }
        end

        if !response.success? && options[:force_full_refund_if_unsettled] &&
           response.params['last_event'] == 'AUTHORISED'
          void(authorization, options)
        else
          response
        end
      end

      # Credits only function on a Merchant ID/login/profile flagged for Payouts
      #   aka Credit Fund Transfers (CFT), whereas normal purchases, refunds,
      #   and other transactions should be performed on a normal eCom-flagged
      #   merchant ID.
      def credit(money, payment_method, options = {})
        payment_details = payment_details(payment_method, options)
        if options[:fast_fund_credit]
          fast_fund_credit_request(money, payment_method, payment_details.merge(credit: true, **options))
        elsif options[:account_funding_transaction]
          aft_request(money, payment_method, payment_details.merge(**options))
        else
          credit_request(money, payment_method, payment_details.merge(credit: true, **options))
        end
      end

      def verify(payment_method, options = {})
        amount = (eligible_for_0_auth?(payment_method, options) ? 0 : 100)
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, payment_method, options) }
          r.process(:ignore_result) { void(r.authorization, options.merge(authorization_validated: true)) }
        end
      end

      def store(credit_card, options = {})
        requires!(options, :customer)
        store_request(credit_card, options)
      end

      def inquire(authorization, options = {})
        order_id = order_id_from_authorization(authorization.to_s) || options[:order_id]
        commit('direct_inquiry', build_order_inquiry_request(order_id, options), :ok, options)
      end

      def supports_scrubbing
        true
      end

      def supports_network_tokenization?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<cardNumber>)\d+(</cardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<cvc>)[^<]+(</cvc>)), '\1[FILTERED]\2').
          gsub(%r((<tokenNumber>)\d+(</tokenNumber>)), '\1[FILTERED]\2').
          gsub(%r((<cryptogram>)[^<]+(</cryptogram>)), '\1[FILTERED]\2').
          gsub(%r((<accountReference accountType="\w+">)\d+(<\/accountReference>)), '\1[FILTERED]\2')
      end

      private

      def eci_value(payment_method, options)
        eci = payment_method.respond_to?(:eci) ? format(payment_method.eci, :two_digits) : ''

        return eci unless eci.empty?

        options[:use_default_eci] ? '07' : eci
      end

      def authorize_request(money, payment_method, options)
        commit('authorize', build_authorization_request(money, payment_method, options), 'AUTHORISED', 'CAPTURED', options)
      end

      def capture_request(money, authorization, options)
        commit('capture', build_capture_request(money, authorization, options), 'CAPTURED', :ok, options)
      end

      def cancel_request(authorization, options)
        commit('cancel', build_void_request(authorization, options), :ok, options)
      end

      def inquire_request(authorization, options, *success_criteria)
        commit('inquiry', build_order_inquiry_request(authorization, options), *success_criteria, options)
      end

      def refund_request(money, authorization, options)
        commit('refund', build_refund_request(money, authorization, options), :ok, 'SENT_FOR_REFUND', options)
      end

      def credit_request(money, payment_method, options)
        commit('credit', build_authorization_request(money, payment_method, options), :ok, 'SENT_FOR_REFUND', options)
      end

      def fast_fund_credit_request(money, payment_method, options)
        commit('fast_credit', build_fast_fund_credit_request(money, payment_method, options), :ok, 'PUSH_APPROVED', options)
      end

      def aft_request(money, payment_method, options)
        commit('funding_transfer_transaction', build_aft_request(money, payment_method, options), :ok, 'AUTHORISED', options)
      end

      def store_request(credit_card, options)
        commit('store', build_store_request(credit_card, options), options)
      end

      def build_request
        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct! :xml, encoding: 'UTF-8'
        xml.declare! :DOCTYPE, :paymentService, :PUBLIC, '-//WorldPay//DTD WorldPay PaymentService v1//EN', 'http://dtd.worldpay.com/paymentService_v1.dtd'
        xml.paymentService 'version' => '1.4', 'merchantCode' => @options[:login] do
          yield xml
        end
        xml.target!
      end

      def build_order_modify_request(authorization)
        build_request do |xml|
          xml.modify do
            xml.orderModification 'orderCode' => authorization do
              yield xml
            end
          end
        end
      end

      def build_order_inquiry_request(authorization, options)
        build_request do |xml|
          xml.inquiry do
            xml.orderInquiry 'orderCode' => authorization
          end
        end
      end

      def build_authorization_request(money, payment_method, options)
        build_request do |xml|
          xml.submit do
            xml.order order_tag_attributes(options) do
              xml.description(options[:description].blank? ? 'Purchase' : options[:description])
              add_amount(xml, money, options)
              add_order_content(xml, options)
              add_payment_method(xml, money, payment_method, options)
              add_shopper(xml, options)
              add_fraud_sight_data(xml, options)
              add_statement_narrative(xml, options)
              add_risk_data(xml, options[:risk_data]) if options[:risk_data]
              add_sub_merchant_data(xml, options[:sub_merchant_data]) if options[:sub_merchant_data]
              add_hcg_additional_data(xml, options) if options[:hcg_additional_data]
              add_instalments_data(xml, options) if options[:instalments]
              add_additional_data(xml, money, options) if options[:level_2_data] || options[:level_3_data]
              add_moto_flag(xml, options) if options.dig(:metadata, :manual_entry)
              add_additional_3ds_data(xml, options) if options[:execute_threed] && options[:three_ds_version] && options[:three_ds_version] =~ /^2/
              add_3ds_exemption(xml, options) if options[:exemption_type]
            end
          end
        end
      end

      def add_additional_data(xml, amount, options)
        level_two_data = options[:level_2_data] || {}
        level_three_data = options[:level_3_data] || {}
        level_two_and_three_data = level_two_data.merge(level_three_data).symbolize_keys

        xml.branchSpecificExtension do
          xml.purchase do
            add_level_two_and_three_data(xml, amount, level_two_and_three_data)
          end
        end
      end

      def add_level_two_and_three_data(xml, amount, data)
        xml.invoiceReferenceNumber data[:invoice_reference_number] if data.include?(:invoice_reference_number)
        xml.customerReference data[:customer_reference] if data.include?(:customer_reference)
        xml.cardAcceptorTaxId data[:card_acceptor_tax_id] if data.include?(:card_acceptor_tax_id)
        {
          tax_amount: 'salesTax',
          discount_amount: 'discountAmount',
          shipping_amount: 'shippingAmount',
          duty_amount: 'dutyAmount'
        }.each do |key, tag|
          next unless data.include?(key)

          xml.tag! tag do
            add_amount(xml, data[key].to_i, data)
          end
        end

        add_optional_data_level_two_and_three(xml, data)

        data[:line_items].each { |item| add_line_items_into_level_three_data(xml, item.symbolize_keys, data) } if data.include?(:line_items)
      end

      def add_line_items_into_level_three_data(xml, item, data)
        xml.item do
          xml.description item[:description] if item[:description]
          xml.productCode item[:product_code] if item[:product_code]
          xml.commodityCode item[:commodity_code] if item[:commodity_code]
          xml.quantity item[:quantity] if item[:quantity]
          xml.unitCost do
            add_amount(xml, item[:unit_cost], data)
          end
          xml.unitOfMeasure item[:unit_of_measure] || 'each'
          xml.itemTotal do
            sub_total_amount = item[:quantity].to_i * (item[:unit_cost].to_i - item[:discount_amount].to_i)
            add_amount(xml, sub_total_amount, data)
          end
          xml.itemTotalWithTax do
            add_amount(xml, item[:total_amount], data)
          end
          xml.itemDiscountAmount do
            add_amount(xml, item[:discount_amount], data)
          end
          xml.taxAmount do
            add_amount(xml, item[:tax_amount], data)
          end
        end
      end

      def add_optional_data_level_two_and_three(xml, data)
        xml.shipFromPostalCode data[:ship_from_postal_code] if data.include?(:ship_from_postal_code)
        xml.destinationPostalCode data[:destination_postal_code] if data.include?(:destination_postal_code)
        xml.destinationCountryCode data[:destination_country_code] if data.include?(:destination_country_code)
        add_date_element(xml, 'orderDate', data[:order_date].symbolize_keys) if data.include?(:order_date)
        xml.taxExempt data[:tax_amount].to_i > 0 ? 'false' : 'true'
      end

      def order_tag_attributes(options)
        { 'orderCode' => clean_order_id(options[:order_id]), 'installationId' => options[:inst_id] || @options[:inst_id] }.reject { |_, v| !v.present? }
      end

      def clean_order_id(order_id)
        order_id.to_s.gsub(/(\s|\||<|>|'|")/, '')[0..64]
      end

      def add_order_content(xml, options)
        return unless options[:order_content]

        xml.orderContent do
          xml.cdata! options[:order_content]
        end
      end

      def build_capture_request(money, authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.capture do
            time = Time.now
            xml.date 'dayOfMonth' => time.day, 'month' => time.month, 'year' => time.year
            add_amount(xml, money, options)
          end
        end
      end

      def build_void_request(authorization, options)
        if options[:cancel_or_refund]
          build_order_modify_request(authorization, &:cancelOrRefund)
        else
          build_order_modify_request(authorization, &:cancel)
        end
      end

      def build_refund_request(money, authorization, options)
        build_order_modify_request(authorization) do |xml|
          if options[:cancel_or_refund]
            # Worldpay docs claim amount must be passed. This causes an error.
            xml.cancelOrRefund # { add_amount(xml, money, options.merge(debit_credit_indicator: 'credit')) }
          else
            xml.refund do
              add_amount(xml, money, options.merge(debit_credit_indicator: 'credit'))
            end
          end
        end
      end

      def build_store_request(credit_card, options)
        build_request do |xml|
          xml.submit do
            xml.paymentTokenCreate do
              add_authenticated_shopper_id(xml, options)
              xml.createToken
              xml.paymentInstrument do
                xml.cardDetails do
                  add_card(xml, credit_card, options)
                end
              end
              add_transaction_identifier(xml, options) if network_transaction_id(options)
            end
          end
        end
      end

      def network_transaction_id(options)
        options[:stored_credential_transaction_id] || options.dig(:stored_credential, :network_transaction_id)
      end

      def add_transaction_identifier(xml, options)
        xml.storedCredentials 'usage' => 'FIRST' do
          xml.schemeTransactionIdentifier network_transaction_id(options)
        end
      end

      def build_fast_fund_credit_request(money, payment_method, options)
        build_request do |xml|
          xml.submit do
            xml.order order_tag_attributes(options) do
              xml.description(options[:description].blank? ? 'Fast Fund Credit' : options[:description])
              add_amount(xml, money, options)
              add_order_content(xml, options)
              add_payment_details_for_ff_credit(xml, payment_method, options)

              if options[:email]
                xml.shopper do
                  xml.shopperEmailAddress options[:email]
                end
              end
            end
          end
        end
      end

      def build_aft_request(money, payment_method, options)
        build_request do |xml|
          xml.submit do
            xml.order order_tag_attributes(options) do
              xml.description(options[:description].blank? ? 'Account Funding Transaction' : options[:description])
              add_amount(xml, money, options)
              add_order_content(xml, options)
              add_payment_method(xml, money, payment_method, options)
              add_shopper(xml, options)
              add_sub_merchant_data(xml, options[:sub_merchant_data]) if options[:sub_merchant_data]
              add_aft_data(xml, payment_method, options)
            end
          end
        end
      end

      def add_aft_data(xml, payment_method, options)
        xml.fundingTransfer 'type' => options[:aft_type], 'category' => 'PULL_FROM_CARD' do
          xml.paymentPurpose options[:aft_payment_purpose] # Must be included for the recipient for following countries, otherwise optional: Argentina, Bangladesh, Chile, Columbia, Jordan, Mexico, Thailand, UAE, India cross-border
          xml.fundingParty 'type' => 'sender' do
            xml.accountReference options[:aft_sender_account_reference], 'accountType' => options[:aft_sender_account_type]
            xml.fullName do
              xml.first options.dig(:aft_sender_full_name, :first)
              xml.middle options.dig(:aft_sender_full_name, :middle)
              xml.last options.dig(:aft_sender_full_name, :last)
            end
            xml.fundingAddress do
              xml.address1 options.dig(:aft_sender_funding_address, :address1)
              xml.address2 options.dig(:aft_sender_funding_address, :address2)
              xml.postalCode options.dig(:aft_sender_funding_address, :postal_code)
              xml.city options.dig(:aft_sender_funding_address, :city)
              xml.state options.dig(:aft_sender_funding_address, :state)
              xml.countryCode options.dig(:aft_sender_funding_address, :country_code)
            end
          end
          xml.fundingParty 'type' => 'recipient' do
            xml.accountReference options[:aft_recipient_account_reference], 'accountType' => options[:aft_recipient_account_type]
            xml.fullName do
              xml.first options.dig(:aft_recipient_full_name, :first)
              xml.middle options.dig(:aft_recipient_full_name, :middle)
              xml.last options.dig(:aft_recipient_full_name, :last)
            end
            xml.fundingAddress do
              xml.address1 options.dig(:aft_recipient_funding_address, :address1)
              xml.address2 options.dig(:aft_recipient_funding_address, :address2)
              xml.postalCode options.dig(:aft_recipient_funding_address, :postal_code)
              xml.city options.dig(:aft_recipient_funding_address, :city)
              xml.state options.dig(:aft_recipient_funding_address, :state)
              xml.countryCode options.dig(:aft_recipient_funding_address, :country_code)
            end
            if options[:aft_recipient_funding_data]
              xml.fundingData do
                add_date_element(xml, 'birthDate', options[:aft_recipient_funding_data][:birth_date])
                xml.telephoneNumber options.dig(:aft_recipient_funding_data, :telephone_number)
              end
            end
          end
        end
      end

      def add_payment_details_for_ff_credit(xml, payment_method, options)
        xml.paymentDetails do
          xml.tag! 'FF_DISBURSE-SSL' do
            if payment_method.is_a?(CreditCard)
              add_card_for_ff_credit(xml, payment_method, options)
            else
              add_token_for_ff_credit(xml, payment_method, options)
            end
          end
          add_shopper_id(xml, options)
        end
      end

      def add_card_for_ff_credit(xml, payment_method, options)
        xml.recipient do
          xml.paymentInstrument do
            xml.cardDetails do
              add_card(xml, payment_method, options)
            end
          end
        end
      end

      def add_token_for_ff_credit(xml, payment_method, options)
        return unless payment_method.is_a?(String)

        token_details = token_details_from_authorization(payment_method)

        xml.tag! 'recipient', 'tokenScope' => token_details[:token_scope] do
          xml.paymentTokenID token_details[:token_id]
          add_authenticated_shopper_id(xml, token_details)
        end
      end

      def add_additional_3ds_data(xml, options)
        additional_data = { 'dfReferenceId' => options[:df_reference_id] }
        additional_data['challengeWindowSize'] = options[:browser_size] if options[:browser_size]

        xml.additional3DSData additional_data
      end

      def add_3ds_exemption(xml, options)
        xml.exemption 'type' => options[:exemption_type], 'placement' => options[:exemption_placement] || 'AUTHORISATION'
      end

      def add_risk_data(xml, risk_data)
        xml.riskData do
          add_authentication_risk_data(xml, risk_data[:authentication_risk_data])
          add_shopper_account_risk_data(xml, risk_data[:shopper_account_risk_data])
          add_transaction_risk_data(xml, risk_data[:transaction_risk_data])
        end
      end

      def add_authentication_risk_data(xml, authentication_risk_data)
        return unless authentication_risk_data

        timestamp = authentication_risk_data.fetch(:authentication_date, {})

        xml.authenticationRiskData('authenticationMethod' => authentication_risk_data[:authentication_method]) do
          xml.authenticationTimestamp do
            xml.date(
              'dayOfMonth' => timestamp[:day_of_month],
              'month' => timestamp[:month],
              'year' => timestamp[:year],
              'hour' => timestamp[:hour],
              'minute' => timestamp[:minute],
              'second' => timestamp[:second]
            )
          end
        end
      end

      def add_sub_merchant_data(xml, options)
        xml.subMerchantData do
          xml.pfId options[:pf_id] if options[:pf_id]
          xml.subName options[:sub_name] if options[:sub_name]
          xml.subId options[:sub_id] if options[:sub_id]
          xml.subStreet options[:sub_street] if options[:sub_street]
          xml.subCity options[:sub_city] if options[:sub_city]
          xml.subState options[:sub_state] if options[:sub_state]
          xml.subCountryCode options[:sub_country_code] if options[:sub_country_code]
          xml.subPostalCode options[:sub_postal_code] if options[:sub_postal_code]
          xml.subTaxId options[:sub_tax_id] if options[:sub_tax_id]
        end
      end

      def add_shopper_account_risk_data(xml, shopper_account_risk_data)
        return unless shopper_account_risk_data

        data = {
          'transactionsAttemptedLastDay' => shopper_account_risk_data[:transactions_attempted_last_day],
          'transactionsAttemptedLastYear' => shopper_account_risk_data[:transactions_attempted_last_year],
          'purchasesCompletedLastSixMonths' => shopper_account_risk_data[:purchases_completed_last_six_months],
          'addCardAttemptsLastDay' => shopper_account_risk_data[:add_card_attempts_last_day],
          'previousSuspiciousActivity' => shopper_account_risk_data[:previous_suspicious_activity],
          'shippingNameMatchesAccountName' => shopper_account_risk_data[:shipping_name_matches_account_name],
          'shopperAccountAgeIndicator' => shopper_account_risk_data[:shopper_account_age_indicator],
          'shopperAccountChangeIndicator' => shopper_account_risk_data[:shopper_account_change_indicator],
          'shopperAccountPasswordChangeIndicator' => shopper_account_risk_data[:shopper_account_password_change_indicator],
          'shopperAccountShippingAddressUsageIndicator' => shopper_account_risk_data[:shopper_account_shipping_address_usage_indicator],
          'shopperAccountPaymentAccountIndicator' => shopper_account_risk_data[:shopper_account_payment_account_indicator]
        }.reject { |_k, v| v.nil? }

        xml.shopperAccountRiskData(data) do
          add_date_element(xml, 'shopperAccountCreationDate', shopper_account_risk_data[:shopper_account_creation_date])
          add_date_element(xml, 'shopperAccountModificationDate', shopper_account_risk_data[:shopper_account_modification_date])
          add_date_element(xml, 'shopperAccountPasswordChangeDate', shopper_account_risk_data[:shopper_account_password_change_date])
          add_date_element(xml, 'shopperAccountShippingAddressFirstUseDate', shopper_account_risk_data[:shopper_account_shipping_address_first_use_date])
          add_date_element(xml, 'shopperAccountPaymentAccountFirstUseDate', shopper_account_risk_data[:shopper_account_payment_account_first_use_date])
        end
      end

      def add_transaction_risk_data(xml, transaction_risk_data)
        return unless transaction_risk_data

        data = {
          'shippingMethod' => transaction_risk_data[:shipping_method],
          'deliveryTimeframe' => transaction_risk_data[:delivery_timeframe],
          'deliveryEmailAddress' => transaction_risk_data[:delivery_email_address],
          'reorderingPreviousPurchases' => transaction_risk_data[:reordering_previous_purchases],
          'preOrderPurchase' => transaction_risk_data[:pre_order_purchase],
          'giftCardCount' => transaction_risk_data[:gift_card_count]
        }.reject { |_k, v| v.nil? }

        xml.transactionRiskData(data) do
          xml.transactionRiskDataGiftCardAmount do
            amount_hash = {
              'value' => transaction_risk_data.dig(:transaction_risk_data_gift_card_amount, :value),
              'currencyCode' => transaction_risk_data.dig(:transaction_risk_data_gift_card_amount, :currency),
              'exponent' => transaction_risk_data.dig(:transaction_risk_data_gift_card_amount, :exponent)
            }
            debit_credit_indicator = transaction_risk_data.dig(:transaction_risk_data_gift_card_amount, :debit_credit_indicator)
            amount_hash['debitCreditIndicator'] = debit_credit_indicator if debit_credit_indicator
            xml.amount(amount_hash)
          end
          add_date_element(xml, 'transactionRiskDataPreOrderDate', transaction_risk_data[:transaction_risk_data_pre_order_date])
        end
      end

      def add_date_element(xml, name, date)
        xml.tag! name do
          xml.date('dayOfMonth' => date[:day_of_month], 'month' => date[:month], 'year' => date[:year])
        end
      end

      def add_amount(xml, money, options)
        currency = options[:currency] || currency(money.to_i)

        amount_hash = {
          :value => localized_amount(money.to_i, currency),
          'currencyCode' => currency,
          'exponent' => currency_exponent(currency)
        }

        amount_hash['debitCreditIndicator'] = options[:debit_credit_indicator] if options[:debit_credit_indicator]

        xml.amount amount_hash
      end

      def add_payment_method(xml, amount, payment_method, options)
        case options[:payment_type]
        when :pay_as_order
          add_amount_for_pay_as_order(xml, amount, payment_method, options)
        when :encrypted_wallet
          add_encrypted_wallet(xml, payment_method)
        when :network_token
          add_network_tokenization_card(xml, payment_method, options)
        else
          add_card_or_token(xml, payment_method, options)
        end
      end

      def add_amount_for_pay_as_order(xml, amount, payment_method, options)
        if options[:merchant_code]
          xml.payAsOrder 'orderCode' => payment_method, 'merchantCode' => options[:merchant_code] do
            add_amount(xml, amount, options)
          end
        else
          xml.payAsOrder 'orderCode' => payment_method do
            add_amount(xml, amount, options)
          end
        end
      end

      def add_network_tokenization_card(xml, payment_method, options)
        source = payment_method.respond_to?(:source) ? payment_method.source : options[:wallet_type]
        token_type = NETWORK_TOKEN_TYPE.fetch(source, 'NETWORKTOKEN')

        xml.paymentDetails do
          xml.tag! 'EMVCO_TOKEN-SSL', 'type' => token_type do
            xml.tokenNumber payment_method.number
            xml.expiryDate do
              xml.date(
                'month' => format(payment_method.month, :two_digits),
                'year' => format(payment_method.year, :four_digits_year)
              )
            end
            name = card_holder_name(payment_method, options)
            xml.cardHolderName name if name.present?
            xml.cryptogram payment_method.payment_cryptogram unless should_send_payment_cryptogram?(options, payment_method)
            eci = eci_value(payment_method, options)
            xml.eciIndicator eci if eci.present?
          end
          add_stored_credential_options(xml, options)
          add_shopper_id(xml, options, false)
          add_three_d_secure(xml, options)
        end
      end

      def should_send_payment_cryptogram?(options, payment_method)
        wallet_type_google_pay?(options) ||
          (payment_method_apple_pay?(payment_method) &&
            merchant_initiated?(options))
      end

      def merchant_initiated?(options)
        options.dig(:stored_credential, :initiator) == 'merchant'
      end

      def add_encrypted_wallet(xml, payment_method)
        source = encrypted_wallet_source(payment_method.source)

        xml.paymentDetails do
          xml.tag! "#{source}-SSL" do
            if source == 'APPLEPAY'
              add_encrypted_apple_pay(xml, payment_method)
            else
              add_encrypted_google_pay(xml, payment_method)
            end
          end
        end
      end

      def add_encrypted_apple_pay(xml, payment_method)
        xml.header do
          xml.ephemeralPublicKey payment_method.payment_data.dig(:header, :ephemeralPublicKey)
          xml.publicKeyHash payment_method.payment_data.dig(:header, :publicKeyHash)
          xml.transactionId payment_method.payment_data.dig(:header, :transactionId)
        end
        xml.signature payment_method.payment_data[:signature]
        xml.version payment_method.payment_data[:version]
        xml.data payment_method.payment_data[:data]
      end

      def add_encrypted_google_pay(xml, payment_method)
        xml.protocolVersion payment_method.payment_data[:version]
        xml.signature payment_method.payment_data[:signature]
        xml.signedMessage payment_method.payment_data[:signed_message]
      end

      def add_card_or_token(xml, payment_method, options)
        xml.paymentDetails credit_fund_transfer_attribute(options) do
          if options[:payment_type] == :token
            add_token_details(xml, options)
          else
            add_card_details(xml, payment_method, options)
          end
          add_stored_credential_options(xml, options)
          add_shopper_id(xml, options)
          add_three_d_secure(xml, options)
        end
      end

      def add_token_details(xml, options)
        xml.tag! 'TOKEN-SSL', 'tokenScope' => options[:token_scope] do
          xml.paymentTokenID options[:token_id]
        end
      end

      def add_card_details(xml, payment_method, options)
        xml.tag! 'CARD-SSL' do
          add_card(xml, payment_method, options)
        end
      end

      def add_shopper_id(xml, options, with_session_id = true)
        session_params = {
          'shopperIPAddress' => options[:ip],
          'id' => with_session_id ? options[:session_id] : nil
        }.compact

        xml.session session_params if session_params.present?
      end

      def add_three_d_secure(xml, options)
        return unless three_d_secure = options[:three_d_secure]

        xml.info3DSecure do
          xml.threeDSVersion three_d_secure[:version]
          if three_d_secure[:version] && three_d_secure[:ds_transaction_id]
            xml.dsTransactionId three_d_secure[:ds_transaction_id]
          else
            xml.xid three_d_secure[:xid]
          end
          xml.cavv three_d_secure[:cavv]
          xml.eci three_d_secure[:eci]
        end
      end

      def add_card(xml, payment_method, options)
        xml.cardNumber payment_method.number
        xml.expiryDate do
          xml.date(
            'month' => format(payment_method.month, :two_digits),
            'year' => format(payment_method.year, :four_digits_year)
          )
        end
        name = card_holder_name(payment_method, options)
        xml.cardHolderName name if name.present?
        xml.cvc payment_method.verification_value

        add_address(xml, (options[:billing_address] || options[:address]), options)
      end

      def add_stored_credential_options(xml, options = {})
        if options[:stored_credential]
          add_stored_credential_using_normalized_fields(xml, options)
        elsif options[:stored_credential_usage]
          add_stored_credential_using_gateway_specific_fields(xml, options)
        end
      end

      def add_stored_credential_using_normalized_fields(xml, options)
        reason = case options[:stored_credential][:reason_type]
                 when 'installment' then 'INSTALMENT'
                 when 'recurring' then 'RECURRING'
                 when 'unscheduled' then 'UNSCHEDULED'
                 end
        is_initial_transaction = options[:stored_credential][:initial_transaction]
        stored_credential_params = generate_stored_credential_params(is_initial_transaction, reason, options[:stored_credential][:initiator])

        xml.storedCredentials stored_credential_params do
          xml.schemeTransactionIdentifier network_transaction_id(options) if send_network_transaction_id?(options)
        end
      end

      def add_stored_credential_using_gateway_specific_fields(xml, options)
        is_initial_transaction = options[:stored_credential_usage] == 'FIRST'
        stored_credential_params = generate_stored_credential_params(is_initial_transaction, options[:stored_credential_initiated_reason])

        xml.storedCredentials stored_credential_params do
          xml.schemeTransactionIdentifier options[:stored_credential_transaction_id] if options[:stored_credential_transaction_id] && !is_initial_transaction
        end
      end

      def send_network_transaction_id?(options)
        network_transaction_id(options) && !options.dig(:stored_credential, :initial_transaction) && options.dig(:stored_credential, :initiator) != 'cardholder'
      end

      def add_shopper(xml, options)
        return unless options[:execute_threed] || options[:email] || options[:customer]

        xml.shopper do
          xml.shopperEmailAddress options[:email] if options[:email]
          add_authenticated_shopper_id(xml, options)
          xml.browser do
            xml.acceptHeader options[:accept_header]
            xml.userAgentHeader options[:user_agent]
          end
        end
      end

      def add_fraud_sight_data(xml, options)
        return unless options[:custom_string_fields].is_a?(Hash)

        xml.tag! 'FraudSightData' do
          xml.tag! 'customStringFields' do
            options[:custom_string_fields].each do |key, value|
              # transform custom_string_field_1 into customStringField1, etc.
              formatted_key = key.to_s.camelize(:lower).to_sym
              xml.tag! formatted_key, value
            end
          end
        end
      end

      def add_statement_narrative(xml, options)
        xml.statementNarrative truncate(options[:statement_narrative], 50) if options[:statement_narrative]
      end

      def add_authenticated_shopper_id(xml, options)
        xml.authenticatedShopperID options[:customer] if options[:customer]
      end

      def add_address(xml, address, options)
        return unless address

        address = address_with_defaults(address)

        xml.cardAddress do
          xml.address do
            if m = /^\s*([^\s]+)\s+(.+)$/.match(address[:name])
              xml.firstName m[1]
              xml.lastName m[2]
            end
            xml.address1 address[:address1]
            xml.address2 address[:address2] if address[:address2]
            xml.postalCode address[:zip]
            xml.city address[:city]
            xml.state address[:state] unless address[:country] != 'US' && options[:execute_threed]
            xml.countryCode address[:country]
            xml.telephoneNumber address[:phone] if address[:phone]
          end
        end
      end

      def add_hcg_additional_data(xml, options)
        xml.hcgAdditionalData do
          options[:hcg_additional_data].each do |k, v|
            xml.param({ name: k.to_s }, v)
          end
        end
      end

      def add_instalments_data(xml, options)
        xml.thirdPartyData do
          xml.instalments options[:instalments]
          xml.cpf options[:cpf] if options[:cpf]
        end
      end

      def add_moto_flag(xml, options)
        xml.dynamicInteractionType 'type' => 'MOTO'
      end

      def address_with_defaults(address)
        address ||= {}
        address.delete_if { |_, v| v.blank? }
        address.reverse_merge!(default_address)
      end

      def default_address
        {
          zip: '0000',
          country: 'US',
          city: 'N/A',
          address1: 'N/A'
        }
      end

      def parse(action, xml)
        xml = xml.strip.gsub(/\&/, '&amp;')
        doc = Nokogiri::XML(xml, &:strict)
        doc.remove_namespaces!
        resp_params = { action: }

        parse_elements(doc.root, resp_params)
        extract_issuer_response(doc.root, resp_params)

        resp_params
      end

      def extract_issuer_response(doc, response)
        return unless issuer_response = doc.at_xpath('//paymentService//reply//orderStatus//payment//IssuerResponseCode')

        response[:issuer_response_code] = issuer_response['code']
        response[:issuer_response_description] = issuer_response['description']
      end

      def parse_elements(node, response)
        node_name = node.name.underscore
        node.attributes.each do |k, v|
          response["#{node_name}_#{k.underscore}".to_sym] = v.value
        end
        if node.elements.empty?
          response[node_name.to_sym] = node.text unless node.text.blank?
        else
          response[node_name.to_sym] = true unless node.name.blank?
          node.elements.each do |childnode|
            parse_elements(childnode, response)
          end
        end
      end

      def headers(options)
        @idempotency_key ||= options[:idempotency_key]

        headers = {
          'Content-Type' => 'text/xml',
          'Authorization' => encoded_credentials
        }

        # ensure cookie included on follow-up '3ds' and 'capture_request' calls, using the cookie saved from the preceding response
        # cookie should be present in options on the 3ds and capture calls, but also still saved in the instance var in case
        cookie = defined?(@cookie) ? @cookie : nil
        cookie = options[:cookie] || cookie
        headers['Cookie'] = cookie if cookie

        # Required because Worldpay does not accept duplicate idempotency keys
        # for different transactions, such as in the case of an authorize => capture flow.
        if @idempotency_key
          headers['Idempotency-Key'] = @idempotency_key
          @idempotency_key = SecureRandom.uuid
        end
        headers
      end

      def commit(action, request, *success_criteria, options)
        xml = ssl_post(url, request, headers(options))
        raw = parse(action, xml)

        if options[:execute_threed]
          raw[:cookie] = @cookie if defined?(@cookie)
          raw[:session_id] = options[:session_id]
          raw[:is3DSOrder] = true
        end
        success = success_from(action, raw, success_criteria)
        message = message_from(success, raw, success_criteria, action)

        Response.new(
          success,
          message,
          raw,
          authorization: authorization_from(action, raw, options),
          error_code: error_code_from(success, raw),
          test: test?,
          avs_result: AVSResult.new(code: AVS_CODE_MAP[raw[:avs_result_code_description]]),
          cvv_result: CVVResult.new(CVC_CODE_MAP[raw[:cvc_result_code_description]])
        )
      rescue Nokogiri::SyntaxError
        unparsable_response(xml)
      rescue ActiveMerchant::ResponseError => e
        if e.response.code.to_s == '401'
          return Response.new(false, 'Invalid credentials', {}, test: test?)
        else
          raise e
        end
      end

      def url
        test? ? self.test_url : self.live_url
      end

      def unparsable_response(raw_response)
        message = 'Unparsable response received from Worldpay. Please contact Worldpay if you continue to receive this message.'
        message += " (The raw response returned by the API was: #{raw_response.inspect})"
        return Response.new(false, message)
      end

      # Override the regular handle response so we can access the headers
      # Set-Cookie value is needed for 3DS transactions
      def handle_response(response)
        case response.code.to_i
        when 200...300
          cookie = response.header['Set-Cookie']&.match('^[^;]*')
          @cookie = cookie[0] if cookie
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def success_from(action, raw, success_criteria)
        success_criteria_success?(raw, success_criteria) || action_success?(action, raw)
      end

      def message_from(success, raw, success_criteria, action)
        return 'SUCCESS' if success

        raw[:iso8583_return_code_description] || raw[:error] || required_status_message(raw, success_criteria, action) || raw[:issuer_response_description]
      end

      # success_criteria can be:
      #   - a string or an array of strings (if one of many responses)
      #   - An array of strings if one of many responses could be considered a
      #     success.
      def success_criteria_success?(raw, success_criteria)
        return if raw[:error]

        raw[:ok].present? || (success_criteria.include?(raw[:last_event]) if raw[:last_event])
      end

      def action_success?(action, raw)
        case action
        when 'store'
          raw[:token].present?
        when 'direct_inquiry'
          raw[:last_event].present?
        else
          false
        end
      end

      def error_code_from(success, raw)
        raw[:iso8583_return_code_code] || raw[:error_code] || nil unless success == 'SUCCESS'
      end

      def required_status_message(raw, success_criteria, action)
        return if success_criteria.include?(raw[:last_event])
        return unless %w[cancel refund inquiry credit fast_credit].include?(action)

        "A transaction status of #{success_criteria.collect { |c| "'#{c}'" }.join(' or ')} is required."
      end

      def authorization_from(action, raw, options)
        order_id = order_id_from(raw)

        case action
        when 'store'
          authorization_from_token_details(
            order_id:,
            token_id: raw[:payment_token_id],
            token_scope: 'shopper',
            customer: options[:customer]
          )
        else
          order_id
        end
      end

      def order_id_from(raw)
        pair = raw.detect { |k, _v| k.to_s =~ /_order_code$/ }
        (pair ? pair.last : nil)
      end

      def authorization_from_token_details(options = {})
        [options[:order_id], options[:token_id], options[:token_scope], options[:customer]].join('|')
      end

      def order_id_from_authorization(authorization)
        token_details_from_authorization(authorization)[:order_id]
      end

      def token_details_from_authorization(authorization)
        order_id, token_id, token_scope, customer = authorization.split('|')

        token_details = {}
        token_details[:order_id] = order_id if order_id.present?
        token_details[:token_id] = token_id if token_id.present?
        token_details[:token_scope] = token_scope if token_scope.present?
        token_details[:customer] = customer if customer.present?

        token_details
      end

      def payment_details(payment_method, options = {})
        case payment_method
        when String
          token_type_and_details(payment_method)
        else
          payment_method_type(payment_method, options)
        end
      end

      def payment_method_type(payment_method, options)
        type = if payment_method.is_a?(NetworkTokenizationCreditCard)
                 payment_method.encrypted_wallet? ? :encrypted_wallet : :network_token
               else
                 wallet_type_google_pay?(options) ? :network_token : :credit
               end
        { payment_type: type }
      end

      def payment_method_apple_pay?(payment_method)
        return false unless payment_method.is_a?(NetworkTokenizationCreditCard)

        payment_method.source == :apple_pay
      end

      def wallet_type_google_pay?(options)
        options[:wallet_type] == :google_pay
      end

      def token_type_and_details(token)
        token_details = token_details_from_authorization(token)
        token_details[:payment_type] = token_details.has_key?(:token_id) ? :token : :pay_as_order

        token_details
      end

      def credit_fund_transfer_attribute(options)
        return unless options[:credit]

        { 'action' => 'REFUND' }
      end

      def encoded_credentials
        credentials = "#{@options[:login]}:#{@options[:password]}"
        "Basic #{[credentials].pack('m').strip}"
      end

      def currency_exponent(currency)
        return 0 if non_fractional_currency?(currency)
        return 3 if three_decimal_currency?(currency)

        return 2
      end

      def eligible_for_0_auth?(payment_method, options = {})
        payment_method.is_a?(CreditCard) && %w(visa master).include?(payment_method.brand) && options[:zero_dollar_auth]
      end

      def card_holder_name(payment_method, options)
        test? && options[:execute_threed] && !options[:three_ds_version]&.start_with?('2') ? '3D' : payment_method.name
      end

      def generate_stored_credential_params(is_initial_transaction, reason = nil, initiator = nil)
        customer_or_merchant = initiator == 'cardholder' ? 'customerInitiatedReason' : 'merchantInitiatedReason'

        stored_credential_params = {}
        stored_credential_params['usage'] = is_initial_transaction ? 'FIRST' : 'USED'

        return stored_credential_params if customer_or_merchant == 'customerInitiatedReason' && stored_credential_params['usage'] == 'USED'

        stored_credential_params[customer_or_merchant] = reason if reason
        stored_credential_params
      end

      def encrypted_wallet_source(source)
        case source
        when :apple_pay
          'APPLEPAY'
        when :google_pay
          'PAYWITHGOOGLE'
        else
          raise ArgumentError, 'Invalid encrypted wallet source'
        end
      end
    end
  end
end
