require 'test_helper'

class RemoteLitleTest < Test::Unit::TestCase
  def setup
    @gateway = LitleGateway.new(fixtures(:litle))
    @credit_card_hash = {
      first_name: 'John',
      last_name: 'Smith',
      month: '01',
      year: '2024',
      brand: 'visa',
      number: '4457010000000009',
      verification_value: '349'
    }

    @options = {
      order_id: '1',
      email: 'wow@example.com',
      billing_address: {
        company: 'testCompany',
        address1: '1 Main St.',
        city: 'Burlington',
        state: 'MA',
        country: 'USA',
        zip: '01803-3747',
        phone: '1234567890'
      }
    }
    @credit_card1 = CreditCard.new(@credit_card_hash)

    @credit_card2 = CreditCard.new(
      first_name: 'Joe',
      last_name: 'Green',
      month: '06',
      year: '2012',
      brand: 'visa',
      number: '4457010100000008',
      verification_value: '992'
    )
    @credit_card_nsf = CreditCard.new(
      first_name: 'Joe',
      last_name: 'Green',
      month: '06',
      year: '2012',
      brand: 'visa',
      number: '4488282659650110',
      verification_value: '992'
    )
    @decrypted_apple_pay = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      {
        month: '01',
        year: '2012',
        brand: 'visa',
        number:  '44444444400009',
        payment_cryptogram: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
      }
    )
    @decrypted_android_pay = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      {
        source: :android_pay,
        month: '01',
        year: '2021',
        brand: 'visa',
        number:  '4457000300000007',
        payment_cryptogram: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
      }
    )

    @decrypted_google_pay = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      {
        source: :google_pay,
        month: '01',
        year: '2021',
        brand: 'visa',
        number:  '4457000300000007',
        payment_cryptogram: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
      }
    )
    @check = check(
      name: 'Tom Black',
      routing_number:  '011075150',
      account_number: '4099999992',
      account_type: 'checking'
    )
    @authorize_check = check(
      name: 'John Smith',
      routing_number: '011075150',
      account_number: '1099999999',
      account_type: 'checking'
    )
    @store_check = check(
      routing_number: '011100012',
      account_number: '1099999998'
    )

    @declined_card = credit_card('4488282659650110', first_name: nil, last_name: 'REFUSED')
  end

  def test_successful_authorization
    assert response = @gateway.authorize(10010, @credit_card1, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_authorization_with_merchant_data
    options = @options.merge(
      affiliate: 'some-affiliate',
      campaign: 'super-awesome-campaign',
      merchant_grouping_id: 'brilliant-group'
    )
    assert @gateway.authorize(10010, @credit_card1, options)
  end

  def test_successful_capture_with_customer_id
    options = @options.merge(customer_id: '8675309')
    assert response = @gateway.authorize(1000, @credit_card1, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_succesful_purchase_with_customer_id
    options = @options.merge(customer_id: '8675309')
    assert response = @gateway.purchase(1000, @credit_card1, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_refund_with_customer_id
    options = @options.merge(customer_id: '8675309')

    assert purchase = @gateway.purchase(100, @credit_card1, options)

    assert refund = @gateway.refund(444, purchase.authorization, options)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_successful_authorization_with_echeck
    options = @options.merge({
      order_id: '38',
      order_source: 'telephone'
    })
    assert response = @gateway.authorize(3002, @authorize_check, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_avs_result
    @credit_card1.number = '4200410886320101'
    assert response = @gateway.authorize(10010, @credit_card1, @options)

    assert_equal 'Z', response.avs_result['code']
  end

  def test__cvv_result
    @credit_card1.number = '4100521234567000'
    assert response = @gateway.authorize(10010, @credit_card1, @options)

    assert_equal 'P', response.cvv_result['code']
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(
      60060,
      @declined_card,
      {
        order_id: '6',
        billing_address: {
          name: 'Joe Green',
          address1: '6 Main St.',
          city: 'Derry',
          state: 'NH',
          zip: '03038',
          country: 'US'
        }
      }
    )
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(10010, @credit_card1, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_some_empty_address_parts
    assert response = @gateway.purchase(10010, @credit_card1, {
      order_id: '1',
      email: 'wow@example.com',
      billing_address: {
      }
    })
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_truncated_billing_address
    assert response = @gateway.purchase(10010, @credit_card1, {
      order_id: '1',
      email: 'test@example.com',
      billing_address: {
        address1: '1234 Supercalifragilisticexpialidocious',
        address2: 'Unit 6',
        city: '‎Lake Chargoggagoggmanchauggagoggchaubunagungamaugg',
        state: 'ME',
        zip: '09901',
        country: 'US'
      }
    })
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_debt_repayment_flag
    assert response = @gateway.purchase(10010, @credit_card1, @options.merge(debt_repayment: true))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_fraud_filter_override_flag
    assert response = @gateway.purchase(10010, @credit_card1, @options.merge(fraud_filter_override: true))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase_when_fraud_filter_override_flag_not_sent_as_boolean
    assert response = @gateway.purchase(10010, @credit_card1, @options.merge(fraud_filter_override: 'hey'))
    assert_failure response
  end

  def test_successful_purchase_with_3ds_fields
    options = @options.merge({
      order_source: '3dsAuthenticated',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      cavv: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
    })
    assert response = @gateway.purchase(10010, @credit_card1, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_apple_pay
    assert response = @gateway.purchase(10010, @decrypted_apple_pay)
    assert_success response
    assert_equal 'Partially Approved: The authorized amount is less than the requested amount.', response.message
  end

  def test_successful_purchase_with_android_pay
    assert response = @gateway.purchase(10000, @decrypted_android_pay)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_google_pay
    assert response = @gateway.purchase(10000, @decrypted_google_pay)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_level_two_data_visa
    options = @options.merge(
      level_2_data: {
        sales_tax: 200
      }
    )
    assert response = @gateway.purchase(10010, @credit_card1, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_level_two_data_master
    credit_card = CreditCard.new(
      first_name: 'John',
      last_name: 'Smith',
      month: '01',
      year: '2024',
      brand: 'master',
      number: '5555555555554444',
      verification_value: '349'
    )

    options = @options.merge(
      level_2_data: {
        total_tax_amount: 200,
        customer_code: 'PO12345',
        card_acceptor_tax_id: '011234567',
        tax_included_in_total: 'true',
        tax_amount: 50
      }
    )
    assert response = @gateway.purchase(10010, credit_card, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_level_three_data_visa
    options = @options.merge(
      level_3_data: {
        discount_amount: 50,
        shipping_amount: 50,
        duty_amount: 20,
        tax_included_in_total: true,
        tax_amount: 100,
        tax_rate: 0.05,
        tax_type_identifier: '01',
        card_acceptor_tax_id: '361531321',
        line_items: [{
          item_sequence_number: 1,
          item_commodity_code: 300,
          item_description: 'ramdom-object',
          product_code: 'TB123',
          quantity: 2,
          unit_of_measure: 'EACH',
          unit_cost: 25,
          discount_per_line_item: 5,
          line_item_total: 300,
          tax_included_in_total: true,
          tax_amount: 100,
          tax_rate: 0.05,
          tax_type_identifier: '01',
          card_acceptor_tax_id: '361531321'
        }]
      }
    )
    assert response = @gateway.purchase(10010, @credit_card1, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_level_three_data_master
    credit_card = CreditCard.new(
      first_name: 'John',
      last_name: 'Smith',
      month: '01',
      year: '2024',
      brand: 'master',
      number: '5555555555554444',
      verification_value: '349'
    )

    options = @options.merge(
      level_3_data: {
        total_tax_amount: 200,
        customer_code: 'PO12345',
        card_acceptor_tax_id: '011234567',
        tax_amount: 50,
        line_items: [{
          item_description: 'ramdom-object',
          product_code: 'TB123',
          quantity: 2,
          unit_of_measure: 'EACH',
          line_item_total: 300
        }]
      }
    )

    assert response = @gateway.purchase(10010, credit_card, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_merchant_data
    options = @options.merge(
      affiliate: 'some-affiliate',
      campaign: 'super-awesome-campaign',
      merchant_grouping_id: 'brilliant-group'
    )
    assert response = @gateway.purchase(10010, @credit_card1, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_echeck
    options = @options.merge({
      order_id: '42',
      order_source: 'telephone'
    })
    assert response = @gateway.purchase(2004, @check, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(60060, @declined_card, {
      order_id: '6',
      billing_address: {
        name: 'Joe Green',
        address1: '6 Main St.',
        city: 'Derry',
        state: 'NH',
        zip: '03038',
        country: 'US'
      }
    })
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  def test_authorize_capture_refund_void
    assert auth = @gateway.authorize(10010, @credit_card1, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message

    assert refund = @gateway.refund(nil, capture.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message

    sleep 40.seconds

    assert void = @gateway.void(refund.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_authorize_and_capture_with_stored_credential_recurring
    credit_card = CreditCard.new(@credit_card_hash.merge(
                                   number: '4100200300011001',
                                   month: '05',
                                   year: '2021',
                                   verification_value: '463'
                                 ))

    initial_options = @options.merge(
      order_id: 'Net_Id1',
      stored_credential: {
        initial_transaction: true,
        reason_type: 'recurring',
        initiator: 'merchant',
        network_transaction_id: nil
      }
    )
    assert auth = @gateway.authorize(4999, credit_card, initial_options)
    assert_success auth
    assert_equal 'Transaction Received: This is sent to acknowledge that the submitted transaction has been received.', auth.message
    assert network_transaction_id = auth.params['networkTransactionId']

    assert capture = @gateway.capture(4999, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message

    used_options = @options.merge(
      order_id: 'Net_Id1a',
      stored_credential: {
        initial_transaction: false,
        reason_type: 'recurring',
        initiator: 'merchant',
        network_transaction_id: network_transaction_id
      }
    )

    assert auth = @gateway.authorize(4999, credit_card, used_options)
    assert_success auth
    assert_equal 'Transaction Received: This is sent to acknowledge that the submitted transaction has been received.', auth.message

    assert capture = @gateway.capture(4999, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_authorize_and_capture_with_stored_credential_installment
    credit_card = CreditCard.new(@credit_card_hash.merge(
                                   number: '4457010000000009',
                                   month: '01',
                                   year: '2021',
                                   verification_value: '349'
                                 ))

    initial_options = @options.merge(
      order_id: 'Net_Id2',
      stored_credential: {
        initial_transaction: true,
        reason_type: 'installment',
        initiator: 'merchant',
        network_transaction_id: nil
      }
    )
    assert auth = @gateway.authorize(5500, credit_card, initial_options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert network_transaction_id = auth.params['networkTransactionId']

    assert capture = @gateway.capture(5500, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message

    used_options = @options.merge(
      order_id: 'Net_Id2a',
      stored_credential: {
        initial_transaction: false,
        reason_type: 'installment',
        initiator: 'merchant',
        network_transaction_id: network_transaction_id
      }
    )
    assert auth = @gateway.authorize(5500, credit_card, used_options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(5500, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_authorize_and_capture_with_stored_credential_mit_card_on_file
    credit_card = CreditCard.new(@credit_card_hash.merge(
                                   number: '4457000800000002',
                                   month: '01',
                                   year: '2021',
                                   verification_value: '349'
                                 ))

    initial_options = @options.merge(
      order_id: 'Net_Id3',
      stored_credential: {
        initial_transaction: true,
        reason_type: 'unscheduled',
        initiator: 'merchant',
        network_transaction_id: nil
      }
    )
    assert auth = @gateway.authorize(5500, credit_card, initial_options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert network_transaction_id = auth.params['networkTransactionId']

    assert capture = @gateway.capture(5500, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message

    used_options = @options.merge(
      order_id: 'Net_Id3a',
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        initiator: 'merchant',
        network_transaction_id: network_transaction_id
      }
    )
    assert auth = @gateway.authorize(2500, credit_card, used_options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(2500, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_authorize_and_capture_with_stored_credential_cit_card_on_file
    credit_card = CreditCard.new(@credit_card_hash.merge(
                                   number: '4457000800000002',
                                   month: '01',
                                   year: '2021',
                                   verification_value: '349'
                                 ))

    initial_options = @options.merge(
      order_id: 'Net_Id3',
      stored_credential: {
        initial_transaction: true,
        reason_type: 'unscheduled',
        initiator: 'cardholder',
        network_transaction_id: nil
      }
    )
    assert auth = @gateway.authorize(5500, credit_card, initial_options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert network_transaction_id = auth.params['networkTransactionId']

    assert capture = @gateway.capture(5500, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message

    used_options = @options.merge(
      order_id: 'Net_Id3b',
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        initiator: 'cardholder',
        network_transaction_id: network_transaction_id
      }
    )
    assert auth = @gateway.authorize(4000, credit_card, used_options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(4000, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_purchase_with_stored_credential_cit_card_on_file_non_ecommerce
    credit_card = CreditCard.new(@credit_card_hash.merge(
                                   number: '4457000800000002',
                                   month: '01',
                                   year: '2021',
                                   verification_value: '349'
                                 ))

    initial_options = @options.merge(
      order_id: 'Net_Id3',
      order_source: '3dsAuthenticated',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      cavv: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      stored_credential: {
        initial_transaction: true,
        reason_type: 'unscheduled',
        initiator: 'cardholder',
        network_transaction_id: nil
      }
    )
    assert auth = @gateway.purchase(5500, credit_card, initial_options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert network_transaction_id = auth.params['networkTransactionId']

    used_options = @options.merge(
      order_id: 'Net_Id3b',
      order_source: '3dsAuthenticated',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      cavv: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        initiator: 'cardholder',
        network_transaction_id: network_transaction_id
      }
    )
    assert auth = @gateway.purchase(4000, credit_card, used_options)

    assert_success auth
    assert_equal 'Approved', auth.message
  end

  def test_void_with_echeck
    options = @options.merge({
      order_id: '42',
      order_source: 'telephone'
    })
    assert sale = @gateway.purchase(2004, @check, options)

    assert void = @gateway.void(sale.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_void_authorization
    assert auth = @gateway.authorize(10010, @credit_card1, @options)

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_unsuccessful_void
    assert void = @gateway.void('1234567890r2345360;authorization;100')
    assert_failure void
    assert_match(/^Error validating xml data against the schema/, void.message)
  end

  def test_successful_credit
    assert credit = @gateway.credit(123456, @credit_card1, @options)
    assert_success credit
    assert_equal 'Approved', credit.message
  end

  def test_failed_credit
    @credit_card1.number = '1234567890'
    assert credit = @gateway.credit(1, @credit_card1, @options)
    assert_failure credit
  end

  def test_partial_refund
    assert purchase = @gateway.purchase(10010, @credit_card1, @options)

    assert refund = @gateway.refund(444, purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_partial_refund_with_echeck
    options = @options.merge({
      order_id: '82',
      order_source: 'telephone'
    })
    assert purchase = @gateway.purchase(2004, @check, options)

    assert refund = @gateway.refund(444, purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_partial_capture
    assert auth = @gateway.authorize(10010, @credit_card1, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(5005, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_full_amount_capture
    assert auth = @gateway.authorize(10010, @credit_card1, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(10010, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_nil_amount_capture
    assert auth = @gateway.authorize(10010, @credit_card1, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_capture_unsuccessful
    assert capture_response = @gateway.capture(10010, '123456789w123')
    assert_failure capture_response
    assert_match(/^Error validating xml data against the schema/, capture_response.message)
  end

  def test_refund_unsuccessful
    assert credit_response = @gateway.refund(10010, '123456789w123')
    assert_failure credit_response
    assert_match(/^Error validating xml data against the schema/, credit_response.message)
  end

  def test_void_unsuccessful
    assert void_response = @gateway.void('123456789012345360')
    assert_failure void_response
    assert_equal 'No transaction found with specified Transaction Id', void_response.message
  end

  def test_store_successful
    credit_card = CreditCard.new(@credit_card_hash.merge(number: '4457119922390123'))
    assert store_response = @gateway.store(credit_card, order_id: '50')

    assert_success store_response
    assert_equal 'Account number was successfully registered', store_response.message
    assert_equal '801', store_response.params['response']
    assert_equal '1111222233334444', store_response.params['litleToken']
  end

  def test_store_with_paypage_registration_id_successful
    paypage_registration_id = 'cDZJcmd1VjNlYXNaSlRMTGpocVZQY1NNlYE4ZW5UTko4NU9KK3p1L1p1VzE4ZWVPQVlSUHNITG1JN2I0NzlyTg='
    assert store_response = @gateway.store(paypage_registration_id, order_id: '50')

    assert_success store_response
    assert_equal 'Account number was successfully registered', store_response.message
    assert_equal '801', store_response.params['response']
    assert_equal '1111222233334444', store_response.params['litleToken']
  end

  def test_store_unsuccessful
    credit_card = CreditCard.new(@credit_card_hash.merge(number: '4100282090123000'))
    assert store_response = @gateway.store(credit_card, order_id: '51')

    assert_failure store_response
    assert_equal 'Credit card Number was invalid', store_response.message
    assert_equal '820', store_response.params['response']
  end

  def test_store_and_purchase_with_token_successful
    credit_card = CreditCard.new(@credit_card_hash.merge(number: '4100280190123000'))
    assert store_response = @gateway.store(credit_card, order_id: '50')
    assert_success store_response

    token = store_response.authorization
    assert_equal store_response.params['litleToken'], token

    assert response = @gateway.purchase(10010, token)
    assert_success response
    assert_equal 'Partially Approved: The authorized amount is less than the requested amount.', response.message
  end

  def test_purchase_with_token_and_date_successful
    assert store_response = @gateway.store(@credit_card1, order_id: '50')
    assert_success store_response

    token = store_response.authorization
    assert_equal store_response.params['litleToken'], token

    assert response = @gateway.purchase(10010, token, { basis_expiration_month: '01', basis_expiration_year: '2024' })
    assert_success response
    assert_equal 'Partially Approved: The authorized amount is less than the requested amount.', response.message
  end

  def test_echeck_store_and_purchase
    assert store_response = @gateway.store(@store_check)
    assert_success store_response
    assert_equal 'Account number was successfully registered', store_response.message

    token = store_response.authorization
    assert_equal store_response.params['litleToken'], token

    assert response = @gateway.purchase(10010, token)
    assert_success response
    assert_equal 'Partially Approved: The authorized amount is less than the requested amount.', response.message
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card1, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_success response.responses.last, 'The void should succeed'
  end

  def test_unsuccessful_verify
    assert response = @gateway.verify(@credit_card_nsf, @options)
    assert_failure response
    assert_match %r{Insufficient Funds}, response.message
  end

  def test_successful_purchase_with_dynamic_descriptors
    assert response = @gateway.purchase(10010, @credit_card1, @options.merge(
                                                                descriptor_name: 'SuperCompany',
                                                                descriptor_phone: '9193341121'
                                                              ))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_xml_schema_validation
    credit_card = CreditCard.new(@credit_card_hash.merge(number: '123456'))
    assert store_response = @gateway.store(credit_card, order_id: '51')

    assert_failure store_response
    assert_match(/^Error validating xml data against the schema/, store_response.message)
    assert_equal '1', store_response.params['response']
  end

  def test_purchase_scrubbing
    credit_card = CreditCard.new(@credit_card_hash.merge(verification_value: '999'))
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(10010, credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:login], transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_echeck_scrubbing
    options = @options.merge({
      order_id: '42',
      order_source: 'telephone'
    })
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(2004, @check, options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@gateway.options[:login], transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
