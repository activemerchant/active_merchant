require 'test_helper'

class RemoteForteTest < Test::Unit::TestCase
  def setup
    @gateway = ForteGateway.new(fixtures(:forte))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('1111111111111111')

    @check = check
    @bad_check = check(
      name: 'Jim Smith',
      bank_name: 'Bank of Elbonia',
      routing_number: '1234567890',
      account_number: '0987654321',
      account_holder_type: '',
      account_type: 'checking',
      number: '0'
    )

    @options = {
      billing_address: address,
      description: 'Store Purchase',
      order_id: '1'
    }
  end

  def test_invalid_login
    gateway = ForteGateway.new(api_key: 'InvalidKey', secret: 'InvalidSecret', location_id: '11', account_id: '323')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'combination not found.', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'TEST APPROVAL', response.message
  end

  def test_successful_purchase_with_echeck
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
    assert_equal 'PPD', response.params['echeck']['sec_code']
  end

  def test_successful_purchase_with_echeck_with_more_options
    options = {
      sec_code: 'WEB'
    }

    response = @gateway.purchase(@amount, @check, options)
    assert_success response
    assert_equal 'APPROVED', response.message
    assert_equal 'WEB', response.params['echeck']['sec_code']
  end

  def test_failed_purchase_with_echeck
    response = @gateway.purchase(@amount, @bad_check, @options)
    assert_failure response
    assert_equal 'INVALID TRN', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      address: address
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal '1', response.params['order_number']
    assert_equal 'TEST APPROVAL', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'INVALID CREDIT CARD NUMBER', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    wait_for_authorization_to_clear

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'APPROVED', capture.message
  end

  def test_successful_authorize_capture_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    wait_for_authorization_to_clear

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_match auth.authorization.split('#')[0], capture.authorization
    assert_match auth.authorization.split('#')[1], capture.authorization
    assert_equal 'APPROVED', capture.message

    void = @gateway.void(capture.authorization)
    assert_success void
  end

  def test_failed_authorize
    @amount = 1985
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'INVALID CREDIT CARD NUMBER', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    wait_for_authorization_to_clear

    assert capture = @gateway.capture(@amount - 1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_match 'field transaction_id', response.message
  end

  def test_successful_credit
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.credit(@amount, @credit_card, @options)
    assert_success refund
    assert_equal 'TEST APPROVAL', refund.message
  end

  def test_partial_credit
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.credit(@amount - 1, @credit_card, @options)
    assert_success refund
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    wait_for_authorization_to_clear

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'APPROVED', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_match 'field transaction_id', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    wait_for_authorization_to_clear

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal 'TEST APPROVAL', refund.message
  end

  def test_successful_refund_with_bank_account
    purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    wait_for_authorization_to_clear

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal 'APPROVED', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_match 'field authorization_code', response.message
    assert_match 'field original_transaction_id', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{TEST APPROVAL}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{INVALID CREDIT CARD NUMBER}, response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'Create Successful.', response.message
    assert response.params['customer_token'].present?
    @data_key = response.params['customer_token']
  end

  def test_successful_store_and_purchase_with_customer_token
    assert response = @gateway.store(@credit_card, billing_address: address)
    assert_success response
    assert_equal 'Create Successful.', response.message

    vault_id = response.params['customer_token']
    purchase_response = @gateway.purchase(@amount, vault_id)
    assert purchase_response.params['transaction_id'].start_with?('trn_')
  end

  def test_successful_store_and_purchase_with_customer_and_paymethod_tokens
    assert response = @gateway.store(@credit_card, billing_address: address)
    assert_success response
    assert_equal 'Create Successful.', response.message

    vault_id = response.params['customer_token'] + '|' + response.params['default_paymethod_token']
    purchase_response = @gateway.purchase(@amount, vault_id)
    assert_success purchase_response
    assert purchase_response.params['transaction_id'].start_with?('trn_')
  end

  def test_successful_store_of_bank_account
    response = @gateway.store(@check)
    assert_success response
    assert_equal 'Create Successful.', response.message
    assert response.params['customer_token'].present?
    @data_key = response.params['customer_token']
  end

  def test_successful_store_of_bank_account_and_purchase_with_customer_token
    assert response = @gateway.store(@check, billing_address: address)
    assert_success response
    assert_equal 'Create Successful.', response.message

    vault_id = response.params['customer_token']
    options = { sec_code: 'WEB' }
    purchase_response = @gateway.purchase(@amount, vault_id, options)
    assert_success purchase_response
    assert purchase_response.params['transaction_id'].start_with?('trn_')
  end

  def test_successful_store_of_bank_account_and_purchase_with_customer_and_paymethod_tokens
    assert response = @gateway.store(@check, billing_address: address)
    assert_success response
    assert_equal 'Create Successful.', response.message

    vault_id = response.params['customer_token'] + '|' + response.params['default_paymethod_token']
    options = { sec_code: 'WEB' }
    purchase_response = @gateway.purchase(@amount, vault_id, options)
    assert_success purchase_response
    assert purchase_response.params['transaction_id'].start_with?('trn_')
  end

  def test_successful_store_and_unstore_of_customer
    assert store_response = @gateway.store(@credit_card, billing_address: address)
    assert_success store_response
    assert_equal 'Create Successful.', store_response.message

    vault_id = store_response.params['customer_token']
    assert unstore_response = @gateway.unstore(vault_id)
    assert_success unstore_response
    assert_equal 'Delete Successful.', unstore_response.message
    assert unstore_response.params['customer_token'].present?
    assert unstore_response.params['paymethod_token'].blank?
  end

  def test_successful_store_of_customer_and_unstore_of_only_paymethod
    assert store_response = @gateway.store(@credit_card, billing_address: address)
    assert_success store_response
    assert_equal 'Create Successful.', store_response.message

    vault_id = store_response.params['customer_token'] + '|' + store_response.params['default_paymethod_token']

    assert unstore_response = @gateway.unstore(vault_id)
    assert_success unstore_response
    assert_equal 'Delete Successful.', unstore_response.message
    assert unstore_response.params['customer_token'].blank?
    assert unstore_response.params['paymethod_token'].present?
  end

  def test_successful_store_for_new_customer
    response = @gateway.store(@credit_card)

    assert_success response
    assert_equal 'Create Successful.', response.message
  end

  def test_failed_store_for_new_customer
    response = @gateway.store(@declined_card)

    assert_failure response
    assert_equal "Error[1]: Payment Method's credit card number is invalid. Error[2]: Payment Method's credit card type is invalid for the credit card number given.", response.message
  end

  def test_successful_store_for_existing_customer_without_billing_address
    store_response1 = @gateway.store(@credit_card)
    credit_card = credit_card('4111111111111111')
    options = { customer_token: store_response1.params['customer_token'] }

    store_response2 = @gateway.store(credit_card, options)
    responses = store_response2.responses

    assert_success store_response2
    assert_instance_of MultiResponse, store_response2
    assert_equal 2, responses.size

    create_paymethod_response = responses[0]
    assert_success create_paymethod_response

    update_customer_response = responses[1]
    assert_success update_customer_response
    assert_equal 'Update Successful.', update_customer_response.message
  end

  def test_successful_store_for_existing_customer_with_billing_address
    store_response1 = @gateway.store(@credit_card)
    credit_card = credit_card('4111111111111111')
    options = {
      customer_token: store_response1.params['customer_token'],
      billing_address: {
        address1: '2981 Aglae Mall',
        address2: 'Suite 949',
        city: 'North Irmachester',
        state: 'NE',
        country: 'US',
        zip: '86498'
      }
    }

    store_response2 = @gateway.store(credit_card, options)
    responses = store_response2.responses

    assert_success store_response2
    assert_instance_of MultiResponse, store_response2
    assert_equal 4, responses.size

    create_paymethod_response = responses[0]
    assert_success create_paymethod_response

    create_address_response = responses[1]
    assert_success create_address_response
    address_params = create_address_response.params['physical_address']
    assert_equal '2981 Aglae Mall', address_params['street_line1']
    assert_equal 'Suite 949', address_params['street_line2']
    assert_equal 'North Irmachester', address_params['locality']
    assert_equal 'NE', address_params['region']
    assert_equal '86498', address_params['postal_code']
    assert_equal 'US', address_params['country']

    add_address_to_paymethod_response = responses[2]
    assert_success add_address_to_paymethod_response

    update_customer_response = responses[3]
    assert_success update_customer_response
  end

  def test_successful_store_for_existing_customer_with_new_customer_name
    store_response1 = @gateway.store(@credit_card)
    credit_card = credit_card('4111111111111111')
    options = {
      customer_token: store_response1.params['customer_token'],
      customer: { first_name: 'Peter', last_name: 'Jones' }
    }

    store_response2 = @gateway.store(credit_card, options)
    responses = store_response2.responses

    assert_success store_response2
    assert_instance_of MultiResponse, store_response2
    assert_equal 2, responses.size

    create_paymethod_response = responses[0]
    assert_success create_paymethod_response

    update_customer_response = responses[1]
    assert_success update_customer_response
    assert_equal 'Peter', update_customer_response.params["first_name"]
    assert_equal 'Jones', update_customer_response.params["last_name"]
  end

  def test_failed_store_for_existing_customer
    response = @gateway.store(@credit_card)
    credit_card = @declined_card
    options = { customer_token: response.params['customer_token'] }

    final_response = @gateway.store(credit_card, options)

    assert_failure final_response
    assert_equal "Error[1]: Payment Method's credit card number is invalid. Error[2]: Payment Method's credit card type is invalid for the credit card number given.", final_response.message
  end

  def test_successful_update
    store_response = @gateway.store(@credit_card, @options)
    credit_card = credit_card(nil, { first_name: 'Jane', last_name: 'Smith' })

    options = {
      customer_token: store_response.params['customer_token'],
      paymethod_token: store_response.params['paymethod']['paymethod_token']
    }

    response = @gateway.update(credit_card, options)
    assert_success response
    assert response.params['customer_token'].present?
    assert response.params['default_paymethod_token'].present?
  end

  def test_successful_bank_account_update
    store_response = @gateway.store(@check)
    options = {
      customer_token: store_response.params['customer_token'],
      paymethod_token: store_response.params['paymethod']['paymethod_token']
    }
    check = ActiveMerchant::Billing::Check.new(first_name: 'Jane', last_name: 'Smith')

    response = @gateway.update(check, options)
    assert_success response
    assert response.params['customer_token'].present?
    assert response.params['default_paymethod_token'].present?
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = 789
    credit_card_transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    credit_card_transcript = @gateway.scrub(credit_card_transcript)
    assert_scrubbed(@credit_card.number, credit_card_transcript)
    assert_scrubbed(@credit_card.verification_value, credit_card_transcript)

    check_transcript = capture_transcript(@gateway) do
      @gateway.store(@check)
    end
    check_transcript = @gateway.scrub(check_transcript)
    assert_scrubbed(@check.account_number, check_transcript)
    assert_scrubbed(@check.routing_number, check_transcript)
  end

  private

  def wait_for_authorization_to_clear
    sleep(10)
  end
end
