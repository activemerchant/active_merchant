require 'test_helper'

class RemoteBraintreeBlueTest < Test::Unit::TestCase
  def setup
    fixture_key = method_name.match?(/bank_account/i) ? :braintree_blue_with_ach_enabled : :braintree_blue
    @gateway = BraintreeGateway.new(fixtures(fixture_key))
    @braintree_backend = @gateway.instance_eval { @braintree_gateway }

    @amount = 100
    @declined_amount = 2000_00
    @credit_card = credit_card('5105105105105100')
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: '1',
      billing_address: address(country_name: 'Canada'),
      description: 'Store Purchase'
    }

    ach_mandate = 'By clicking "Checkout", I authorize Braintree, a service of PayPal, ' \
      'on behalf of My Company (i) to verify my bank account information ' \
      'using bank information and consumer reports and (ii) to debit my bank account.'

    @check_required_options = {
      billing_address: {
        address1: '1670',
        address2: '1670 NW 82ND AVE',
        city: 'Miami',
        state: 'FL',
        zip: '32191'
      },
      ach_mandate: ach_mandate
    }

    @nt_credit_card = network_tokenization_credit_card('4111111111111111',
                                                       brand: 'visa',
                                                       eci: '05',
                                                       source: :network_token,
                                                       payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')
  end

  def test_credit_card_details_on_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal '5100', response.params['braintree_customer']['credit_cards'].first['last_4']
    assert_equal('510510******5100', response.params['braintree_customer']['credit_cards'].first['masked_number'])
    assert_equal('5100', response.params['braintree_customer']['credit_cards'].first['last_4'])
    assert_equal('MasterCard', response.params['braintree_customer']['credit_cards'].first['card_type'])
    assert_equal('510510', response.params['braintree_customer']['credit_cards'].first['bin'])
    assert_match %r{^\d+$}, response.params['customer_vault_id']
    assert_equal response.params['customer_vault_id'], response.authorization
    assert_match %r{^\w+$}, response.params['credit_card_token']
    assert_equal response.params['credit_card_token'], response.params['braintree_customer']['credit_cards'].first['token']
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'authorized', response.params['braintree_transaction']['status']
  end

  def test_successful_authorize_with_nt
    assert response = @gateway.authorize(@amount, @nt_credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'authorized', response.params['braintree_transaction']['status']
  end

  def test_successful_authorize_with_nil_and_empty_billing_address_options
    credit_card = credit_card('5105105105105100')
    options = {
      billing_address: {
        name: 'John Smith',
        phone: '123-456-7890',
        company: nil,
        address1: nil,
        address2: '',
        city: nil,
        state: nil,
        zip: nil,
        country: ''
      }
    }
    assert response = @gateway.authorize(@amount, credit_card, options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'authorized', response.params['braintree_transaction']['status']
  end

  def test_masked_card_number
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal('510510******5100', response.params['braintree_transaction']['credit_card_details']['masked_number'])
    assert_equal('5100', response.params['braintree_transaction']['credit_card_details']['last_4'])
    assert_equal('MasterCard', response.params['braintree_transaction']['credit_card_details']['card_type'])
    assert_equal('510510', response.params['braintree_transaction']['credit_card_details']['bin'])
  end

  def test_successful_setup_purchase
    assert response = @gateway.setup_purchase
    assert_success response
    assert_equal 'Client token created', response.message
    assert_not_nil response.params['client_token']
  end

  def test_successful_setup_purchase_with_merchant_account_id
    assert response = @gateway.setup_purchase(merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id])
    assert_success response
    assert_equal 'Client token created', response.message

    assert_not_nil response.params['client_token']
  end

  def test_successful_authorize_with_order_id
    assert response = @gateway.authorize(@amount, @credit_card, order_id: '123')
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal '123', response.params['braintree_transaction']['order_id']
  end

  def test_successful_purchase_with_hold_in_escrow
    @options.merge({ merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id], hold_in_escrow: true })
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
  end

  def test_successful_purchase_using_vault_id
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    customer_vault_id = response.params['customer_vault_id']
    assert_match(/\A\d+\z/, customer_vault_id)

    assert response = @gateway.purchase(@amount, customer_vault_id)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
    assert_equal customer_vault_id, response.params['braintree_transaction']['customer_details']['id']
  end

  def test_successful_purchase_using_vault_id_as_integer
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    customer_vault_id = response.params['customer_vault_id']
    assert_match %r{\A\d+\z}, customer_vault_id

    assert response = @gateway.purchase(@amount, customer_vault_id.to_i)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
    assert_equal customer_vault_id, response.params['braintree_transaction']['customer_details']['id']
  end

  def test_successful_purchase_using_card_token
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    credit_card_token = response.params['credit_card_token']
    assert_match %r{^\w+$}, credit_card_token

    assert response = @gateway.purchase(@amount, credit_card_token, payment_method_token: true)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_purchase_with_level_2_data
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(tax_amount: '20', purchase_order_number: '6789'))
    assert_success response
    assert_equal '1000 Approved', response.message
  end

  def test_successful_purchase_with_level_2_and_3_data
    options = {
      tax_amount: '20',
      purchase_order_number: '6789',
      shipping_amount: '300',
      discount_amount: '150',
      ships_from_postal_code: '90210',
      line_items: [
        {
          name: 'Product Name',
          kind: 'debit',
          quantity: '10.0000',
          unit_amount: '9.5000',
          unit_of_measure: 'unit',
          total_amount: '95.00',
          tax_amount: '5.00',
          discount_amount: '0.00',
          product_code: '54321',
          commodity_code: '98765'
        },
        {
          name: 'Other Product Name',
          kind: 'debit',
          quantity: '1.0000',
          unit_amount: '2.5000',
          unit_of_measure: 'unit',
          total_amount: '90.00',
          tax_amount: '2.00',
          discount_amount: '1.00',
          product_code: '54322',
          commodity_code: '98766'
        }
      ]
    }
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
    assert_equal '1000 Approved', response.message
  end

  def test_successful_purchase_sending_risk_data
    options = @options.merge(
      risk_data: {
        customer_browser: 'User-Agent Header',
        customer_ip: '127.0.0.1'
      }
    )
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_paypal_options
    options = @options.merge(
      paypal_custom_field: 'abc',
      paypal_description: 'shoes'
    )
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  # Follow instructions found at https://developer.paypal.com/braintree/articles/guides/payment-methods/venmo#multiple-profiles
  # for sandbox control panel https://sandbox.braintreegateway.com/login to create a venmo profile.
  # Insert your Profile Id into fixtures.
  def test_successful_purchase_with_venmo_profile_id
    options = @options.merge(venmo_profile_id: fixtures(:braintree_blue)[:venmo_profile_id], payment_method_nonce: 'fake-venmo-account-nonce')
    assert response = @gateway.purchase(@amount, 'fake-venmo-account-nonce', options)
    assert_success response
  end

  def test_successful_partial_capture
    options = @options.merge(venmo_profile_id: fixtures(:braintree_blue)[:venmo_profile_id], payment_method_nonce: 'fake-venmo-account-nonce')
    assert auth = @gateway.authorize(@amount, 'fake-venmo-account-nonce', options)
    assert_success auth
    assert_equal '1000 Approved', auth.message
    assert auth.authorization
    assert capture_one = @gateway.capture(50, auth.authorization, { partial_capture: true })
    assert_success capture_one
    assert capture_two = @gateway.capture(50, auth.authorization, { partial_capture: true })
    assert_success capture_two
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
  end

  def test_failed_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{number is not an accepted test number}, response.message
  end

  def test_successful_credit_card_verification
    card = credit_card('4111111111111111')
    assert response = @gateway.verify(card, @options.merge({ allow_card_verification: true, merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id] }))
    assert_success response

    assert_match 'OK', response.message
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'M', response.avs_result['code']
  end

  def test_successful_credit_card_verification_without_billing_address
    options = {
      order_ID: '1',
      description: 'store purchase'
    }
    card = credit_card('4111111111111111')
    assert response = @gateway.verify(card, options.merge({ allow_card_verification: true, merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id] }))
    assert_success response

    assert_match 'OK', response.message
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'I', response.avs_result['code']
  end

  def test_successful_credit_card_verification_with_only_address
    options = {
      order_ID: '1',
      description: 'store purchase',
      billing_address: {
        address1: '456 My Street'
      }
    }
    card = credit_card('4111111111111111')
    assert response = @gateway.verify(card, options.merge({ allow_card_verification: true, merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id] }))
    assert_success response

    assert_match 'OK', response.message
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'B', response.avs_result['code']
  end

  def test_successful_credit_card_verification_with_only_zip
    options = {
      order_ID: '1',
      description: 'store purchase',
      billing_address: {
        zip: 'K1C2N6'
      }
    }
    card = credit_card('4111111111111111')
    assert response = @gateway.verify(card, options.merge({ allow_card_verification: true, merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id] }))
    assert_success response

    assert_match 'OK', response.message
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'P', response.avs_result['code']
  end

  def test_failed_credit_card_verification
    credit_card = credit_card('378282246310005', verification_value: '544')

    assert response = @gateway.verify(credit_card, @options.merge({ allow_card_verification: true }))
    assert_failure response
    assert_match 'CVV must be 4 digits for American Express and 3 digits for other card types. (81707)', response.message
  end

  def test_successful_verify_with_device_data
    # Requires Advanced Fraud Tools to be enabled
    assert response = @gateway.verify(@credit_card, @options.merge({ device_data: 'device data for verify' }))
    assert_success response
    assert_equal '1000 Approved', response.message

    assert transaction = response.params['braintree_transaction']
    assert transaction['risk_data']
    assert transaction['risk_data']['id']
    assert_equal 'Approve', transaction['risk_data']['decision']
    assert_equal false, transaction['risk_data']['device_data_captured']
    assert_equal 'fraud_protection', transaction['risk_data']['fraud_service_provider']
  end

  def test_successful_validate_on_store
    card = credit_card('4111111111111111', verification_value: '101')
    assert response = @gateway.store(card, verify_card: true)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_failed_validate_on_store
    card = credit_card('4000111111111115', verification_value: '200')
    assert response = @gateway.store(card, verify_card: true)
    assert_failure response
    assert_equal 'Processor declined: Do Not Honor (2000)', response.message
  end

  def test_successful_store_with_no_validate
    card = credit_card('4000111111111115', verification_value: '200')
    assert response = @gateway.store(card, verify_card: false)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_store_with_invalid_card
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_store_with_billing_address
    billing_address = {
      address1: '1 E Main St',
      address2: 'Suite 403',
      city: 'Chicago',
      state: 'Illinois',
      zip: '60622',
      country_name: 'United States of America'
    }
    credit_card = credit_card('5105105105105100')
    assert response = @gateway.store(credit_card, billing_address: billing_address)
    assert_success response
    assert_equal 'OK', response.message

    vault_id = response.params['customer_vault_id']
    purchase_response = @gateway.purchase(@amount, vault_id)
    response_billing_details = {
      'country_name' => 'United States of America',
      'region' => 'Illinois',
      'company' => nil,
      'postal_code' => '60622',
      'extended_address' => 'Suite 403',
      'street_address' => '1 E Main St',
      'locality' => 'Chicago'
    }
    assert_equal purchase_response.params['braintree_transaction']['billing_details'], response_billing_details
  end

  def test_successful_store_with_nil_billing_address_options
    billing_address = {
      name: 'John Smith',
      phone: '123-456-7890',
      company: nil,
      address1: nil,
      address2: nil,
      city: nil,
      state: nil,
      zip: nil,
      country_name: nil
    }
    credit_card = credit_card('5105105105105100')
    assert response = @gateway.store(credit_card, billing_address: billing_address)
    assert_success response
    assert_equal 'OK', response.message

    vault_id = response.params['customer_vault_id']
    purchase_response = @gateway.purchase(@amount, vault_id)
    assert_success purchase_response
  end

  def test_successful_store_with_credit_card_token
    credit_card = credit_card('5105105105105100')
    credit_card_token = generate_unique_id
    assert response = @gateway.store(credit_card, credit_card_token: credit_card_token)
    assert_success response
    assert_equal 'OK', response.message
    assert_equal credit_card_token, response.params['braintree_customer']['credit_cards'][0]['token']
  end

  def test_successful_store_with_new_customer_id
    credit_card = credit_card('5105105105105100')
    customer_id = generate_unique_id
    assert response = @gateway.store(credit_card, customer: customer_id)
    assert_success response
    assert_equal 'OK', response.message
    assert_equal customer_id, response.authorization
    assert_equal customer_id, response.params['braintree_customer']['id']
  end

  def test_successful_store_with_existing_customer_id
    credit_card = credit_card('5105105105105100')
    customer_id = generate_unique_id
    assert response = @gateway.store(credit_card, @options.merge(customer: customer_id))
    assert_success response
    assert_equal 1, @braintree_backend.customer.find(customer_id).credit_cards.size

    credit_card = credit_card('4111111111111111')
    assert response = @gateway.store(credit_card, @options.merge(customer: customer_id))
    assert_success response
    assert_equal 2, @braintree_backend.customer.find(customer_id).credit_cards.size
    assert_equal customer_id, response.params['customer_vault_id']
    assert_equal customer_id, response.authorization
    assert_not_nil response.params['credit_card_token']
  end

  def test_successful_store_with_existing_customer_id_and_nil_billing_address_options
    credit_card = credit_card('5105105105105100')
    customer_id = generate_unique_id
    options = {
      customer: customer_id,
      billing_address: {
        name: 'John Smith',
        phone: '123-456-7890',
        company: nil,
        address1: nil,
        address2: nil,
        city: nil,
        state: nil,
        zip: nil,
        country_name: nil
      }
    }
    assert response = @gateway.store(credit_card, options)
    assert_success response
    assert_equal 1, @braintree_backend.customer.find(customer_id).credit_cards.size

    assert response = @gateway.store(credit_card, options)
    assert_success response
    assert_equal 2, @braintree_backend.customer.find(customer_id).credit_cards.size
    assert_equal customer_id, response.params['customer_vault_id']
    assert_equal customer_id, response.authorization
    assert_not_nil response.params['credit_card_token']
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::BraintreeBlueGateway.application_id = 'ABC123'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  ensure
    ActiveMerchant::Billing::BraintreeBlueGateway.application_id = nil
  end

  def test_avs
    assert_avs('1 Elm', '60622', 'M')
    assert_avs('1 Elm', '20000', 'A')
    assert_avs('1 Elm', '20001', 'B')
    assert_avs('1 Elm', '', 'B')

    assert_avs('200 Elm', '60622', 'Z')
    assert_avs('200 Elm', '20000', 'C')
    assert_avs('200 Elm', '20001', 'C')
    assert_avs('200 Elm', '', 'C')

    assert_avs('201 Elm', '60622', 'P')
    assert_avs('201 Elm', '20000', 'N')
    assert_avs('201 Elm', '20001', 'I')
    assert_avs('201 Elm', '', 'I')

    assert_avs('', '60622', 'P')
    assert_avs('', '20000', 'C')
    assert_avs('', '20001', 'I')
    assert_avs('', '', 'I')

    assert_avs('1 Elm', '30000', 'E')
    assert_avs('1 Elm', '30001', 'S')
  end

  def test_cvv_match
    assert response = @gateway.purchase(@amount, credit_card('5105105105105100', verification_value: '400'))
    assert_success response
    assert_equal({ 'code' => 'M', 'message' => '' }, response.cvv_result)
  end

  def test_cvv_no_match
    assert response = @gateway.purchase(@amount, credit_card('5105105105105100', verification_value: '200'))
    assert_success response
    assert_equal({ 'code' => 'N', 'message' => '' }, response.cvv_result)
  end

  def test_successful_purchase_with_email
    assert response = @gateway.purchase(@amount, @credit_card, email: 'customer@example.com')
    assert_success response
    transaction = response.params['braintree_transaction']
    assert_equal 'customer@example.com', transaction['customer_details']['email']
  end

  def test_successful_purchase_with_phone
    assert response = @gateway.purchase(@amount, @credit_card, phone: '123-345-5678')
    assert_success response
    transaction = response.params['braintree_transaction']
    assert_equal '123-345-5678', transaction['customer_details']['phone']
  end

  def test_successful_purchase_with_phone_from_address
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    transaction = response.params['braintree_transaction']
    assert_equal '(555)555-5555', transaction['customer_details']['phone']
  end

  def test_successful_purchase_with_phone_number_from_address
    @options[:billing_address][:phone] = nil
    @options[:billing_address][:phone_number] = '9191231234'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    transaction = response.params['braintree_transaction']
    assert_equal '9191231234', transaction['customer_details']['phone']
  end

  def test_successful_purchase_with_skip_advanced_fraud_checking_option
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(skip_advanced_fraud_checking: true))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_purchase_with_skip_avs
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(skip_avs: true))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'B', response.avs_result['code']
  end

  def test_successful_purchase_with_skip_cvv
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(skip_cvv: true))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'B', response.cvv_result['code']
  end

  def test_successful_purchase_with_device_data
    # Requires Advanced Fraud Tools to be enabled
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(device_data: 'device data for purchase'))
    assert_success response
    assert_equal '1000 Approved', response.message

    assert transaction = response.params['braintree_transaction']
    assert transaction['risk_data']
    assert transaction['risk_data']['id']
    assert_equal true, ['Not Evaluated', 'Approve'].include?(transaction['risk_data']['decision'])
    assert_equal false, transaction['risk_data']['device_data_captured']
    assert_equal 'fraud_protection', transaction['risk_data']['fraud_service_provider']
  end

  def test_purchase_with_store_using_random_customer_id
    assert response = @gateway.purchase(
      @amount, credit_card('5105105105105100'), @options.merge(store: true)
    )
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_match(/\A\d+\z/, response.params['customer_vault_id'])
    assert_equal '510510', response.params['braintree_transaction']['vault_customer']['credit_cards'][0]['bin']
    assert_equal '510510', @braintree_backend.customer.find(response.params['customer_vault_id']).credit_cards[0].bin
  end

  def test_purchase_with_store_using_specified_customer_id
    customer_id = rand(1_000_000_000).to_s
    assert response = @gateway.purchase(
      @amount, credit_card('5105105105105100'), @options.merge(store: customer_id)
    )
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal customer_id, response.params['customer_vault_id']
    assert_equal '510510', response.params['braintree_transaction']['vault_customer']['credit_cards'][0]['bin']
    assert_equal '510510', @braintree_backend.customer.find(response.params['customer_vault_id']).credit_cards[0].bin
  end

  def test_purchase_with_transaction_source
    assert response = @gateway.store(@credit_card)
    assert_success response
    customer_vault_id = response.params['customer_vault_id']

    assert response = @gateway.purchase(@amount, customer_vault_id, @options.merge(transaction_source: 'unscheduled'))
    assert_success response
    assert_equal '1000 Approved', response.message
  end

  def test_purchase_using_specified_payment_method_token
    assert response = @gateway.store(
      credit_card('4111111111111111', first_name: 'Old First', last_name: 'Old Last', month: 9, year: 2012),
      email: 'old@example.com',
      phone: '321-654-0987'
    )
    payment_method_token = response.params['braintree_customer']['credit_cards'][0]['token']
    assert response = @gateway.purchase(
      @amount, payment_method_token, @options.merge(payment_method_token: true)
    )
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal payment_method_token, response.params['braintree_transaction']['credit_card_details']['token']
  end

  def test_successful_purchase_with_addresses
    billing_address = {
      address1: '1 E Main St',
      address2: 'Suite 101',
      company: 'Widgets Co',
      city: 'Chicago',
      state: 'IL',
      zip: '60622',
      country_name: 'United States of America'
    }
    shipping_address = {
      address1: '1 W Main St',
      address2: 'Suite 102',
      company: 'Widgets Company',
      city: 'Bartlett',
      state: 'Illinois',
      zip: '60103',
      country_name: 'Mexico'
    }
    assert response = @gateway.purchase(
      @amount,
      @credit_card,
      billing_address: billing_address,
      shipping_address: shipping_address
    )
    assert_success response
    transaction = response.params['braintree_transaction']
    assert_equal '1 E Main St', transaction['billing_details']['street_address']
    assert_equal 'Suite 101', transaction['billing_details']['extended_address']
    assert_equal 'Widgets Co', transaction['billing_details']['company']
    assert_equal 'Chicago', transaction['billing_details']['locality']
    assert_equal 'IL', transaction['billing_details']['region']
    assert_equal '60622', transaction['billing_details']['postal_code']
    assert_equal 'United States of America', transaction['billing_details']['country_name']
    assert_equal '1 W Main St', transaction['shipping_details']['street_address']
    assert_equal 'Suite 102', transaction['shipping_details']['extended_address']
    assert_equal 'Widgets Company', transaction['shipping_details']['company']
    assert_equal 'Bartlett', transaction['shipping_details']['locality']
    assert_equal 'Illinois', transaction['shipping_details']['region']
    assert_equal '60103', transaction['shipping_details']['postal_code']
    assert_equal 'Mexico', transaction['shipping_details']['country_name']
  end

  def test_successful_purchase_with_three_d_secure_pass_thru_and_sca_exemption
    options = {
      three_ds_exemption_type: 'low_value',
      three_d_secure: { version: '2.0', cavv: 'cavv', eci: '02', ds_transaction_id: 'trans_id', cavv_algorithm: 'algorithm', directory_response_status: 'directory', authentication_response_status: 'auth' }
    }
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_some_three_d_secure_pass_thru_fields
    three_d_secure_params = { version: '2.0', cavv: 'cavv', eci: '02', ds_transaction_id: 'trans_id' }
    response = @gateway.purchase(@amount, @credit_card, three_d_secure: three_d_secure_params)
    assert_success response
  end

  def test_unsuccessful_purchase_declined
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert response.authorization.present?
    assert_equal '2000 Do Not Honor', response.message
  end

  def test_unsuccessful_purchase_validation_error
    assert response = @gateway.purchase(@amount, credit_card('51051051051051000'))
    assert_failure response
    assert_match %r{Credit card number is invalid\. \(81715\)}, response.message
    assert_equal('91577', response.params['braintree_transaction']['processor_response_code'])
  end

  def test_unsuccessful_purchase_with_additional_processor_response
    assert response = @gateway.purchase(204700, @credit_card)
    assert_failure response
    assert_equal('2047 : Call Issuer. Pick Up Card.', response.params['braintree_transaction']['additional_processor_response'])
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal '1000 Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_capture_with_apple_pay_card
    credit_card = network_tokenization_credit_card(
      '4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    assert auth = @gateway.authorize(@amount, credit_card, @options)
    assert_success auth
    assert_equal '1000 Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_capture_with_google_pay_card
    credit_card = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '01',
      year: '2024',
      source: :google_pay,
      transaction_id: '123456789',
      eci: '05'
    )

    assert auth = @gateway.authorize(@amount, credit_card, @options)
    assert_success auth
    assert_equal '1000 Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal '1000 Approved', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'voided', void.params['braintree_transaction']['status']
  end

  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'voided', void.params['braintree_transaction']['status']
  end

  def test_capture_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert void = @gateway.void(capture.authorization)
    assert_success void
    assert_equal 'voided', void.params['braintree_transaction']['status']
  end

  def test_failed_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal '1000 Approved', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'voided', void.params['braintree_transaction']['status']
    assert failed_void = @gateway.void(auth.authorization)
    assert_failure failed_void
    assert_match('Transaction can only be voided if status is authorized', failed_void.message)
    assert_equal('91504', failed_void.params['braintree_transaction']['processor_response_code'])
  end

  def test_failed_capture_with_invalid_transaction_id
    assert response = @gateway.capture(@amount, 'invalidtransactionid')
    assert_failure response
    assert_equal 'Braintree::NotFoundError', response.message
  end

  def test_invalid_login
    gateway = BraintreeBlueGateway.new(merchant_id: 'invalid', public_key: 'invalid', private_key: 'invalid')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Braintree::AuthenticationError', response.message
  end

  def test_successful_add_to_vault_with_store_method
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    assert_match(/\A\d+\z/, response.params['customer_vault_id'])
  end

  def test_failed_add_to_vault
    assert response = @gateway.store(credit_card('5105105105105101'))
    assert_failure response
    assert_equal 'Credit card number is invalid. (81715)', response.message
    assert_equal nil, response.params['braintree_customer']
    assert_equal nil, response.params['customer_vault_id']
  end

  def test_unstore_customer
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    assert customer_vault_id = response.params['customer_vault_id']
    assert delete_response = @gateway.unstore(customer_vault_id)
    assert_success delete_response
  end

  def test_unstore_credit_card
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    assert credit_card_token = response.params['credit_card_token']
    assert delete_response = @gateway.unstore(nil, credit_card_token: credit_card_token)
    assert_success delete_response
  end

  def test_unstore_with_delete_method
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    assert customer_vault_id = response.params['customer_vault_id']
    assert delete_response = @gateway.delete(customer_vault_id)
    assert_success delete_response
  end

  def test_successful_update
    assert response = @gateway.store(
      credit_card('4111111111111111', first_name: 'Old First', last_name: 'Old Last', month: 9, year: 2012),
      email: 'old@example.com',
      phone: '321-654-0987'
    )
    assert_success response
    assert_equal 'OK', response.message
    customer_vault_id = response.params['customer_vault_id']
    assert_match(/\A\d+\z/, customer_vault_id)
    assert_equal 'old@example.com', response.params['braintree_customer']['email']
    assert_equal '321-654-0987', response.params['braintree_customer']['phone']
    assert_equal 'Old First', response.params['braintree_customer']['first_name']
    assert_equal 'Old Last', response.params['braintree_customer']['last_name']
    assert_equal '411111', response.params['braintree_customer']['credit_cards'][0]['bin']
    assert_equal '09/2012', response.params['braintree_customer']['credit_cards'][0]['expiration_date']
    assert_not_nil response.params['braintree_customer']['credit_cards'][0]['token']
    assert_equal customer_vault_id, response.params['braintree_customer']['id']

    assert response = @gateway.update(
      customer_vault_id,
      credit_card('5105105105105100', first_name: 'New First', last_name: 'New Last', month: 10, year: 2014),
      email: 'new@example.com',
      phone: '987-765-5432'
    )
    assert_success response
    assert_equal 'new@example.com', response.params['braintree_customer']['email']
    assert_equal '987-765-5432', response.params['braintree_customer']['phone']
    assert_equal 'New First', response.params['braintree_customer']['first_name']
    assert_equal 'New Last', response.params['braintree_customer']['last_name']
    assert_equal '510510', response.params['braintree_customer']['credit_cards'][0]['bin']
    assert_equal '10/2014', response.params['braintree_customer']['credit_cards'][0]['expiration_date']
    assert_not_nil response.params['braintree_customer']['credit_cards'][0]['token']
    assert_equal customer_vault_id, response.params['braintree_customer']['id']
  end

  def test_failed_customer_update
    assert response = @gateway.store(credit_card('4111111111111111'), email: 'email@example.com', phone: '321-654-0987')
    assert_success response
    assert_equal 'OK', response.message
    assert customer_vault_id = response.params['customer_vault_id']

    assert response = @gateway.update(
      customer_vault_id,
      credit_card('51051051051051001')
    )
    assert_failure response
    assert_equal 'Credit card number is invalid. (81715)', response.message
    assert_equal nil, response.params['braintree_customer']
    assert_equal nil, response.params['customer_vault_id']
  end

  def test_failed_customer_update_invalid_vault_id
    assert response = @gateway.update('invalid-customer-id', credit_card('5105105105105100'))
    assert_failure response
    assert_equal 'Braintree::NotFoundError', response.message
  end

  def test_failed_credit_card_update
    assert response = @gateway.store(credit_card('4111111111111111'))
    assert_success response
    assert_equal 'OK', response.message
    assert customer_vault_id = response.params['customer_vault_id']

    assert response = @gateway.update(
      customer_vault_id,
      credit_card('5105105105105101')
    )
    assert_failure response
    assert_equal 'Credit card number is invalid. (81715)', response.message
  end

  def test_failed_credit_card_update_on_verify
    assert response = @gateway.store(credit_card('4111111111111111'))
    assert_success response
    assert_equal 'OK', response.message
    assert customer_vault_id = response.params['customer_vault_id']

    assert response = @gateway.update(
      customer_vault_id,
      credit_card('4000111111111115'),
      { verify_card: true }
    )
    assert_failure response
    assert_equal 'Processor declined: Do Not Honor (2000)', response.message
  end

  def test_customer_does_not_have_credit_card_failed_update
    customer_without_credit_card = @braintree_backend.customer.create
    assert response = @gateway.update(customer_without_credit_card.customer.id, credit_card('5105105105105100'))
    assert_failure response
    assert_equal 'Braintree::NotFoundError', response.message
  end

  def test_successful_credit
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response, 'You must get credits enabled in your Sandbox account for this to pass.'
    assert_equal '1002 Processed', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_failed_credit
    assert response = @gateway.credit(@amount, credit_card('5105105105105101'), @options)
    assert_failure response
    assert_equal 'Credit card number is invalid. (81715)', response.message, 'You must get credits enabled in your Sandbox account for this to pass'
  end

  def test_successful_credit_with_merchant_account_id
    assert response = @gateway.credit(@amount, @credit_card, merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id])
    assert_success response, 'You must specify a valid :merchant_account_id key in your fixtures.yml AND get credits enabled in your Sandbox account for this to pass.'
    assert_equal '1002 Processed', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_failed_credit_with_merchant_account_id
    assert response = @gateway.credit(@declined_amount, credit_card('4000111111111115'), merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id])
    assert_failure response
    assert_equal '2000 Do Not Honor', response.message
    assert_equal '2000 : Do Not Honor', response.params['braintree_transaction']['additional_processor_response']
  end

  def test_successful_credit_using_card_token
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    credit_card_token = response.params['credit_card_token']

    assert response = @gateway.credit(@amount, credit_card_token, { merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id], payment_method_token: true })
    assert_success response, 'You must specify a valid :merchant_account_id key in your fixtures.yml AND get credits enabled in your Sandbox account for this to pass.'
    assert_equal '1002 Processed', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_authorize_with_merchant_account_id
    assert response = @gateway.authorize(@amount, @credit_card, merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id])
    assert_success response, 'You must specify a valid :merchant_account_id key in your fixtures.yml for this to pass.'
    assert_equal '1000 Approved', response.message
    assert_equal 'authorized', response.params['braintree_transaction']['status']
  end

  def test_authorize_with_descriptor
    assert auth = @gateway.authorize(@amount, @credit_card, descriptor_name: 'company*theproduct', descriptor_phone: '1331131131', descriptor_url: 'company.com')
    assert_success auth
  end

  def test_authorize_with_travel_data
    assert auth = @gateway.authorize(
      @amount,
      @credit_card,
      travel_data: {
        travel_package: 'flight',
        departure_date: '2050-07-22',
        lodging_check_in_date: '2050-07-22',
        lodging_check_out_date: '2050-07-25',
        lodging_name: 'Best Hotel Ever'
      }
    )
    assert_success auth
  end

  def test_authorize_with_lodging_data
    assert auth = @gateway.authorize(
      @amount,
      @credit_card,
      lodging_data: {
        folio_number: 'ABC123',
        check_in_date: '2050-12-22',
        check_out_date: '2050-12-25',
        room_rate: '80.00'
      }
    )
    assert_success auth
  end

  def test_successful_validate_on_store_with_verification_merchant_account
    card = credit_card('4111111111111111', verification_value: '101')
    assert response = @gateway.store(card, verify_card: true, verification_merchant_account_id: fixtures(:braintree_blue)[:merchant_account_id])
    assert_success response, 'You must specify a valid :merchant_account_id key in your fixtures.yml for this to pass.'
    assert_equal 'OK', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = BraintreeGateway.new(merchant_id: 'UNKNOWN', public_key: 'UNKONWN', private_key: 'UNKONWN')
    assert !gateway.verify_credentials
  end

  def test_successful_recurring_first_stored_credential_v2
    creds_options = stored_credential_options(:cardholder, :recurring, :initial)
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options, stored_credentials_v2: true))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_not_nil response.params['braintree_transaction']['network_transaction_id']
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_follow_on_recurring_first_cit_stored_credential_v2
    creds_options = stored_credential_options(:cardholder, :recurring, id: '020190722142652')
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options, stored_credentials_v2: true))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_not_nil response.params['braintree_transaction']['network_transaction_id']
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_follow_on_recurring_first_mit_stored_credential_v2
    creds_options = stored_credential_options(:merchant, :recurring, id: '020190722142652')
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options, stored_credentials_v2: true))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_not_nil response.params['braintree_transaction']['network_transaction_id']
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_one_time_mit_stored_credential_v2
    creds_options = stored_credential_options(:merchant, id: '020190722142652')
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options, stored_credentials_v2: true))

    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
    assert_not_nil response.params['braintree_transaction']['network_transaction_id']
  end

  def test_successful_merchant_purchase_initial
    creds_options = stored_credential_options(:merchant, :recurring, :initial)
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options))

    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
    assert_not_nil response.params['braintree_transaction']['network_transaction_id']
  end

  def test_successful_subsequent_merchant_unscheduled_transaction
    creds_options = stored_credential_options(:merchant, :unscheduled, id: '020190722142652')
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_subsequent_merchant_recurring_transaction
    creds_options = stored_credential_options(:cardholder, :recurring, id: '020190722142652')
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_cardholder_purchase_initial
    creds_options = stored_credential_options(:cardholder, :recurring, :initial)
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_not_nil response.params['braintree_transaction']['network_transaction_id']
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_cardholder_purchase_recurring
    creds_options = stored_credential_options(:cardholder, :recurring, id: '020190722142652')
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_cardholder_purchase_unscheduled
    creds_options = stored_credential_options(:cardholder, :unscheduled, id: '020190722142652')
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_cardholder_purchase_initial_setup
    creds_options = { initiator: 'merchant', reason_type: 'recurring_first', initial_transaction: true }
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_not_nil response.params['braintree_transaction']['network_transaction_id']
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
    assert_equal true, response.params['braintree_transaction']['recurring']
  end

  def test_successful_cardholder_purchase_initial_moto
    creds_options = { initiator: 'merchant', reason_type: 'moto', initial_transaction: true }
    response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(stored_credential: creds_options))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_not_nil response.params['braintree_transaction']['network_transaction_id']
    assert_equal 'submitted_for_settlement', response.params['braintree_transaction']['status']
  end

  def test_successful_store_bank_account_with_a_new_customer
    bank_account = check({ account_number: '1000000000', routing_number: '011000015' })
    response = @gateway.store(bank_account, @options.merge(@check_required_options))

    assert_success response
    assert response.params['bank_account_token']
    assert response.params['verified']

    customer = @braintree_backend.customer.find(response.params['customer_vault_id'])
    bank_accounts = customer.us_bank_accounts
    created_bank_account = bank_accounts.first

    assert_equal 1, bank_accounts.size
    assert created_bank_account.verified
    assert_equal bank_account.routing_number, created_bank_account.routing_number
    assert_equal bank_account.account_number[-4..-1], created_bank_account.last_4
    assert_equal 'checking', created_bank_account.account_type
    assert_equal 'Jim', customer.first_name
    assert_equal 'Smith', customer.last_name
  end

  def test_successful_store_bank_account_with_existing_customer
    customer_id = generate_unique_id
    bank_account = check({ account_number: '1000000000', routing_number: '011000015' })
    response = @gateway.store(bank_account, @options.merge(customer: customer_id).merge(@check_required_options))

    assert response
    assert_success response

    bank_account = check({ account_number: '1000000001', routing_number: '011000015' })
    response = @gateway.store(bank_account, @options.merge(customer: customer_id).merge(@check_required_options))

    assert response
    assert_success response

    customer = @braintree_backend.customer.find(customer_id)
    bank_accounts = customer.us_bank_accounts

    assert_equal 2, bank_accounts.size
    assert bank_accounts.first.verified
    assert bank_accounts.last.verified
  end

  def test_successful_store_bank_account_with_customer_id_not_in_merchant_account
    customer_id = generate_unique_id
    bank_account = check({ account_number: '1000000000', routing_number: '011000015' })
    response = @gateway.store(bank_account, @options.merge(customer: customer_id).merge(@check_required_options))

    assert response
    assert_success response
    assert response.params['bank_account_token']
    assert response.params['verified']
    assert_equal response.params['customer_vault_id'], customer_id

    customer = @braintree_backend.customer.find(customer_id)
    bank_accounts = customer.us_bank_accounts
    created_bank_account = bank_accounts.first

    assert created_bank_account.verified
    assert_equal 1, bank_accounts.size
    assert_equal bank_account.routing_number, created_bank_account.routing_number
    assert_equal bank_account.account_number[-4..-1], created_bank_account.last_4
    assert_equal customer_id, customer.id
    assert_equal 'checking', created_bank_account.account_type
    assert_equal 'Jim', customer.first_name
    assert_equal 'Smith', customer.last_name
  end

  def test_successful_store_business_savings_bank_account
    customer_id = generate_unique_id
    bank_account = check({ account_type: 'savings', account_holder_type: 'business', account_number: '1000000000', routing_number: '011000015' })
    response = @gateway.store(bank_account, @options.merge(customer: customer_id).merge(@check_required_options))

    assert response
    assert_success response

    customer = @braintree_backend.customer.find(customer_id)
    bank_accounts = customer.us_bank_accounts
    created_bank_account = bank_accounts.first
    assert created_bank_account.verified
    assert_equal 1, bank_accounts.size
    assert_equal 'savings', bank_account.account_type
    assert_equal 'business', (created_bank_account.instance_eval { @ownership_type })
  end

  def test_unsuccessful_store_an_unverified_bank_account
    customer_id = generate_unique_id
    bank_account = check({ account_number: '1000000004', routing_number: '011000015' })
    options = @options.merge(customer: customer_id).merge(@check_required_options)
    response = @gateway.store(bank_account, options)

    assert response
    assert_failure response
    assert_equal 'verification_status: [processor_declined], processor_response: [2046-Declined]', response.message

    customer = @braintree_backend.customer.find(customer_id)
    bank_accounts = customer.us_bank_accounts
    created_bank_account = bank_accounts.first

    refute created_bank_account.verified
    assert_equal 1, bank_accounts.size
  end

  def test_sucessful_purchase_using_a_bank_account_token
    bank_account = check({ account_number: '1000000000', routing_number: '011000015' })
    response = @gateway.store(bank_account, @options.merge(@check_required_options))

    assert response
    assert_success response
    payment_method_token = response.params['bank_account_token']
    sleep 2

    assert response = @gateway.purchase(@amount, payment_method_token, @options.merge(payment_method_token: true))
    assert_success response
    assert_equal '4002 Settlement Pending', response.message
  end

  def test_successful_purchase_with_the_same_bank_account_several_times
    bank_account = check({ account_number: '1000000000', routing_number: '011000015' })
    response = @gateway.store(bank_account, @options.merge(@check_required_options))

    assert response
    assert_success response

    payment_method_token = response.params['bank_account_token']
    sleep 2

    # Purchase # 1
    assert response = @gateway.purchase(@amount, payment_method_token, @options.merge(payment_method_token: true))
    assert_success response
    assert_equal '4002 Settlement Pending', response.message

    # Purchase # 2
    assert response = @gateway.purchase(120, payment_method_token, @options.merge(payment_method_token: true))
    assert_success response
    assert_equal '4002 Settlement Pending', response.message
  end

  def test_successful_purchase_with_processor_authorization_code
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_not_nil response.params['braintree_transaction']['processor_authorization_code']
  end

  def test_successful_purchase_and_return_paypal_details_object
    @non_payal_link_gateway = BraintreeGateway.new(fixtures(:braintree_blue_non_linked_paypal))
    assert response = @non_payal_link_gateway.purchase(400000, 'fake-paypal-one-time-nonce', @options.merge(payment_method_nonce: 'fake-paypal-one-time-nonce'))
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'paypal_payer_id', response.params['braintree_transaction']['paypal_details']['payer_id']
    assert_equal 'payer@example.com', response.params['braintree_transaction']['paypal_details']['payer_email']
  end

  def test_successful_credit_card_purchase_with_prepaid_debit_issuing_bank
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'credit_card', response.params['braintree_transaction']['payment_instrument_type']
    assert_equal 'Unknown', response.params['braintree_transaction']['credit_card_details']['prepaid']
    assert_equal 'Unknown', response.params['braintree_transaction']['credit_card_details']['debit']
    assert_equal 'Unknown', response.params['braintree_transaction']['credit_card_details']['issuing_bank']
  end

  def test_unsuccessful_credit_card_purchase_and_return_payment_details
    assert response = @gateway.purchase(204700, @credit_card)
    assert_failure response
    assert_equal('2047 : Call Issuer. Pick Up Card.', response.params['braintree_transaction']['additional_processor_response'])
    assert_equal 'credit_card', response.params['braintree_transaction']['payment_instrument_type']
    assert_equal 'Unknown', response.params['braintree_transaction']['credit_card_details']['prepaid']
    assert_equal 'Unknown', response.params['braintree_transaction']['credit_card_details']['debit']
    assert_equal 'M', response.params.dig('braintree_transaction', 'cvv_response_code')
    assert_equal 'I', response.params.dig('braintree_transaction', 'avs_response_code')
    assert_equal 'Call Issuer. Pick Up Card.', response.params.dig('braintree_transaction', 'gateway_message')
    assert_equal 'Unknown', response.params.dig('braintree_transaction', 'credit_card_details', 'country_of_issuance')
    assert_equal 'Unknown', response.params['braintree_transaction']['credit_card_details']['issuing_bank']
  end

  def test_successful_network_token_purchase_with_prepaid_debit_issuing_bank
    assert response = @gateway.purchase(@amount, @nt_credit_card)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'network_token', response.params['braintree_transaction']['payment_instrument_type']
    assert_equal 'Unknown', response.params['braintree_transaction']['network_token_details']['prepaid']
    assert_equal 'Unknown', response.params['braintree_transaction']['network_token_details']['debit']
    assert_equal 'Unknown', response.params['braintree_transaction']['network_token_details']['issuing_bank']
  end

  def test_unsuccessful_network_token_purchase_and_return_payment_details
    assert response = @gateway.purchase(204700, @nt_credit_card)
    assert_failure response
    assert_equal('2047 : Call Issuer. Pick Up Card.', response.params['braintree_transaction']['additional_processor_response'])
    assert_equal 'network_token', response.params['braintree_transaction']['payment_instrument_type']
    assert_equal 'Unknown', response.params['braintree_transaction']['network_token_details']['prepaid']
    assert_equal 'Unknown', response.params['braintree_transaction']['network_token_details']['debit']
    assert_equal 'Unknown', response.params['braintree_transaction']['network_token_details']['issuing_bank']
  end

  def test_successful_google_pay_purchase_with_prepaid_debit
    credit_card = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '01',
      year: '2024',
      source: :google_pay,
      transaction_id: '123456789',
      eci: '05'
    )

    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'android_pay_card', response.params['braintree_transaction']['payment_instrument_type']
    assert_equal 'Unknown', response.params['braintree_transaction']['google_pay_details']['prepaid']
    assert_equal 'Unknown', response.params['braintree_transaction']['google_pay_details']['debit']
  end

  def test_unsuccessful_google_pay_purchase_and_return_payment_details
    credit_card = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '01',
      year: '2024',
      source: :google_pay,
      transaction_id: '123456789',
      eci: '05'
    )
    assert response = @gateway.purchase(204700, credit_card, @options)
    assert_failure response
    assert_equal('2047 : Call Issuer. Pick Up Card.', response.params['braintree_transaction']['additional_processor_response'])
    assert_equal 'android_pay_card', response.params['braintree_transaction']['payment_instrument_type']
    assert_equal 'Unknown', response.params['braintree_transaction']['google_pay_details']['prepaid']
    assert_equal 'Unknown', response.params['braintree_transaction']['google_pay_details']['debit']
  end

  def test_successful_apple_pay_purchase_with_prepaid_debit_issuing_bank
    credit_card = network_tokenization_credit_card(
      '4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'apple_pay_card', response.params['braintree_transaction']['payment_instrument_type']
    assert_equal 'Unknown', response.params['braintree_transaction']['apple_pay_details']['prepaid']
    assert_equal 'Unknown', response.params['braintree_transaction']['apple_pay_details']['debit']
    assert_equal 'Unknown', response.params['braintree_transaction']['apple_pay_details']['issuing_bank']
  end

  def test_unsuccessful_apple_pay_purchase_and_return_payment_details
    credit_card = network_tokenization_credit_card(
      '4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    assert response = @gateway.purchase(204700, credit_card, @options)
    assert_failure response
    assert_equal('2047 : Call Issuer. Pick Up Card.', response.params['braintree_transaction']['additional_processor_response'])
    assert_equal 'apple_pay_card', response.params['braintree_transaction']['payment_instrument_type']
    assert_equal 'Unknown', response.params['braintree_transaction']['apple_pay_details']['prepaid']
    assert_equal 'Unknown', response.params['braintree_transaction']['apple_pay_details']['debit']
    assert_equal 'Unknown', response.params['braintree_transaction']['apple_pay_details']['issuing_bank']
  end

  def test_successful_purchase_with_global_id
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_not_nil response.params['braintree_transaction']['payment_receipt']['global_id']
  end

  def test_unsucessful_purchase_using_a_bank_account_token_not_verified
    bank_account = check({ account_number: '1000000002', routing_number: '011000015' })
    response = @gateway.store(bank_account, @options.merge(@check_required_options))

    assert response
    assert_failure response

    payment_method_token = response.params['bank_account_token']
    assert response = @gateway.purchase(@amount, payment_method_token, @options.merge(payment_method_token: true))

    assert_failure response
    assert_equal 'US bank account payment method must be verified prior to transaction. (915172)', response.message
  end

  def test_unsuccessful_store_with_incomplete_bank_account
    bank_account = check({ account_type: 'blah',
                           account_holder_type: 'blah',
                           account_number: nil,
                           routing_number: nil,
                           name: nil })

    response = @gateway.store(bank_account, @options.merge(@check_required_options))

    assert response
    assert_failure response
    assert_equal 'cannot be empty', response.message[:account_number].first
    assert_equal 'cannot be empty', response.message[:routing_number].first
    assert_equal 'cannot be empty', response.message[:name].first
    assert_equal 'must be checking or savings', response.message[:account_type].first
    assert_equal 'must be personal or business', response.message[:account_holder_type].first
  end

  private

  def stored_credential_options(*args, id: nil)
    stored_credential(*args, id: id)
  end

  def assert_avs(address1, zip, expected_avs_code)
    response = @gateway.purchase(@amount, @credit_card, billing_address: { address1: address1, zip: zip })

    assert_success response
    assert_equal expected_avs_code, response.avs_result['code']
  end
end
