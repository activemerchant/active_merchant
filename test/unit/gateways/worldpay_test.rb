require 'test_helper'

class WorldpayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = WorldpayGateway.new(
      login: 'testlogin',
      password: 'testpassword'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @token = '|99411111780163871111|shopper|59424549c291397379f30c5c082dbed8'
    @elo_credit_card = credit_card(
      '4514 1600 0000 0008',
      month: 10,
      year: 2020,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'elo'
    )
    @nt_credit_card = network_tokenization_credit_card(
      '4895370015293175',
      brand: 'visa',
      eci: 5,
      source: :network_token,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )
    @nt_credit_card_without_eci = network_tokenization_credit_card(
      '4895370015293175',
      source: :network_token,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )
    @credit_card_with_two_digits_year = credit_card(
      '4514 1600 0000 0008',
      month: 10,
      year: 22,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737'
    )
    @sodexo_voucher = credit_card('6060704495764400', brand: 'sodexo')
    @options = { order_id: 1 }
    @store_options = {
      customer: '59424549c291397379f30c5c082dbed8',
      email: 'wow@example.com'
    }
    @sub_merchant_options = {
      sub_merchant_data: {
        pf_id: '12345678901',
        sub_name: 'Example Shop',
        sub_id: '1234567'
      }
    }

    @apple_play_network_token = network_tokenization_credit_card(
      '4895370015293175',
      month: 10,
      year: 24,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      source: :apple_pay
    )

    @google_pay_network_token = network_tokenization_credit_card(
      '4444333322221111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '01',
      year: Time.new.year + 2,
      source: :google_pay,
      transaction_id: '123456789',
      eci: '05'
    )

    @google_pay_network_token_without_eci = network_tokenization_credit_card(
      '4444333322221111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '01',
      year: Time.new.year + 2,
      source: :google_pay,
      transaction_id: '123456789'
    )

    @level_two_data = {
      level_2_data: {
        invoice_reference_number: 'INV12233565',
        customer_reference: 'CUST00000101',
        card_acceptor_tax_id: 'VAT1999292',
        tax_amount: '20',
        ship_from_postal_code:  '43245',
        destination_postal_code: '54545',
        destination_country_code: 'CO',
        order_date: {
          day_of_month: Date.today.day,
          month: Date.today.month,
          year: Date.today.year
        }
      }
    }

    @level_three_data = {
      level_3_data: {
        customer_reference: 'CUST00000102',
        card_acceptor_tax_id: 'VAT1999285',
        tax_amount: '20',
        discount_amount: '1',
        shipping_amount: '50',
        duty_amount: '20',
        line_items: [{
          description: 'Laptop 14',
          product_code: 'LP00125',
          commodity_code: 'COM00125',
          quantity: '2',
          unit_cost: '1500',
          unit_of_measure: 'each',
          item_discount_amount: '200',
          discount_amount: '0',
          tax_amount: '500',
          total_amount: '4000'
        },
                     {
                       description: 'Laptop 15',
                       product_code: 'LP00120',
                       commodity_code: 'COM00125',
                       quantity: '2',
                       unit_cost: '1000',
                       unit_of_measure: 'each',
                       item_discount_amount: '200',
                       tax_amount: '500',
                       discount_amount: '0',
                       total_amount: '3000'
                     }]
      }
    }

    @aft_options = {
      account_funding_transaction: true,
      aft_type: 'A',
      aft_payment_purpose: '01',
      aft_sender_account_type: '02',
      aft_sender_account_reference: '4111111111111112',
      aft_sender_full_name: {
        first: 'First',
        middle: 'Middle',
        last: 'Sender'
      },
      aft_sender_funding_address: {
        address1: '123 Sender St',
        address2: 'Apt 1',
        postal_code: '12345',
        city: 'Senderville',
        state: 'NC',
        country_code: 'US'
      },
      aft_recipient_account_type: '03',
      aft_recipient_account_reference: '4111111111111111',
      aft_recipient_full_name: {
        first: 'First',
        middle: 'Middle',
        last: 'Recipient'
      },
      aft_recipient_funding_address: {
        address1: '123 Recipient St',
        address2: 'Apt 1',
        postal_code: '12345',
        city: 'Recipientville',
        state: 'NC',
        country_code: 'US'
      },
      aft_recipient_funding_data: {
        telephone_number: '123456789',
        birth_date: {
          day_of_month: '01',
          month: '01',
          year: '1980'
        }
      }
    }
  end

  def test_payment_type_for_network_card
    payment = @gateway.send(:payment_details, @nt_credit_card)[:payment_type]
    assert_equal payment, :network_token
  end

  def test_payment_type_returns_network_token_if_the_payment_method_responds_to_source_payment_cryptogram_and_eci
    payment_method = mock
    payment_method.stubs(source: nil, payment_cryptogram: nil, eci: nil)
    result = @gateway.send(:payment_details, payment_method)
    assert_equal({ payment_type: :network_token }, result)
  end

  def test_payment_type_returns_credit_if_the_payment_method_does_not_responds_to_source
    payment_method = mock
    payment_method.stubs(payment_cryptogram: nil, eci: nil)
    result = @gateway.send(:payment_details, payment_method)
    assert_equal({ payment_type: :credit }, result)
  end

  def test_payment_type_returns_credit_if_the_payment_method_does_not_responds_to_payment_cryptogram
    payment_method = mock
    payment_method.stubs(source: nil, eci: nil)
    result = @gateway.send(:payment_details, payment_method)
    assert_equal({ payment_type: :credit }, result)
  end

  def test_payment_type_returns_credit_if_the_payment_method_does_not_responds_to_eci
    payment_method = mock
    payment_method.stubs(source: nil, payment_cryptogram: nil)
    result = @gateway.send(:payment_details, payment_method)
    assert_equal({ payment_type: :credit }, result)
  end

  def test_payment_type_for_credit_card
    payment = @gateway.send(:payment_details, @credit_card)[:payment_type]
    assert_equal payment, :credit
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/4242424242424242/, data)
      assert_match(/cardHolderName/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  def test_successful_authorize_without_name
    credit_card = credit_card('4242424242424242', first_name: nil, last_name: nil)
    response = stub_comms do
      @gateway.authorize(@amount, credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/4242424242424242/, data)
      assert_no_match(/cardHolderName/, data)
      assert_match(/CARD-SSL/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  def test_successful_authorize_by_reference
    response = stub_comms do
      @gateway.authorize(@amount, @options[:order_id].to_s, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/payAsOrder/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  def test_exemption_in_request
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ exemption_type: 'LV', exemption_placement: 'AUTHENTICATION' }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/exemption/, data)
      assert_match(/AUTHENTICATION/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_risk_data_in_request
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(risk_data: risk_data))
    end.check_request do |_endpoint, data, _headers|
      doc = Nokogiri::XML(data)

      authentication_risk_data = doc.at_xpath('//riskData//authenticationRiskData')
      assert_equal(risk_data[:authentication_risk_data][:authentication_method], authentication_risk_data.attribute('authenticationMethod').value)

      timestamp = doc.at_xpath('//riskData//authenticationRiskData//authenticationTimestamp//date')
      assert_equal(risk_data[:authentication_risk_data][:authentication_date][:day_of_month], timestamp.attribute('dayOfMonth').value)
      assert_equal(risk_data[:authentication_risk_data][:authentication_date][:month], timestamp.attribute('month').value)
      assert_equal(risk_data[:authentication_risk_data][:authentication_date][:year], timestamp.attribute('year').value)
      assert_equal(risk_data[:authentication_risk_data][:authentication_date][:hour], timestamp.attribute('hour').value)
      assert_equal(risk_data[:authentication_risk_data][:authentication_date][:minute], timestamp.attribute('minute').value)
      assert_equal(risk_data[:authentication_risk_data][:authentication_date][:second], timestamp.attribute('second').value)

      shopper_account_risk_data_xml = doc.at_xpath('//riskData//shopperAccountRiskData')
      shopper_account_risk_data = risk_data[:shopper_account_risk_data]
      assert_equal(shopper_account_risk_data[:transactions_attempted_last_day], shopper_account_risk_data_xml.attribute('transactionsAttemptedLastDay').value)
      assert_equal(shopper_account_risk_data[:transactions_attempted_last_year], shopper_account_risk_data_xml.attribute('transactionsAttemptedLastYear').value)
      assert_equal(shopper_account_risk_data[:purchases_completed_last_six_months], shopper_account_risk_data_xml.attribute('purchasesCompletedLastSixMonths').value)
      assert_equal(shopper_account_risk_data[:add_card_attempts_last_day], shopper_account_risk_data_xml.attribute('addCardAttemptsLastDay').value)
      assert_equal(shopper_account_risk_data[:previous_suspicious_activity], shopper_account_risk_data_xml.attribute('previousSuspiciousActivity').value)
      assert_equal(shopper_account_risk_data[:shipping_name_matches_account_name], shopper_account_risk_data_xml.attribute('shippingNameMatchesAccountName').value)
      assert_equal(shopper_account_risk_data[:shopper_account_age_indicator], shopper_account_risk_data_xml.attribute('shopperAccountAgeIndicator').value)
      assert_equal(shopper_account_risk_data[:shopper_account_change_indicator], shopper_account_risk_data_xml.attribute('shopperAccountChangeIndicator').value)
      assert_equal(shopper_account_risk_data[:shopper_account_password_change_indicator], shopper_account_risk_data_xml.attribute('shopperAccountPasswordChangeIndicator').value)
      assert_equal(shopper_account_risk_data[:shopper_account_shipping_address_usage_indicator], shopper_account_risk_data_xml.attribute('shopperAccountShippingAddressUsageIndicator').value)
      assert_equal(shopper_account_risk_data[:shopper_account_payment_account_indicator], shopper_account_risk_data_xml.attribute('shopperAccountPaymentAccountIndicator').value)
      assert_date_element(shopper_account_risk_data[:shopper_account_creation_date], shopper_account_risk_data_xml.at_xpath('//shopperAccountCreationDate//date'))
      assert_date_element(shopper_account_risk_data[:shopper_account_modification_date], shopper_account_risk_data_xml.at_xpath('//shopperAccountModificationDate//date'))
      assert_date_element(shopper_account_risk_data[:shopper_account_password_change_date], shopper_account_risk_data_xml.at_xpath('//shopperAccountPasswordChangeDate//date'))
      assert_date_element(shopper_account_risk_data[:shopper_account_shipping_address_first_use_date], shopper_account_risk_data_xml.at_xpath('//shopperAccountShippingAddressFirstUseDate//date'))
      assert_date_element(shopper_account_risk_data[:shopper_account_payment_account_first_use_date], shopper_account_risk_data_xml.at_xpath('//shopperAccountPaymentAccountFirstUseDate//date'))

      transaction_risk_data_xml = doc.at_xpath('//riskData//transactionRiskData')
      transaction_risk_data = risk_data[:transaction_risk_data]
      assert_equal(transaction_risk_data[:shipping_method], transaction_risk_data_xml.attribute('shippingMethod').value)
      assert_equal(transaction_risk_data[:delivery_timeframe], transaction_risk_data_xml.attribute('deliveryTimeframe').value)
      assert_equal(transaction_risk_data[:delivery_email_address], transaction_risk_data_xml.attribute('deliveryEmailAddress').value)
      assert_equal(transaction_risk_data[:reordering_previous_purchases], transaction_risk_data_xml.attribute('reorderingPreviousPurchases').value)
      assert_equal(transaction_risk_data[:pre_order_purchase], transaction_risk_data_xml.attribute('preOrderPurchase').value)
      assert_equal(transaction_risk_data[:gift_card_count], transaction_risk_data_xml.attribute('giftCardCount').value)

      amount_xml = doc.at_xpath('//riskData//transactionRiskData//transactionRiskDataGiftCardAmount//amount')
      amount_data = transaction_risk_data[:transaction_risk_data_gift_card_amount]
      assert_equal(amount_data[:value], amount_xml.attribute('value').value)
      assert_equal(amount_data[:currency], amount_xml.attribute('currencyCode').value)
      assert_equal(amount_data[:exponent], amount_xml.attribute('exponent').value)
      assert_equal(amount_data[:debit_credit_indicator], amount_xml.attribute('debitCreditIndicator').value)

      assert_date_element(transaction_risk_data[:transaction_risk_data_pre_order_date], transaction_risk_data_xml.at_xpath('//transactionRiskDataPreOrderDate//date'))
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_reference_transaction_authorize_with_merchant_code
    response = stub_comms do
      @gateway.authorize(@amount, @options[:order_id].to_s, @options.merge({ merchant_code: 'testlogin2' }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/testlogin2/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  def test_authorize_passes_ip_and_session_id
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(ip: '127.0.0.1', session_id: '0215ui8ib1'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<session shopperIPAddress="127.0.0.1" id="0215ui8ib1"\/>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_passes_stored_credential_options
    options = @options.merge(
      stored_credential_usage: 'USED',
      stored_credential_initiated_reason: 'UNSCHEDULED',
      stored_credential_transaction_id: '000000000000020005060720116005060'
    )
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<storedCredentials usage\=\"USED\" merchantInitiatedReason\=\"UNSCHEDULED\"\>/, data)
      assert_match(/<schemeTransactionIdentifier\>000000000000020005060720116005060\<\/schemeTransactionIdentifier\>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_with_nt_passes_stored_credential_options
    options = @options.merge(
      stored_credential_usage: 'USED',
      stored_credential_initiated_reason: 'UNSCHEDULED',
      stored_credential_transaction_id: '000000000000020005060720116005060'
    )
    response = stub_comms do
      @gateway.authorize(@amount, @nt_credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<storedCredentials usage\=\"USED\" merchantInitiatedReason\=\"UNSCHEDULED\"\>/, data)
      assert_match(/<schemeTransactionIdentifier\>000000000000020005060720116005060\<\/schemeTransactionIdentifier\>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_with_nt_passes_standard_stored_credential_options
    stored_credential_params = stored_credential(:used, :unscheduled, :merchant, network_transaction_id: 20_005_060_720_116_005_060)
    response = stub_comms do
      @gateway.authorize(@amount, @nt_credit_card, @options.merge({ stored_credential: stored_credential_params }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<storedCredentials usage\=\"USED\" merchantInitiatedReason\=\"UNSCHEDULED\"\>/, data)
      assert_match(/<schemeTransactionIdentifier\>20005060720116005060\<\/schemeTransactionIdentifier\>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_passes_correct_stored_credential_options_for_first_recurring
    options = @options.merge(
      stored_credential_usage: 'FIRST',
      stored_credential_initiated_reason: 'RECURRING'
    )
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<storedCredentials usage\=\"FIRST\" customerInitiatedReason\=\"RECURRING\"\>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_passes_correct_stored_credential_options_for_used_recurring
    options = @options.merge(
      stored_credential_usage: 'USED',
      stored_credential_initiated_reason: 'RECURRING',
      stored_credential_transaction_id: '000000000000020005060720116005061'
    )
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<storedCredentials usage\=\"USED\" merchantInitiatedReason\=\"RECURRING\"\>/, data)
      assert_match(/<schemeTransactionIdentifier\>000000000000020005060720116005061\<\/schemeTransactionIdentifier\>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_passes_correct_stored_credentials_for_first_installment
    options = @options.merge(
      stored_credential_usage: 'FIRST',
      stored_credential_initiated_reason: 'INSTALMENT'
    )
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<storedCredentials usage\=\"FIRST\" merchantInitiatedReason\=\"INSTALMENT\"\>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_passes_sub_merchant_data
    options = @options.merge(@sub_merchant_options)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<pfId>12345678901</pfId>), data
      assert_match %r(<subName>Example Shop</subName>), data
      assert_match %r(<subId>1234567</subId>), data
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(failed_authorize_response)
    assert_equal '7', response.error_code
    assert_match 'Invalid payment details', response.message
    assert_failure response
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_transaction_with_level_two_data
    options = @options.merge(@level_two_data)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<invoiceReferenceNumber>INV12233565</invoiceReferenceNumber>), data
      assert_match %r(<customerReference>CUST00000101</customerReference>), data
      assert_match %r(<cardAcceptorTaxId>VAT1999292</cardAcceptorTaxId>), data
      assert_match %r(<salesTax><amountvalue="20"currencyCode="GBP"exponent="2"/></salesTax>), data.gsub(/\s+/, '')
      assert_match %r(<shipFromPostalCode>43245</shipFromPostalCode>), data
      assert_match %r(<destinationPostalCode>54545</destinationPostalCode>), data
      assert_match %r(<destinationCountryCode>CO</destinationCountryCode>), data
      assert_match %r(<taxExempt>false</taxExempt>), data
      assert_match %r(<orderDate><datedayOfMonth="#{Date.today.day}"month="#{Date.today.month}"year="#{Date.today.year}"/></orderDate>), data.gsub(/\s+/, '')
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_transaction_with_level_two_data_without_tax
    @level_two_data[:level_2_data][:tax_amount] = 0
    options = @options.merge(@level_two_data)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<invoiceReferenceNumber>INV12233565</invoiceReferenceNumber>), data
      assert_match %r(<customerReference>CUST00000101</customerReference>), data
      assert_match %r(<cardAcceptorTaxId>VAT1999292</cardAcceptorTaxId>), data
      assert_match %r(<salesTax><amountvalue="0"currencyCode="GBP"exponent="2"/></salesTax>), data.gsub(/\s+/, '')
      assert_match %r(<shipFromPostalCode>43245</shipFromPostalCode>), data
      assert_match %r(<destinationPostalCode>54545</destinationPostalCode>), data
      assert_match %r(<destinationCountryCode>CO</destinationCountryCode>), data
      assert_match %r(<taxExempt>true</taxExempt>), data
      assert_match %r(<orderDate><datedayOfMonth="#{Date.today.day}"month="#{Date.today.month}"year="#{Date.today.year}"/></orderDate>), data.gsub(/\s+/, '')
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_transaction_with_level_three_data
    options = @options.merge(@level_three_data)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<customerReference>CUST00000102</customerReference>), data
      assert_match %r(<cardAcceptorTaxId>VAT1999285</cardAcceptorTaxId>), data
      assert_match %r(<salesTax><amountvalue="20"currencyCode="GBP"exponent="2"/></salesTax>), data.gsub(/\s+/, '')
      assert_match %r(<discountAmount><amountvalue="1"currencyCode="GBP"exponent="2"/></discountAmount>), data.gsub(/\s+/, '')
      assert_match %r(<shippingAmount><amountvalue="50"currencyCode="GBP"exponent="2"/></shippingAmount>), data.gsub(/\s+/, '')
      assert_match %r(<dutyAmount><amountvalue="20"currencyCode="GBP"exponent="2"/></dutyAmount>), data.gsub(/\s+/, '')
      assert_match %r(<item><description>Laptop14</description><productCode>LP00125</productCode><commodityCode>COM00125</commodityCode><quantity>2</quantity><unitCost><amountvalue=\"1500\"currencyCode=\"GBP\"exponent=\"2\"/></unitCost><unitOfMeasure>each</unitOfMeasure><itemTotal><amountvalue=\"3000\"currencyCode=\"GBP\"exponent=\"2\"/></itemTotal><itemTotalWithTax><amountvalue=\"4000\"currencyCode=\"GBP\"exponent=\"2\"/></itemTotalWithTax><itemDiscountAmount><amountvalue=\"0\"currencyCode=\"GBP\"exponent=\"2\"/></itemDiscountAmount><taxAmount><amountvalue=\"500\"currencyCode=\"GBP\"exponent=\"2\"/></taxAmount></item><item><description>Laptop15</description><productCode>LP00120</productCode><commodityCode>COM00125</commodityCode><quantity>2</quantity><unitCost><amountvalue=\"1000\"currencyCode=\"GBP\"exponent=\"2\"/></unitCost><unitOfMeasure>each</unitOfMeasure><itemTotal><amountvalue=\"2000\"currencyCode=\"GBP\"exponent=\"2\"/></itemTotal><itemTotalWithTax><amountvalue=\"3000\"currencyCode=\"GBP\"exponent=\"2\"/></itemTotalWithTax><itemDiscountAmount><amountvalue=\"0\"currencyCode=\"GBP\"exponent=\"2\"/></itemDiscountAmount><taxAmount><amountvalue=\"500\"currencyCode=\"GBP\"exponent=\"2\"/></taxAmount></item>), data.gsub(/\s+/, '')
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_purchase_with_sub_merchant_data
    options = @options.merge(@sub_merchant_options)
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_successful_purchase_skipping_capture
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(skip_capture: true))
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert response.responses.length == 1
    assert_success response
  end

  def test_successful_purchase_with_network_token
    response = stub_comms do
      @gateway.purchase(@amount, @nt_credit_card, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_successful_authorize_with_network_token_with_eci
    response = stub_comms do
      @gateway.authorize(@amount, @nt_credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<eciIndicator>05</eciIndicator>), data
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_authorize_with_network_token_with_shopper_ip_address
    response = stub_comms do
      @gateway.authorize(@amount, @nt_credit_card, @options.merge(ip: '127.0.0.1', email: 'wow@example.com'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<session shopperIPAddress=\"127.0.0.1\"\/>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_purchase_with_elo
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'BRL'))
    end.respond_with(successful_authorize_with_elo_response, successful_capture_with_elo_response)
    assert_success response
  end

  def test_purchase_passes_correct_currency
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'CAD'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/CAD/, data)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_successful_purchase_with_two_digits_year
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card_with_two_digits_year, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_purchase_authorize_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(failed_authorize_response)
    assert_failure response
    assert_equal '7', response.error_code
    assert_match 'Invalid payment details', response.message
    assert_equal 1, response.responses.size
  end

  def test_require_order_id
    assert_raise(ArgumentError) do
      @gateway.authorize(@amount, @credit_card)
    end
  end

  def test_purchase_does_not_run_inquiry
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal(%w(authorize capture), response.responses.collect { |e| e.params['action'] })
  end

  def test_failed_purchase_with_issuer_response_code
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(failed_purchase_response_with_issuer_response_code)

    assert_failure response
    assert_equal('51', response.params['issuer_response_code'])
    assert_equal('Insufficient funds/over credit limit', response.params['issuer_response_description'])
  end

  def test_failed_purchase_without_active_merchant_generated_response_message
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(failed_purchase_response_without_useful_error_from_gateway)

    assert_failure response
    assert_equal('61', response.params['issuer_response_code'])
    assert_equal('Exceeds withdrawal amount limit', response.message)
  end

  def test_successful_void
    response = stub_comms do
      @gateway.void(@options[:order_id], @options)
    end.respond_with(successful_void_inquiry_response, successful_void_response)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal '924e810350efc21a989e0ac7727ce43b', response.params['cancel_received_order_code']
  end

  def test_successful_void_with_elo
    response = stub_comms do
      @gateway.void(@options[:order_id], @options)
    end.respond_with(successful_void_inquiry_with_elo_response, successful_void_with_elo_response)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal '3a10f83fb9bb765488d0b3eb153879d7', response.params['cancel_received_order_code']
  end

  def test_void_fails_unless_status_is_authorized
    response = stub_comms do
      @gateway.void(@options[:order_id], @options)
    end.respond_with(failed_void_inquiry_response, successful_void_response)
    assert_failure response
    assert_equal "A transaction status of 'AUTHORISED' is required.", response.message
  end

  def test_supports_network_tokenization
    assert_instance_of TrueClass, @gateway.supports_network_tokenization?
  end

  def test_void_using_order_id_embedded_with_token
    response = stub_comms do
      authorization = "#{@options[:order_id]}|99411111780163871111|shopper|59424549c291397379f30c5c082dbed8"
      @gateway.void(authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('orderInquiry', { 'orderCode' => @options[:order_id].to_s }, data) if %r(<orderInquiry .*?>).match?(data)
      assert_tag_with_attributes('orderModification', { 'orderCode' => @options[:order_id].to_s }, data) if %r(<orderModification .*?>).match?(data)
    end.respond_with(successful_void_inquiry_response, successful_void_response)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal '924e810350efc21a989e0ac7727ce43b', response.params['cancel_received_order_code']
  end

  def test_successful_refund_for_captured_payment
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(successful_refund_inquiry_response('CAPTURED'), successful_refund_response)
    assert_success response
  end

  def test_successful_refund_for_settled_payment
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(successful_refund_inquiry_response('SETTLED'), successful_refund_response)
    assert_success response
    assert_equal '05d9f8c622553b1df1fe3a145ce91ccf', response.params['refund_received_order_code']
  end

  def test_successful_refund_for_settled_by_merchant_payment
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(successful_refund_inquiry_response('SETTLED_BY_MERCHANT'), successful_refund_response)
    assert_success response
    assert_equal '05d9f8c622553b1df1fe3a145ce91ccf', response.params['refund_received_order_code']
  end

  def test_refund_fails_unless_status_is_captured
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(failed_refund_inquiry_response, successful_refund_response)
    assert_failure response
    assert_equal "A transaction status of 'CAPTURED' or 'SETTLED' or 'SETTLED_BY_MERCHANT' or 'SENT_FOR_REFUND' is required.", response.message
  end

  def test_full_refund_for_unsettled_payment_forces_void
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options.merge(force_full_refund_if_unsettled: true))
    end.respond_with(failed_refund_inquiry_response, failed_refund_inquiry_response, successful_void_response)
    assert_success response
    assert 'cancel', response.responses.last.params['action']
  end

  def test_refund_failure_with_force_full_refund_if_unsettled_does_not_force_void
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options.merge(force_full_refund_if_unsettled: true))
    end.respond_with('total garbage')

    assert_failure response
  end

  def test_refund_using_order_id_embedded_with_token
    response = stub_comms do
      authorization = "#{@options[:order_id]}|99411111780163871111|shopper|59424549c291397379f30c5c082dbed8"
      @gateway.refund(@amount, authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('orderInquiry', { 'orderCode' => @options[:order_id].to_s }, data) if %r(<orderInquiry .*?>).match?(data)
      assert_tag_with_attributes('orderModification', { 'orderCode' => @options[:order_id].to_s }, data) if %r(<orderModification .*?>).match?(data)
    end.respond_with(successful_refund_inquiry_response('CAPTURED'), successful_refund_response)
    assert_success response
  end

  def test_capture
    response = stub_comms do
      response = @gateway.authorize(@amount, @credit_card, @options)
      @gateway.capture(@amount, response.authorization, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_capture_using_order_id_embedded_with_token
    response = stub_comms do
      response = @gateway.authorize(@amount, @credit_card, @options)
      authorization = "#{response.authorization}|99411111780163871111|shopper|59424549c291397379f30c5c082dbed8"
      @gateway.capture(@amount, authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('orderModification', { 'orderCode' => response.authorization }, data) if %r(<orderModification .*?>).match?(data)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_successful_visa_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<paymentDetails action="REFUND">/, data)
    end.respond_with(successful_visa_credit_response)
    assert_success response
    assert_equal '3d4187536044bd39ad6a289c4339c41c', response.authorization
  end

  def test_successful_mastercard_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<paymentDetails action="REFUND">/, data)
    end.respond_with(successful_mastercard_credit_response)
    assert_success response
    assert_equal 'f25257d251b81fb1fd9c210973c941ff', response.authorization
  end

  def test_successful_visa_account_funding_transaction
    response = stub_comms do
      @gateway.credit(@amount, @credit_card, @options.merge(@aft_options))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<fundingTransfer type="A" category="PULL_FROM_CARD">/, data)
    end.respond_with(successful_visa_credit_response)
    assert_success response
    assert_equal '3d4187536044bd39ad6a289c4339c41c', response.authorization
  end

  def test_description
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<description>Purchase</description>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(description: 'Something cool.'))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<description>Something cool.</description>), data
    end.respond_with(successful_authorize_response)
  end

  def test_order_content
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match %r(orderContent), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(order_content: "Lots 'o' crazy <data> stuff."))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<orderContent>\s*<!\[CDATA\[Lots 'o' crazy <data> stuff\.\]\]>\s*</orderContent>), data
    end.respond_with(successful_authorize_response)
  end

  def test_capture_time
    stub_comms do
      @gateway.capture(@amount, 'bogus', @options)
    end.check_request do |_endpoint, data, _headers|
      if /capture/.match?(data)
        t = Time.now
        assert_tag_with_attributes 'date', { 'dayOfMonth' => t.day.to_s, 'month' => t.month.to_s, 'year' => t.year.to_s }, data
      end
    end.respond_with(successful_inquiry_response, successful_capture_response)
  end

  def test_amount_handling
    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes 'amount', { 'value' => '100', 'exponent' => '2', 'currencyCode' => 'GBP' }, data
    end.respond_with(successful_authorize_response)
  end

  def test_currency_exponent_handling
    stub_comms do
      @gateway.authorize(10000, @credit_card, @options.merge(currency: :JPY))
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes 'amount', { 'value' => '100', 'exponent' => '0', 'currencyCode' => 'JPY' }, data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(10000, @credit_card, @options.merge(currency: :OMR))
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes 'amount', { 'value' => '10000', 'exponent' => '3', 'currencyCode' => 'OMR' }, data
    end.respond_with(successful_authorize_response)
  end

  def test_address_handling
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: address))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<firstName>Jim</firstName>), data
      assert_match %r(<lastName>Smith</lastName>), data
      assert_match %r(<address1>456 My Street</address1>), data
      assert_match %r(<address2>Apt 1</address2>), data
      assert_match %r(<postalCode>K1C2N6</postalCode>), data
      assert_match %r(<city>Ottawa</city>), data
      assert_match %r(<state>ON</state>), data
      assert_match %r(<countryCode>CA</countryCode>), data
      assert_match %r(<telephoneNumber>\(555\)555-5555</telephoneNumber>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: address.with_indifferent_access))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<firstName>Jim</firstName>), data
      assert_match %r(<lastName>Smith</lastName>), data
      assert_match %r(<address1>456 My Street</address1>), data
      assert_match %r(<address2>Apt 1</address2>), data
      assert_match %r(<postalCode>K1C2N6</postalCode>), data
      assert_match %r(<city>Ottawa</city>), data
      assert_match %r(<state>ON</state>), data
      assert_match %r(<countryCode>CA</countryCode>), data
      assert_match %r(<telephoneNumber>\(555\)555-5555</telephoneNumber>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(address: address))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<firstName>Jim</firstName>), data
      assert_match %r(<lastName>Smith</lastName>), data
      assert_match %r(<address1>456 My Street</address1>), data
      assert_match %r(<address2>Apt 1</address2>), data
      assert_match %r(<postalCode>K1C2N6</postalCode>), data
      assert_match %r(<city>Ottawa</city>), data
      assert_match %r(<state>ON</state>), data
      assert_match %r(<countryCode>CA</countryCode>), data
      assert_match %r(<telephoneNumber>\(555\)555-5555</telephoneNumber>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: { phone: '555-3323' }))
    end.check_request do |_endpoint, data, _headers|
      assert_no_match %r(firstName), data
      assert_no_match %r(lastName), data
      assert_no_match %r(address2), data
      assert_match %r(<address1>N/A</address1>), data
      assert_match %r(<city>N/A</city>), data
      assert_match %r(<postalCode>0000</postalCode>), data
      assert_match %r(<state/>), data
      assert_match %r(<countryCode>US</countryCode>), data
      assert_match %r(<telephoneNumber>555-3323</telephoneNumber>), data
    end.respond_with(successful_authorize_response)
  end

  def test_no_address_specified
    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match %r(cardAddress), data
      assert_no_match %r(address), data
      assert_no_match %r(firstName), data
      assert_no_match %r(lastName), data
      assert_no_match %r(address1), data
      assert_no_match %r(address2), data
      assert_no_match %r(postalCode), data
      assert_no_match %r(city), data
      assert_no_match %r(state), data
      assert_no_match %r(countryCode), data
      assert_no_match %r(telephoneNumber), data
    end.respond_with(successful_authorize_response)
  end

  def test_address_with_parts_unspecified
    address_with_nils = { address1: nil, city: ' ', state: nil, zip: '  ',
                          country: nil, phone: '555-3323' }

    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: address_with_nils))
    end.check_request do |_endpoint, data, _headers|
      assert_no_match %r(firstName), data
      assert_no_match %r(lastName), data
      assert_no_match %r(address2), data
      assert_match %r(<address1>N/A</address1>), data
      assert_match %r(<city>N/A</city>), data
      assert_match %r(<postalCode>0000</postalCode>), data
      assert_match %r(<state/>), data
      assert_match %r(<countryCode>US</countryCode>), data
      assert_match %r(<telephoneNumber>555-3323</telephoneNumber>), data
    end.respond_with(successful_authorize_response)
  end

  def test_state_sent_for_3ds_transactions_in_us_country
    us_billing_address = address.merge(country: 'US')
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: us_billing_address, execute_threed: true))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(firstName), data
      assert_match %r(lastName), data
      assert_match %r(<address1>456 My Street</address1>), data
      assert_match %r(<address2>Apt 1</address2>), data
      assert_match %r(<city>Ottawa</city>), data
      assert_match %r(<postalCode>K1C2N6</postalCode>), data
      assert_match %r(<state>ON</state>), data
      assert_match %r(<countryCode>US</countryCode>), data
      assert_match %r(<telephoneNumber>\(555\)555-5555</telephoneNumber>), data
    end.respond_with(successful_authorize_response)
  end

  def test_state_not_sent_for_3ds_transactions_in_non_us_country
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: address, execute_threed: true))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(firstName), data
      assert_match %r(lastName), data
      assert_match %r(<address1>456 My Street</address1>), data
      assert_match %r(<address2>Apt 1</address2>), data
      assert_match %r(<city>Ottawa</city>), data
      assert_match %r(<postalCode>K1C2N6</postalCode>), data
      assert_no_match %r(<state>ON</state>), data
      assert_match %r(<countryCode>CA</countryCode>), data
      assert_match %r(<telephoneNumber>\(555\)555-5555</telephoneNumber>), data
    end.respond_with(successful_authorize_response)
  end

  def test_email
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(email: 'eggcellent@example.com'))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<shopperEmailAddress>eggcellent@example.com</shopperEmailAddress>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match %r(shopperEmailAddress), data
    end.respond_with(successful_authorize_response)
  end

  def test_statement_narrative_and_truncation
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(statement_narrative: 'Merchant Statement Narrative The Story Of Your Purchase'))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<statementNarrative>Merchant Statement Narrative The Story Of Your Pur</statementNarrative>), data
      assert_no_match %r(<statementNarrative>Merchant Statement Narrative The Story Of Your Purchase</statementNarrative>), data
    end.respond_with(successful_authorize_response)
  end

  def test_instalments
    stub_comms do
      @gateway.purchase(100, @credit_card, @options.merge(instalments: 3))
    end.check_request do |_endpoint, data, _headers|
      unless /<capture>/.match?(data)
        assert_match %r(<instalments>3</instalments>), data
        assert_no_match %r(cpf), data
      end
    end.respond_with(successful_authorize_response, successful_capture_response)

    stub_comms do
      @gateway.purchase(100, @credit_card, @options.merge(instalments: 3, cpf: 12341234))
    end.check_request do |_endpoint, data, _headers|
      unless /<capture>/.match?(data)
        assert_match %r(<instalments>3</instalments>), data
        assert_match %r(<cpf>12341234</cpf>), data
      end
    end.respond_with(successful_authorize_response, successful_capture_response)
  end

  def test_ip
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(ip: '192.137.11.44'))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<session shopperIPAddress="192.137.11.44"/>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match %r(<session), data
    end.respond_with(successful_authorize_response)
  end

  def test_parsing
    response = stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(address: { address1: '123 Anystreet', country: 'US' }))
    end.respond_with(successful_authorize_response)

    assert_equal({
      'action' => 'authorize',
      'amount_currency_code' => 'HKD',
      'amount_debit_credit_indicator' => 'credit',
      'amount_exponent' => '2',
      'amount_value' => '15000',
      'avs_result_code_description' => 'UNKNOWN',
      'balance' => true,
      'balance_account_type' => 'IN_PROCESS_AUTHORISED',
      'card_number' => '4111********1111',
      'cvc_result_code_description' => 'UNKNOWN',
      'last_event' => 'AUTHORISED',
      'order_status' => true,
      'order_status_order_code' => 'R50704213207145707',
      'payment' => true,
      'payment_method' => 'VISA-SSL',
      'payment_service' => true,
      'payment_service_merchant_code' => 'XXXXXXXXXXXXXXX',
      'payment_service_version' => '1.4',
      'reply' => true,
      'risk_score_value' => '1'
    }, response.params)
  end

  def test_auth
    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, _data, headers|
      assert_equal 'Basic dGVzdGxvZ2luOnRlc3RwYXNzd29yZA==', headers['Authorization']
    end.respond_with(successful_authorize_response)
  end

  def test_request_respects_test_mode_on_gateway_instance
    ActiveMerchant::Billing::Base.mode = :production

    @gateway = WorldpayGateway.new(
      login: 'testlogin',
      password: 'testpassword',
      test: true
    )

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, _data, _headers|
      assert_equal WorldpayGateway.test_url, endpoint
    end.respond_with(successful_authorize_response, successful_capture_response)
  ensure
    ActiveMerchant::Billing::Base.mode = :test
  end

  def test_refund_amount_contains_debit_credit_indicator
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.check_request do |_endpoint, data, _headers|
      if /<refund>/.match?(data)
        request_hash = Hash.from_xml(data)
        assert_equal 'credit', request_hash['paymentService']['modify']['orderModification']['refund']['amount']['debitCreditIndicator']
      end
    end.respond_with(successful_refund_inquiry_response('CAPTURED'), successful_refund_response)
    assert_success response
  end

  def test_cancel_or_refund
    stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.check_request do |_endpoint, data, _headers|
      next if data =~ /<inquiry>/

      refute_match(/<cancelOrRefund\/>/, data)
    end.respond_with(successful_refund_inquiry_response, successful_refund_response)

    stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options.merge(cancel_or_refund: true))
    end.check_request do |_endpoint, data, _headers|
      next if data =~ /<inquiry>/

      assert_match(/<cancelOrRefund\/>/, data)
    end.respond_with(successful_refund_inquiry_response('SENT_FOR_REFUND'), successful_cancel_or_refund_response)
  end

  def test_cancel_or_refund_with_void
    stub_comms do
      @gateway.void(@options[:order_id], @options)
    end.check_request do |_endpoint, data, _headers|
      next if data =~ /<inquiry>/

      refute_match(/<cancelOrRefund\/>/, data)
    end.respond_with(successful_refund_inquiry_response, successful_refund_response)

    stub_comms do
      @gateway.void(@options[:order_id], @options.merge(cancel_or_refund: true))
    end.check_request do |_endpoint, data, _headers|
      next if data =~ /<inquiry>/

      assert_match(/<cancelOrRefund\/>/, data)
    end.respond_with(successful_refund_inquiry_response('SENT_FOR_REFUND'), successful_cancel_or_refund_response)
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_0_auth
    stub_comms do
      @gateway.verify(@credit_card, @options.merge(zero_dollar_auth: true))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/amount value="0"/, data) if /<submit>/.match?(data)
    end.respond_with(successful_authorize_response, successful_void_response)
  end

  def test_successful_verify_with_0_auth_and_ineligible_card
    stub_comms do
      @gateway.verify(@elo_credit_card, @options.merge(zero_dollar_auth: true))
    end.check_request do |_endpoint, data, _headers|
      refute_match(/amount value="0"/, data)
    end.respond_with(successful_authorize_response, successful_void_response)
  end

  def test_successful_verify_with_elo
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_with_elo_response, successful_void_with_elo_response)

    response = @gateway.verify(@elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_empty_inst_id_is_stripped
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ inst_id: '' }))
    end.check_request do |_, data, _|
      assert_not_match(/installationId/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_3ds_name_coersion_for_testing
    @options[:execute_threed] = true
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<cardHolderName>3D</cardHolderName>}, data if /<submit>/.match?(data)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_3ds_name_coersion_based_on_version_for_testing
    @options[:execute_threed] = true
    @options[:three_ds_version] = '2.0'
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<cardHolderName>Longbob Longsen</cardHolderName>}, data if /<submit>/.match?(data)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response

    @options[:three_ds_version] = '2'
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<cardHolderName>Longbob Longsen</cardHolderName>}, data if /<submit>/.match?(data)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response

    @options[:three_ds_version] = '1.0.2'
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<cardHolderName>3D</cardHolderName>}, data if /<submit>/.match?(data)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_3ds_name_not_coerced_in_production
    ActiveMerchant::Billing::Base.mode = :production

    @options[:execute_threed] = true

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match %r{<cardHolderName>3D</cardHolderName>}, data
    end.respond_with(successful_authorize_response, successful_capture_response)
  ensure
    ActiveMerchant::Billing::Base.mode = :test
  end

  def test_3ds_additional_information
    browser_size = '390x400'
    session_id = '0215ui8ib1'
    df_reference_id = '1326vj9jc2'

    options = @options.merge(
      session_id: session_id,
      df_reference_id: df_reference_id,
      browser_size: browser_size,
      execute_threed: true,
      three_ds_version: '2.0.1'
    )

    stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes 'additional3DSData', { 'dfReferenceId' => df_reference_id, 'challengeWindowSize' => browser_size }, data
    end.respond_with(successful_authorize_response)
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  def test_transcript_scrubbing_on_network_token
    assert_equal network_token_transcript_scrubbed, @gateway.scrub(network_token_transcript)
  end

  def test_transcript_scrubbing_on_aft
    assert_equal aft_transcript_scrubbed, @gateway.scrub(aft_transcript)
  end

  def test_3ds_version_1_request
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(three_d_secure_option(version: '1.0.2', xid: 'xid')))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<paymentService version="1.4" merchantCode="testlogin">}, data
      assert_match %r{<eci>eci</eci>}, data
      assert_match %r{<cavv>cavv</cavv>}, data
      assert_match %r{<xid>xid</xid>}, data
      assert_match %r{<threeDSVersion>1.0.2</threeDSVersion>}, data
    end.respond_with(successful_authorize_response)
  end

  def test_3ds_version_2_request
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(three_d_secure_option(version: '2.1.0', ds_transaction_id: 'ds_transaction_id')))
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<paymentService version="1.4" merchantCode="testlogin">}, data
      assert_match %r{<eci>eci</eci>}, data
      assert_match %r{<cavv>cavv</cavv>}, data
      assert_match %r{<dsTransactionId>ds_transaction_id</dsTransactionId>}, data
      assert_match %r{<threeDSVersion>2.1.0</threeDSVersion>}, data
    end.respond_with(successful_authorize_response)
  end

  def test_failed_authorize_with_unknown_card
    response = stub_comms do
      @gateway.authorize(@amount, @sodexo_voucher, @options)
    end.respond_with(failed_with_unknown_card_response)
    assert_failure response
    assert_equal '5', response.error_code
  end

  def test_failed_purchase_with_unknown_card
    response = stub_comms do
      @gateway.purchase(@amount, @sodexo_voucher, @options)
    end.respond_with(failed_with_unknown_card_response)
    assert_failure response
    assert_equal '5', response.error_code
  end

  def test_failed_verify_with_unknown_card
    @gateway.expects(:ssl_post).returns(failed_with_unknown_card_response)

    response = @gateway.verify(@sodexo_voucher, @options)
    assert_failure response
    assert_equal '5', response.error_code
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @store_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<paymentTokenCreate>), data
      assert_match %r(<createToken/?>), data
      assert_match %r(<authenticatedShopperID>59424549c291397379f30c5c082dbed8</authenticatedShopperID>), data
      assert_match %r(4242424242424242), data
      assert_no_match %r(<order>), data
      assert_no_match %r(<paymentDetails>), data
      assert_no_match %r(<CARD-SSL>), data
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal @token, response.authorization
  end

  def test_successful_authorize_using_token
    response = stub_comms do
      @gateway.authorize(@amount, @token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('order', { 'orderCode' => @options[:order_id].to_s }, data)
      assert_match %r(<authenticatedShopperID>59424549c291397379f30c5c082dbed8</authenticatedShopperID>), data
      assert_tag_with_attributes 'TOKEN-SSL', { 'tokenScope' => 'shopper' }, data
      assert_match %r(<paymentTokenID>99411111780163871111</paymentTokenID>), data
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_authorize_with_token_includes_shopper_using_minimal_options
    stub_comms do
      @gateway.authorize(@amount, @token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<authenticatedShopperID>59424549c291397379f30c5c082dbed8</authenticatedShopperID>), data
    end.respond_with(successful_authorize_response)
  end

  def test_successful_purchase_using_token
    response = stub_comms do
      @gateway.purchase(@amount, @token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('order', { 'orderCode' => @options[:order_id].to_s }, data) if %r(<order .*?>).match?(data)
    end.respond_with(successful_authorize_response, successful_capture_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_verify_using_token
    response = stub_comms do
      @gateway.verify(@token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('order', { 'orderCode' => @options[:order_id].to_s }, data) if %r(<order .*?>).match?(data)
    end.respond_with(successful_authorize_response, successful_void_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_credit_using_token
    response = stub_comms do
      @gateway.credit(@amount, @token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('order', { 'orderCode' => @options[:order_id].to_s }, data)
      assert_match(/<paymentDetails action="REFUND">/, data)
      assert_match %r(<authenticatedShopperID>59424549c291397379f30c5c082dbed8</authenticatedShopperID>), data
      assert_tag_with_attributes 'TOKEN-SSL', { 'tokenScope' => 'shopper' }, data
      assert_match '<paymentTokenID>99411111780163871111</paymentTokenID>', data
    end.respond_with(successful_visa_credit_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal '3d4187536044bd39ad6a289c4339c41c', response.authorization
  end

  def test_optional_idempotency_key_header
    response = stub_comms do
      @gateway.authorize(@amount, @token, @options.merge({ idempotency_key: 'test123' }))
    end.check_request do |_endpoint, _data, headers|
      headers && headers['Idempotency-Key'] == 'test123'
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card, @store_options.merge(customer: '_invalidId'))
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal '2', response.error_code
    assert_equal 'authenticatedShopperID cannot start with an underscore', response.message
  end

  def test_store_should_raise_when_customer_not_present
    assert_raises(ArgumentError) do
      @gateway.store(@credit_card)
    end
  end

  def test_failed_authorize_using_token
    response = stub_comms do
      @gateway.authorize(@amount, @token, @options)
    end.respond_with(failed_authorize_response_2)

    assert_failure response
    assert_equal '5', response.error_code
    assert_match %r{XML failed validation: Invalid payment details : Card number not recognised:}, response.message
  end

  def test_failed_verify_using_token
    response = stub_comms do
      @gateway.verify(@token, @options)
    end.respond_with(failed_authorize_response_2)

    assert_failure response
    assert_equal '5', response.error_code
    assert_match %r{XML failed validation: Invalid payment details : Card number not recognised:}, response.message
  end

  def test_authorize_order_id_not_overridden_by_order_id_of_token
    @token = 'wrong_order_id|99411111780163871111|shopper|59424549c291397379f30c5c082dbed8'
    response = stub_comms do
      @gateway.authorize(@amount, @token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('order', { 'orderCode' => @options[:order_id].to_s }, data)
      assert_match %r(<authenticatedShopperID>59424549c291397379f30c5c082dbed8</authenticatedShopperID>), data
      assert_tag_with_attributes 'TOKEN-SSL', { 'tokenScope' => 'shopper' }, data
      assert_match %r(<paymentTokenID>99411111780163871111</paymentTokenID>), data
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_purchase_order_id_not_overridden_by_order_id_of_token
    @token = 'wrong_order_id|99411111780163871111|shopper|59424549c291397379f30c5c082dbed8'
    response = stub_comms do
      @gateway.purchase(@amount, @token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('order', { 'orderCode' => @options[:order_id].to_s }, data) if %r(<order .*?>).match?(data)
    end.respond_with(successful_authorize_response, successful_capture_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_verify_order_id_not_overridden_by_order_id_of_token
    @token = 'wrong_order_id|99411111780163871111|shopper|59424549c291397379f30c5c082dbed8'
    response = stub_comms do
      @gateway.verify(@token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('order', { 'orderCode' => @options[:order_id].to_s }, data) if %r(<order .*?>).match?(data)
    end.respond_with(successful_authorize_response, successful_void_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_credit_order_id_not_overridden_by_order_if_of_token
    @token = 'wrong_order_id|99411111780163871111|shopper|59424549c291397379f30c5c082dbed8'
    response = stub_comms do
      @gateway.credit(@amount, @token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('order', { 'orderCode' => @options[:order_id].to_s }, data)
      assert_match(/<paymentDetails action="REFUND">/, data)
      assert_match %r(<authenticatedShopperID>59424549c291397379f30c5c082dbed8</authenticatedShopperID>), data
      assert_tag_with_attributes 'TOKEN-SSL', { 'tokenScope' => 'shopper' }, data
      assert_match '<paymentTokenID>99411111780163871111</paymentTokenID>', data
    end.respond_with(successful_visa_credit_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal '3d4187536044bd39ad6a289c4339c41c', response.authorization
  end

  def test_handles_plain_text_response
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with('Temporary Failure, please Retry')
    assert_failure response
    assert_match "Unparsable response received from Worldpay. Please contact Worldpay if you continue to receive this message. \(The raw response returned by the API was: \"Temporary Failure, please Retry\"\)", response.message
  end

  def test_successful_authorize_synchronous_response
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/4242424242424242/, data)
    end.respond_with(successful_authorize_synchronous_response)
    assert_success response
    assert_equal 'fbe493442977787ea2fadabfb23c2574', response.authorization
  end

  def test_successful_capture_synchronous_response
    response = stub_comms do
      response = @gateway.authorize(@amount, @credit_card, @options)
      @gateway.capture(@amount, response.authorization, @options)
    end.respond_with(successful_authorize_synchronous_response, successful_capture_synchronous_response)
    assert_success response
  end

  def test_failed_capture_synchronous_response
    response = stub_comms do
      response = @gateway.authorize(@amount, @credit_card, @options)
      @gateway.capture(@amount, response.authorization, @options)
    end.respond_with(successful_authorize_synchronous_response, failed_capture_synchronous_response)
    assert_failure response
  end

  def test_successful_refund_synchronous_response
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(successful_refund_synchronous_response)
    assert_success response
  end

  def test_failed_refund_synchronous_response
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(failed_refund_synchronous_response)
    assert_failure response
  end

  def test_network_token_type_assignation_when_apple_token
    stub_comms do
      @gateway.authorize(@amount, @apple_play_network_token, @options)
    end.check_request(skip_response: true) do |_endpoint, data, _headers|
      assert_match %r(<EMVCO_TOKEN-SSL type="APPLEPAY">), data
    end
  end

  def test_network_token_type_assignation_when_network_token
    stub_comms do
      @gateway.authorize(@amount, @nt_credit_card, @options)
    end.check_request(skip_response: true) do |_endpoint, data, _headers|
      assert_match %r(<EMVCO_TOKEN-SSL type="NETWORKTOKEN">), data
    end
  end

  def test_network_token_type_assignation_when_google_pay
    stub_comms do
      @gateway.authorize(@amount, @google_pay_network_token, @options)
    end.check_request(skip_response: true) do |_endpoint, data, _headers|
      assert_match %r(<EMVCO_TOKEN-SSL type="GOOGLEPAY">), data
      assert_match %r(<eciIndicator>05</eciIndicator>), data
    end
  end

  def test_google_pay_without_eci_value
    stub_comms do
      @gateway.authorize(@amount, @google_pay_network_token_without_eci, @options)
    end.check_request(skip_response: true) do |_endpoint, data, _headers|
      assert_match %r(<EMVCO_TOKEN-SSL type="GOOGLEPAY">), data
    end
  end

  def test_google_pay_with_use_default_eci_value
    stub_comms do
      @gateway.authorize(@amount, @google_pay_network_token_without_eci, @options.merge({ use_default_eci: true }))
    end.check_request(skip_response: true) do |_endpoint, data, _headers|
      assert_match %r(<EMVCO_TOKEN-SSL type="GOOGLEPAY">), data
      assert_match %r(<eciIndicator>07</eciIndicator>), data
    end
  end

  def test_network_token_type_assignation_when_google_pay_pan_only
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge!(wallet_type: :google_pay))
    end.check_request(skip_response: true) do |_endpoint, data, _headers|
      assert_match %r(<EMVCO_TOKEN-SSL type="GOOGLEPAY">), data
    end
  end

  def test_order_id_crop_and_clean
    @options[:order_id] = "abc1234 abc1234 'abc1234' <abc1234> \"abc1234\" | abc1234 abc1234 abc1234 abc1234 abc1234"
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<order orderCode="abc1234abc1234abc1234abc1234abc1234abc1234abc1234abc1234abc1234ab">), data
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_prefers_options_for_ntid
    stored_credential_params = stored_credential(:used, :recurring, :merchant, network_transaction_id: '3812908490218390214124')
    options = @options.merge(
      stored_credential_transaction_id: '000000000000020005060720116005060'
    )

    options.merge!({ stored_credential: stored_credential_params })
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<storedCredentials usage\=\"USED\" merchantInitiatedReason\=\"RECURRING\"\>/, data)
      assert_match(/<schemeTransactionIdentifier\>000000000000020005060720116005060\<\/schemeTransactionIdentifier\>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_inquire_with_order_id
    response = stub_comms do
      @gateway.inquire(nil, { order_id: @options[:order_id].to_s })
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('orderInquiry', { 'orderCode' => @options[:order_id].to_s }, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  def test_successful_inquire_with_authorization
    response = stub_comms do
      @gateway.inquire(@options[:order_id].to_s, {})
    end.check_request do |_endpoint, data, _headers|
      assert_tag_with_attributes('orderInquiry', { 'orderCode' => @options[:order_id].to_s }, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  private

  def assert_date_element(expected_date_hash, date_element)
    assert_equal(expected_date_hash[:day_of_month], date_element.attribute('dayOfMonth').value)
    assert_equal(expected_date_hash[:month], date_element.attribute('month').value)
    assert_equal(expected_date_hash[:year], date_element.attribute('year').value)
  end

  def assert_tag_with_attributes(tag, attributes, string)
    assert(m = %r(<#{tag}([^>]+)/?>).match(string))
    attributes.each do |attribute, value|
      assert_match %r(#{attribute}="#{value}"), m[1]
    end
  end

  def three_d_secure_option(version:, xid: nil, ds_transaction_id: nil)
    {
      three_d_secure: {
        eci: 'eci',
        cavv: 'cavv',
        xid: xid,
        ds_transaction_id: ds_transaction_id,
        version: version
      }
    }
  end

  def risk_data
    return @risk_data if defined?(@risk_data)

    authentication_time = Time.now
    shopper_account_creation_date = Date.today
    shopper_account_modification_date = Date.today - 1.day
    shopper_account_password_change_date = Date.today - 2.days
    shopper_account_shipping_address_first_use_date = Date.today - 3.day
    shopper_account_payment_account_first_use_date = Date.today - 4.day
    transaction_risk_data_pre_order_date = Date.today + 1.day

    @risk_data = {
      authentication_risk_data: {
        authentication_method: 'localAccount',
        authentication_date: {
          day_of_month: authentication_time.strftime('%d'),
          month: authentication_time.strftime('%m'),
          year: authentication_time.strftime('%Y'),
          hour: authentication_time.strftime('%H'),
          minute: authentication_time.strftime('%M'),
          second: authentication_time.strftime('%S')
        }
      },
      shopper_account_risk_data: {
        transactions_attempted_last_day: '1',
        transactions_attempted_last_year: '2',
        purchases_completed_last_six_months: '3',
        add_card_attempts_last_day: '4',
        previous_suspicious_activity: 'false', # Boolean (true or false)
        shipping_name_matches_account_name: 'true', #	Boolean (true or false)
        shopper_account_age_indicator: 'lessThanThirtyDays', # Possible Values: noAccount, createdDuringTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_change_indicator: 'thirtyToSixtyDays', # Possible values: changedDuringTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_password_change_indicator: 'noChange', # Possible Values: noChange, changedDuringTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_shipping_address_usage_indicator: 'moreThanSixtyDays', # Possible Values: thisTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_payment_account_indicator: 'thirtyToSixtyDays', # Possible Values: noAccount, duringTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_creation_date: {
          day_of_month: shopper_account_creation_date.strftime('%d'),
          month: shopper_account_creation_date.strftime('%m'),
          year: shopper_account_creation_date.strftime('%Y')
        },
        shopper_account_modification_date: {
          day_of_month: shopper_account_modification_date.strftime('%d'),
          month: shopper_account_modification_date.strftime('%m'),
          year: shopper_account_modification_date.strftime('%Y')
        },
        shopper_account_password_change_date: {
          day_of_month: shopper_account_password_change_date.strftime('%d'),
          month: shopper_account_password_change_date.strftime('%m'),
          year: shopper_account_password_change_date.strftime('%Y')
        },
        shopper_account_shipping_address_first_use_date: {
          day_of_month: shopper_account_shipping_address_first_use_date.strftime('%d'),
          month: shopper_account_shipping_address_first_use_date.strftime('%m'),
          year: shopper_account_shipping_address_first_use_date.strftime('%Y')
        },
        shopper_account_payment_account_first_use_date: {
          day_of_month: shopper_account_payment_account_first_use_date.strftime('%d'),
          month: shopper_account_payment_account_first_use_date.strftime('%m'),
          year: shopper_account_payment_account_first_use_date.strftime('%Y')
        }
      },
      transaction_risk_data: {
        shipping_method: 'digital',
        delivery_timeframe: 'electronicDelivery',
        delivery_email_address: 'abe@lincoln.gov',
        reordering_previous_purchases: 'false',
        pre_order_purchase: 'false',
        gift_card_count: '0',
        transaction_risk_data_gift_card_amount: {
          value: '123',
          currency: 'EUR',
          exponent: '2',
          debit_credit_indicator: 'credit'
        },
        transaction_risk_data_pre_order_date: {
          day_of_month: transaction_risk_data_pre_order_date.strftime('%d'),
          month: transaction_risk_data_pre_order_date.strftime('%m'),
          year: transaction_risk_data_pre_order_date.strftime('%Y')
        }
      }
    }
  end

  def successful_authorize_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="XXXXXXXXXXXXXXX">
        <reply>
          <orderStatus orderCode="R50704213207145707">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="15000" currencyCode="HKD" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="UNKNOWN"/>
              <AVSResultCode description="UNKNOWN"/>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="15000" currencyCode="HKD" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_authorize_synchronous_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLYCFT">
        <reply>
          <orderStatus orderCode="fbe493442977787ea2fadabfb23c2574">
            <payment>
              <paymentMethod>VISA_CREDIT-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="NOT SENT TO ACQUIRER"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_authorize_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="XXXXXXXXXXXXXXX">
        <reply>
          <orderStatus orderCode="R12538568107150952">
            <error code="7">
              <![CDATA[Invalid payment details : Card number : 4111********1111]]>
            </error>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  # main variation is that CDATA is nested inside <error> w/o newlines; also a
  # more recent captured response from remote tests where the reply is
  # contained the error directly (no <orderStatus>)
  def failed_authorize_response_2
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <error code="5"><![CDATA[XML failed validation: Invalid payment details : Card number not recognised: 606070******4400]]></error>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_purchase_response_with_issuer_response_code
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="XXXXXXXXXXXXXXX">
        <reply>
          <orderStatus orderCode="R50704213207145707">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="15000" currencyCode="USD" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>REFUSED</lastEvent>
              <IssuerResponseCode code="51" description="Insufficient funds/over credit limit"/>
              <CVCResultCode description="C"/>
              <AVSResultCode description="H"/>
              <AAVAddressResultCode description="B"/>
              <AAVPostcodeResultCode description="B"/>
              <AAVCardholderNameResultCode description="B"/>
              <AAVTelephoneResultCode description="B"/>
              <AAVEmailResultCode description="B"/>
              <cardHolderName><![CDATA[Test McTest]]></cardHolderName>
              <issuerCountryCode>US</issuerCountryCode>
              <issuerName>TEST BANK</issuerName>
              <riskScore value="0"/>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_capture_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <ok>
            <captureReceived orderCode="33955f6bb4524813b51836de76228983">
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
            </captureReceived>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_capture_synchronous_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLYCFT">
        <reply>
          <orderStatus orderCode="fbe493442977787ea2fadabfb23c2574">
            <payment>
              <paymentMethod>VISA_CREDIT-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>CAPTURED</lastEvent>
              <CVCResultCode description="NOT SENT TO ACQUIRER"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <balance accountType="IN_PROCESS_CAPTURED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <riskScore value="1"/>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_capture_synchronous_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLYCFT">
        <reply>
          <orderStatus orderCode="bb2e156f3eb9e210fe11777c1102ea4b">
            <error code="5"><![CDATA[Requested capture amount (GBP 1.01) exceeds the authorised balance for this payment (GBP 1.00)]]></error>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_authorize_with_elo_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <orderStatus orderCode="9fe31a79de5f6aa3ce1ed7bea7edbf42">
            <payment>
              <paymentMethod>ELO-SSL</paymentMethod>
              <amount value="100" currencyCode="BRL" exponent="2" debitCreditIndicator="credit" />
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="C" />
              <AVSResultCode description="H" />
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="BRL" exponent="2" debitCreditIndicator="credit" />
              </balance>
              <cardNumber>4514********0008</cardNumber>
              <riskScore value="21" />
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_capture_with_elo_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <ok>
            <captureReceived orderCode="9fe31a79de5f6aa3ce1ed7bea7edbf42">
              <amount value="100" currencyCode="BRL" exponent="2" debitCreditIndicator="credit" />
            </captureReceived>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_void_inquiry_with_elo_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <orderStatus orderCode="eda0b101428892fdb32e2fc617a7f5e0">
            <payment>
              <paymentMethod>ELO-SSL</paymentMethod>
              <amount value="100" currencyCode="BRL" exponent="2" debitCreditIndicator="credit" />
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="C" />
              <AVSResultCode description="H" />
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="BRL" exponent="2" debitCreditIndicator="credit" />
              </balance>
              <cardNumber>4514********0008</cardNumber>
              <riskScore value="21" />
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_void_with_elo_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <ok>
            <cancelReceived orderCode="3a10f83fb9bb765488d0b3eb153879d7" />
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_inquiry_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <orderStatus orderCode="d192c159d5730d339c03fa1a8dc796eb">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="UNKNOWN"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="20" month="04" year="2011" hour="22" minute="24" second="0"/>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_void_inquiry_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <orderStatus orderCode="1266bc1b6ab96c026741300418453d43">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="NOT SENT TO ACQUIRER"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <cardHolderName><![CDATA[Longbob Longsen]]></cardHolderName>
              <issuerCountryCode>N/A</issuerCountryCode>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="05" month="03" year="2013" hour="22" minute="52" second="0"/>
          </orderStatus></reply></paymentService>
    RESPONSE
  end

  def successful_void_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <ok>
            <cancelReceived orderCode="924e810350efc21a989e0ac7727ce43b"/>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_void_inquiry_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <orderStatus orderCode="33d6dfa9726198d44a743488cf611d3b">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>SENT_FOR_REFUND</lastEvent>
              <CVCResultCode description="NOT SENT TO ACQUIRER"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <cardHolderName><![CDATA[Longbob Longsen]]></cardHolderName>
              <issuerCountryCode>N/A</issuerCountryCode>
              <balance accountType="IN_PROCESS_CAPTURED">
                <amount value="30" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="05" month="03" year="2013" hour="23" minute="6" second="0"/>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_purchase_response_without_useful_error_from_gateway
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <paymentService version="1.4" merchantCode="ACMECORP">
        <reply>
          <orderStatus orderCode="2119303">
            <payment>
              <paymentMethod>ECMC_DEBIT-SSL</paymentMethod>
              <amount value="2000" currencyCode="USD" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>REFUSED</lastEvent>
              <IssuerResponseCode code="61" description="Exceeds withdrawal amount limit"/>
              <CVCResultCode description="A"/>
              <AVSResultCode description="H"/>
              <AAVAddressResultCode description="B"/>
              <AAVPostcodeResultCode description="B"/>
              <AAVCardholderNameResultCode description="B"/>
              <AAVTelephoneResultCode description="B"/>
              <AAVEmailResultCode description="B"/>
              <cardHolderName>Snuffy Smith</cardHolderName>
              <issuerCountryCode>US</issuerCountryCode>
              <issuerName>PRETEND BANK</issuerName>
              <riskScore value="95"/>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_refund_inquiry_response(last_event = 'CAPTURED')
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <orderStatus orderCode="d192c159d5730d339c03fa1a8dc796eb">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>#{last_event}</lastEvent>
              <CVCResultCode description="UNKNOWN"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="20" month="04" year="2011" hour="22" minute="24" second="0"/>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_refund_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <ok>
            <refundReceived orderCode="05d9f8c622553b1df1fe3a145ce91ccf">
              <amount value="35" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
            </refundReceived>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_cancel_or_refund_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <ok>
            <voidReceived orderCode="afd85a0de932d5b7111b3eda78945544"></voidReceived>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_refund_synchronous_response
    <<~RESPONSE
      <paymentService version="1.4" merchantCode="MERCHANT-CODE">
        <reply>
          <orderStatus orderCode="testcentralcell0008">
            <payment>
              <paymentMethod>ECMC_CREDIT-SSL</paymentMethod>
              <amount value="1000" currencyCode="ARS" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>SENT_FOR_REFUND</lastEvent>
              <AuthorisationId id="999999"/>
              <CVCResultCode description="C"/>
              <cardHolderName>
                <![CDATA[CARDHOLDER_NAME]]>
              </cardHolderName>
              <issuerCountryCode>AR</issuerCountryCode>
              <issuerName>ISSUER-NAME</issuerName>
              <localAcquirer>WA</localAcquirer>
              <schemeResponse>
                <transactionIdentifier>999999999</transactionIdentifier>
              </schemeResponse>
            </payment>
            <orderModification orderCode="testcentralcell0008">
              <refund>
                <amount value="1000" currencyCode="ARS" exponent="2" debitCreditIndicator="credit"/>
              </refund>
            </orderModification>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_refund_synchronous_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLYCFT">
        <reply>
          <orderStatus orderCode="49a9d4e8a52bccbd3a3a6ac228ae0998">
            <error code="5"><![CDATA[Refund amount too high]]></error>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_refund_inquiry_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <orderStatus orderCode="417ceff8079ea6a0d8e803f6c0bb2b76">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="NOT SENT TO ACQUIRER"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <cardHolderName><![CDATA[Longbob Longsen]]></cardHolderName>
              <issuerCountryCode>N/A</issuerCountryCode>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="05" month="03" year="2013" hour="23" minute="19" second="0"/>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_void_response
    <<~REQUEST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <orderStatus orderCode="non_existent_authorization">
            <error code="5">
              <![CDATA[Could not find payment for order]]>
            </error>
          </orderStatus>
        </reply>
      </paymentService>
    REQUEST
  end

  def successful_visa_credit_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLYCFT">
        <reply>
          <ok>
            <refundReceived orderCode="3d4187536044bd39ad6a289c4339c41c">
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
            </refundReceived>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_mastercard_credit_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="YOUR_MERCHANT_CODE">
        <reply>
          <orderStatus orderCode="f25257d251b81fb1fd9c210973c941ff\">
            <payment>
              <paymentMethod>ECMC_DEBIT-SSL</paymentMethod>
              <amount value="1110" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>SENT_FOR_REFUND</lastEvent>
              <AuthorisationId id="987654"/>
              <balance accountType="IN_PROCESS_CAPTURED">
                <amount value="1110" currencyCode="GBP" exponent="2" debitCreditIndicator="debit"/>
              </balance>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def sample_authorization_request
    <<~REQUEST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//RBS WorldPay//DTD RBS WorldPay PaymentService v1//EN" "http://dtd.wp3.rbsworldpay.com/paymentService_v1.dtd">
      <paymentService merchantCode="XXXXXXXXXXXXXXX" version="1.4">
      <submit>
        <order installationId="0000000000" orderCode="R85213364408111039">
          <description>Products Products Products</description>
          <amount value="100" exponent="2" currencyCode="HKD"/>
          <orderContent>Products Products Products</orderContent>
          <paymentDetails>
            <CARD-SSL>
              <cardNumber>4242424242424242</cardNumber>
              <expiryDate>
                <date month="09" year="2011"/>
              </expiryDate>
              <cardHolderName>Jim Smith</cardHolderName>
              <cvc>123</cvc>
              <cardAddress>
                <address>
                  <firstName>Jim</firstName>
                  <lastName>Smith</lastName>
                  <street>456 My Street</street>
                  <houseName>Apt 1</houseName>
                  <postalCode>K1C2N6</postalCode>
                  <city>Ottawa</city>
                  <state>ON</state>
                  <countryCode>CA</countryCode>
                  <telephoneNumber>(555)555-5555</telephoneNumber>
                </address>
              </cardAddress>
            </CARD-SSL>
            <session id="asfasfasfasdgvsdzvxzcvsd" shopperIPAddress="127.0.0.1"/>
          </paymentDetails>
          <shopper>
            <browser>
              <acceptHeader>application/json, text/javascript, */*</acceptHeader>
              <userAgentHeader>Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.19</userAgentHeader>
            </browser>
          </shopper>
        </order>
      </submit>
      </paymentService>
    REQUEST
  end

  def transcript
    <<~TRANSCRIPT
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <submit>
          <order orderCode="4efd348dbe6708b9ec9c118322e0954f">
            <description>Purchase</description>
            <amount value="100" currencyCode="GBP" exponent="2"/>
            <paymentDetails>
              <CARD-SSL>
                <cardNumber>4111111111111111</cardNumber>
                <expiryDate>
                  <date month="09" year="2016"/>
                </expiryDate>
                <cardHolderName>Longbob Longsen</cardHolderName>
                <cvc>123</cvc>
                <cardAddress>
                  <address>
                    <address1>N/A</address1>
                    <postalCode>0000</postalCode>
                    <city>N/A</city>
                    <state>N/A</state>
                    <countryCode>US</countryCode>
                  </address>
                </cardAddress>
              </CARD-SSL>
            </paymentDetails>
            <shopper>
              <shopperEmailAddress>wow@example.com</shopperEmailAddress>
            </shopper>
          </order>
        </submit>
      </paymentService>
    TRANSCRIPT
  end

  def scrubbed_transcript
    <<~TRANSCRIPT
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <submit>
          <order orderCode="4efd348dbe6708b9ec9c118322e0954f">
            <description>Purchase</description>
            <amount value="100" currencyCode="GBP" exponent="2"/>
            <paymentDetails>
              <CARD-SSL>
                <cardNumber>[FILTERED]</cardNumber>
                <expiryDate>
                  <date month="09" year="2016"/>
                </expiryDate>
                <cardHolderName>Longbob Longsen</cardHolderName>
                <cvc>[FILTERED]</cvc>
                <cardAddress>
                  <address>
                    <address1>N/A</address1>
                    <postalCode>0000</postalCode>
                    <city>N/A</city>
                    <state>N/A</state>
                    <countryCode>US</countryCode>
                  </address>
                </cardAddress>
              </CARD-SSL>
            </paymentDetails>
            <shopper>
              <shopperEmailAddress>wow@example.com</shopperEmailAddress>
            </shopper>
          </order>
        </submit>
      </paymentService>
    TRANSCRIPT
  end

  def aft_transcript
    <<~TRANSCRIPT
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <submit>
          <order orderCode="24602b5855e3edf2f7821f6e86694b7f">
            <description>Account Funding Transaction</description>
            <amount value="100" currencyCode="GBP" exponent="2"/>
            <paymentDetails>
              <CARD-SSL>
                <cardNumber>4111111111111111</cardNumber>
                <expiryDate>
                  <date month="09" year="2025"/>
                </expiryDate>
                <cardHolderName>Longbob Longsen</cardHolderName>
                <cvc>123</cvc>
              </CARD-SSL>
            </paymentDetails>
            <shopper>
              <shopperEmailAddress>wow@example.com</shopperEmailAddress>
              <browser>
                <acceptHeader/>
                <userAgentHeader/>
              </browser>
            </shopper>
            <fundingTransfer type="A" category="PULL_FROM_CARD">
              <paymentPurpose>01</paymentPurpose>
              <fundingParty type="sender">
                <accountReference accountType="02">4111111111111112</accountReference>
                <fullName>
                  <first>First</first>
                  <middle>Middle</middle>
                  <last>Sender</last>
                </fullName>
                <fundingAddress>
                  <address1>123 Sender St</address1>
                  <address2>Apt 1</address2>
                  <postalCode>12345</postalCode>
                  <city>Senderville</city>
                  <state>NC</state>
                  <countryCode>US</countryCode>
                </fundingAddress>
              </fundingParty>
              <fundingParty type="recipient">
                <accountReference accountType="03">4111111111111111</accountReference>
                <fullName>
                  <first>First</first>
                  <middle>Middle</middle>
                  <last>Recipient</last>
                </fullName>
                <fundingAddress>
                  <address1>123 Recipient St</address1>
                  <address2>Apt 1</address2>
                  <postalCode>12345</postalCode>
                  <city>Recipientville</city>
                  <state>NC</state>
                  <countryCode>US</countryCode>
                </fundingAddress>
                <fundingData>
                  <birthDate>
                    <date dayOfMonth="01" month="01" year="1980"/>
                  </birthDate>
                  <telephoneNumber>123456789</telephoneNumber>
                </fundingData>
              </fundingParty>
            </fundingTransfer>
          </order>
        </submit>
      </paymentService>
    TRANSCRIPT
  end

  def aft_transcript_scrubbed
    <<~TRANSCRIPT
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <submit>
          <order orderCode="24602b5855e3edf2f7821f6e86694b7f">
            <description>Account Funding Transaction</description>
            <amount value="100" currencyCode="GBP" exponent="2"/>
            <paymentDetails>
              <CARD-SSL>
                <cardNumber>[FILTERED]</cardNumber>
                <expiryDate>
                  <date month="09" year="2025"/>
                </expiryDate>
                <cardHolderName>Longbob Longsen</cardHolderName>
                <cvc>[FILTERED]</cvc>
              </CARD-SSL>
            </paymentDetails>
            <shopper>
              <shopperEmailAddress>wow@example.com</shopperEmailAddress>
              <browser>
                <acceptHeader/>
                <userAgentHeader/>
              </browser>
            </shopper>
            <fundingTransfer type="A" category="PULL_FROM_CARD">
              <paymentPurpose>01</paymentPurpose>
              <fundingParty type="sender">
                <accountReference accountType="02">[FILTERED]</accountReference>
                <fullName>
                  <first>First</first>
                  <middle>Middle</middle>
                  <last>Sender</last>
                </fullName>
                <fundingAddress>
                  <address1>123 Sender St</address1>
                  <address2>Apt 1</address2>
                  <postalCode>12345</postalCode>
                  <city>Senderville</city>
                  <state>NC</state>
                  <countryCode>US</countryCode>
                </fundingAddress>
              </fundingParty>
              <fundingParty type="recipient">
                <accountReference accountType="03">[FILTERED]</accountReference>
                <fullName>
                  <first>First</first>
                  <middle>Middle</middle>
                  <last>Recipient</last>
                </fullName>
                <fundingAddress>
                  <address1>123 Recipient St</address1>
                  <address2>Apt 1</address2>
                  <postalCode>12345</postalCode>
                  <city>Recipientville</city>
                  <state>NC</state>
                  <countryCode>US</countryCode>
                </fundingAddress>
                <fundingData>
                  <birthDate>
                    <date dayOfMonth="01" month="01" year="1980"/>
                  </birthDate>
                  <telephoneNumber>123456789</telephoneNumber>
                </fundingData>
              </fundingParty>
            </fundingTransfer>
          </order>
        </submit>
      </paymentService>
    TRANSCRIPT
  end

  def network_token_transcript
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
          <submit>
              <order orderCode="c293b34a70aee391193a1c08168b6c91">
                  <description>Purchase</description>
                  <amount value="100" currencyCode="GBP" exponent="2" />
                  <paymentDetails>
                      <EMVCO_TOKEN-SSL type="APPLEPAY">
                          <tokenNumber>4895370015293175</tokenNumber>
                          <expiryDate>
                              <date month="10" year="2024" />
                          </expiryDate>
                          <cardHolderName>PedroPerez</cardHolderName>
                          <cryptogram>axxxxxxxxx</cryptogram>
                          <eciIndicator>07</eciIndicator>
                      </EMVCO_TOKEN-SSL>
                  </paymentDetails>
                  <shopper>
                      <shopperEmailAddress>wow@ example.com</shopperEmailAddress>
                      <browser>
                          <acceptHeader />
                          <userAgentHeader />
                      </browser>
                  </shopper>
              </order>
          </submit>
      </paymentService>
    RESPONSE
  end

  def network_token_transcript_scrubbed
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
          <submit>
              <order orderCode="c293b34a70aee391193a1c08168b6c91">
                  <description>Purchase</description>
                  <amount value="100" currencyCode="GBP" exponent="2" />
                  <paymentDetails>
                      <EMVCO_TOKEN-SSL type="APPLEPAY">
                          <tokenNumber>[FILTERED]</tokenNumber>
                          <expiryDate>
                              <date month="10" year="2024" />
                          </expiryDate>
                          <cardHolderName>PedroPerez</cardHolderName>
                          <cryptogram>[FILTERED]</cryptogram>
                          <eciIndicator>07</eciIndicator>
                      </EMVCO_TOKEN-SSL>
                  </paymentDetails>
                  <shopper>
                      <shopperEmailAddress>wow@ example.com</shopperEmailAddress>
                      <browser>
                          <acceptHeader />
                          <userAgentHeader />
                      </browser>
                  </shopper>
              </order>
          </submit>
      </paymentService>
    RESPONSE
  end

  def failed_with_unknown_card_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <error code="5">
            <![CDATA[XML failed validation: Invalid payment details : Card number not recognised: 606070******4400]]>
          </error>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_store_response
    <<~RESPONSE
      <?xml version="1.0"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <token>
            <authenticatedShopperID>59424549c291397379f30c5c082dbed8</authenticatedShopperID>
            <tokenDetails tokenEvent="NEW">
              <paymentTokenID>99411111780163871111</paymentTokenID>
              <paymentTokenExpiry>
                <date dayOfMonth="30" month="05" year="2019" hour="22" minute="54" second="47"/>
              </paymentTokenExpiry>
              <tokenReason>Created token without payment on 2019-05-23</tokenReason>
            </tokenDetails>
            <paymentInstrument>
              <cardDetails>
                <expiryDate>
                  <date month="09" year="2020"/>
                </expiryDate>
                <cardHolderName><![CDATA[Longbob Longsen]]></cardHolderName>
                <derived>
                  <cardBrand>VISA</cardBrand>
                  <cardSubBrand>VISA_CREDIT</cardSubBrand>
                  <issuerCountryCode>N/A</issuerCountryCode>
                  <issuerName>TARGOBANK AG & CO. KGAA</issuerName>
                  <obfuscatedPAN>4111********1111</obfuscatedPAN>
                </derived>
              </cardDetails>
            </paymentInstrument>
          </token>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_store_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <error code="2"><![CDATA[authenticatedShopperID cannot start with an underscore]]></error>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_aft_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <orderStatus orderCode="d493bbdf45239ef244316bba986f5196">
            <payment>
              <paymentMethod>VISA_CREDIT-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="C"/>
              <AVSResultCode description="H"/>
              <cardHolderName><![CDATA[Longbob Longsen]]></cardHolderName>
              <issuerCountryCode>N/A</issuerCountryCode>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
              <schemeResponse>
                <transactionIdentifier>060720116005062</transactionIdentifier>
              </schemeResponse>
              <fundingLinkId></fundingLinkId>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end
end
