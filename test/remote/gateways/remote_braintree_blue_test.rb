require 'test_helper'

class RemoteBraintreeBlueTest < Test::Unit::TestCase
  def setup
    @gateway = BraintreeGateway.new(fixtures(:braintree_blue))
    @braintree_backend = @gateway.instance_eval{@braintree_gateway}

    @amount = 100
    @declined_amount = 2000_00
    @credit_card = credit_card('5105105105105100')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1',
      :billing_address => address(:country_name => "United States of America"),
      :description => 'Store Purchase'
    }
  end

  def test_credit_card_details_on_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal '5100', response.params["braintree_customer"]["credit_cards"].first["last_4"]
    assert_equal('510510******5100', response.params["braintree_customer"]["credit_cards"].first["masked_number"])
    assert_equal('5100', response.params["braintree_customer"]["credit_cards"].first["last_4"])
    assert_equal('MasterCard', response.params["braintree_customer"]["credit_cards"].first["card_type"])
    assert_equal('510510', response.params["braintree_customer"]["credit_cards"].first["bin"])
    assert_match %r{^\d+$}, response.params["customer_vault_id"]
    assert_equal response.params["customer_vault_id"], response.authorization
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'authorized', response.params["braintree_transaction"]["status"]
  end

  def test_masked_card_number
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal('510510******5100', response.params["braintree_transaction"]["credit_card_details"]["masked_number"])
    assert_equal('5100', response.params["braintree_transaction"]["credit_card_details"]["last_4"])
    assert_equal('MasterCard', response.params["braintree_transaction"]["credit_card_details"]["card_type"])
    assert_equal('510510', response.params["braintree_transaction"]["credit_card_details"]["bin"])
  end

  def test_successful_authorize_with_order_id
    assert response = @gateway.authorize(@amount, @credit_card, :order_id => '123')
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal '123', response.params["braintree_transaction"]["order_id"]
  end

  def test_successful_purchase_using_vault_id
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    customer_vault_id = response.params["customer_vault_id"]
    assert_match(/\A\d+\z/, customer_vault_id)

    assert response = @gateway.purchase(@amount, customer_vault_id)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params["braintree_transaction"]["status"]
    assert_equal customer_vault_id, response.params["braintree_transaction"]["customer_details"]["id"]
  end

  def test_successful_purchase_using_vault_id_as_integer
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    customer_vault_id = response.params["customer_vault_id"]
    assert_match %r{\A\d+\z}, customer_vault_id

    assert response = @gateway.purchase(@amount, customer_vault_id.to_i)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params["braintree_transaction"]["status"]
    assert_equal customer_vault_id, response.params["braintree_transaction"]["customer_details"]["id"]
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "1000 Approved", response.message
  end

  def test_failed_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{number is not an accepted test number}, response.message
  end

  def test_successful_validate_on_store
    card = credit_card('4111111111111111', :verification_value => '101')
    assert response = @gateway.store(card, :verify_card => true)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_failed_validate_on_store
    card = credit_card('4000111111111115', :verification_value => '200')
    assert response = @gateway.store(card, :verify_card => true)
    assert_failure response
    assert_equal 'Processor declined: Do Not Honor (2000)', response.message
  end

  def test_successful_store_with_no_validate
    card = credit_card('4000111111111115', :verification_value => '200')
    assert response = @gateway.store(card, :verify_card => false)
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
      :address1 => "1 E Main St",
      :address2 => "Suite 403",
      :city => "Chicago",
      :state => "Illinois",
      :zip => "60622",
      :country_name => "United States of America"
    }
    credit_card = credit_card('5105105105105100')
    assert response = @gateway.store(credit_card, :billing_address => billing_address)
    assert_success response
    assert_equal 'OK', response.message

    vault_id = response.params['customer_vault_id']
    purchase_response = @gateway.purchase(@amount, vault_id)
    response_billing_details = {
      "country_name"=>"United States of America",
      "region"=>"Illinois",
      "company"=>nil,
      "postal_code"=>"60622",
      "extended_address"=>"Suite 403",
      "street_address"=>"1 E Main St",
      "locality"=>"Chicago"
    }
    assert_equal purchase_response.params['braintree_transaction']['billing_details'], response_billing_details
  end

  def test_successful_store_with_credit_card_token
    credit_card = credit_card('5105105105105100')
    credit_card_token = generate_unique_id
    assert response = @gateway.store(credit_card, credit_card_token: credit_card_token)
    assert_success response
    assert_equal 'OK', response.message
    assert_equal credit_card_token, response.params["braintree_customer"]["credit_cards"][0]["token"]
  end

  def test_successful_store_with_new_customer_id
    credit_card = credit_card('5105105105105100')
    customer_id = generate_unique_id
    assert response = @gateway.store(credit_card, customer: customer_id)
    assert_success response
    assert_equal 'OK', response.message
    assert_equal customer_id, response.authorization
    assert_equal customer_id, response.params["braintree_customer"]["id"]
  end

  def test_successful_store_with_existing_customer_id
    credit_card = credit_card('5105105105105100')
    customer_id = generate_unique_id
    assert response = @gateway.store(credit_card, customer: customer_id)
    assert_success response
    assert_equal 1, @braintree_backend.customer.find(customer_id).credit_cards.size

    assert response = @gateway.store(credit_card, customer: customer_id)
    assert_success response
    assert_equal 2, @braintree_backend.customer.find(customer_id).credit_cards.size
    assert_equal customer_id, response.params["customer_vault_id"]
    assert_equal customer_id, response.authorization
    assert_not_nil response.params["credit_card_token"]
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params["braintree_transaction"]["status"]
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::BraintreeBlueGateway.application_id = 'ABC123'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal 'submitted_for_settlement', response.params["braintree_transaction"]["status"]
  ensure
    ActiveMerchant::Billing::BraintreeBlueGateway.application_id = nil
  end

  def test_avs_match
    assert response = @gateway.purchase(@amount, @credit_card,
      @options.merge(
        :billing_address => {:address1 => "1 E Main St", :zip => "60622"}
      )
    )
    assert_success response
    assert_equal({'code' => nil, 'message' => nil, 'street_match' => 'M', 'postal_match' => 'M'}, response.avs_result)
  end

  def test_cvv_match
    assert response = @gateway.purchase(@amount, credit_card('5105105105105100', :verification_value => '400'))
    assert_success response
    assert_equal({'code' => 'M', 'message' => ''}, response.cvv_result)
  end

  def test_cvv_no_match
    assert response = @gateway.purchase(@amount, credit_card('5105105105105100', :verification_value => '200'))
    assert_success response
    assert_equal({'code' => 'N', 'message' => ''}, response.cvv_result)
  end

  def test_successful_purchase_with_email
    assert response = @gateway.purchase(@amount, @credit_card,
      :email => "customer@example.com"
    )
    assert_success response
    transaction = response.params["braintree_transaction"]
    assert_equal 'customer@example.com', transaction["customer_details"]["email"]
  end

  def test_purchase_with_store_using_random_customer_id
    assert response = @gateway.purchase(
      @amount, credit_card('5105105105105100'), @options.merge(:store => true)
    )
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_match(/\A\d+\z/, response.params["customer_vault_id"])
    assert_equal '510510', response.params["braintree_transaction"]["vault_customer"]["credit_cards"][0]["bin"]
    assert_equal '510510', @braintree_backend.customer.find(response.params["customer_vault_id"]).credit_cards[0].bin
  end

  def test_purchase_with_store_using_specified_customer_id
    customer_id = rand(1_000_000_000).to_s
    assert response = @gateway.purchase(
      @amount, credit_card('5105105105105100'), @options.merge(:store => customer_id)
    )
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal customer_id, response.params["customer_vault_id"]
    assert_equal '510510', response.params["braintree_transaction"]["vault_customer"]["credit_cards"][0]["bin"]
    assert_equal '510510', @braintree_backend.customer.find(response.params["customer_vault_id"]).credit_cards[0].bin
  end

  def test_purchase_using_specified_payment_method_token
    assert response = @gateway.store(
      credit_card('4111111111111111',
        :first_name => 'Old First', :last_name => 'Old Last',
        :month => 9, :year => 2012
      ),
      :email => "old@example.com"
    )
    payment_method_token = response.params["braintree_customer"]["credit_cards"][0]["token"]
    assert response = @gateway.purchase(
      @amount, payment_method_token, @options.merge(payment_method_token: true)
    )
    assert_success response
    assert_equal '1000 Approved', response.message
    assert_equal payment_method_token, response.params["braintree_transaction"]["credit_card_details"]["token"]
  end

  def test_successful_purchase_with_addresses
    billing_address = {
      :address1 => '1 E Main St',
      :address2 => 'Suite 101',
      :company => 'Widgets Co',
      :city => 'Chicago',
      :state => 'IL',
      :zip => '60622',
      :country_name => 'United States of America'
    }
    shipping_address = {
      :address1 => '1 W Main St',
      :address2 => 'Suite 102',
      :company => 'Widgets Company',
      :city => 'Bartlett',
      :state => 'Illinois',
      :zip => '60103',
      :country_name => 'Mexico'
    }
    assert response = @gateway.purchase(@amount, @credit_card,
      :billing_address => billing_address,
      :shipping_address => shipping_address
    )
    assert_success response
    transaction = response.params["braintree_transaction"]
    assert_equal '1 E Main St', transaction["billing_details"]["street_address"]
    assert_equal 'Suite 101', transaction["billing_details"]["extended_address"]
    assert_equal 'Widgets Co', transaction["billing_details"]["company"]
    assert_equal 'Chicago', transaction["billing_details"]["locality"]
    assert_equal 'IL', transaction["billing_details"]["region"]
    assert_equal '60622', transaction["billing_details"]["postal_code"]
    assert_equal 'United States of America', transaction["billing_details"]["country_name"]
    assert_equal '1 W Main St', transaction["shipping_details"]["street_address"]
    assert_equal 'Suite 102', transaction["shipping_details"]["extended_address"]
    assert_equal 'Widgets Company', transaction["shipping_details"]["company"]
    assert_equal 'Bartlett', transaction["shipping_details"]["locality"]
    assert_equal 'Illinois', transaction["shipping_details"]["region"]
    assert_equal '60103', transaction["shipping_details"]["postal_code"]
    assert_equal 'Mexico', transaction["shipping_details"]["country_name"]
  end

  def test_unsuccessful_purchase_declined
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal '2000 Do Not Honor', response.message
  end

  def test_unsuccessful_purchase_validation_error
    assert response = @gateway.purchase(@amount, credit_card('51051051051051000'))
    assert_failure response
    assert_match %r{Credit card number is invalid\. \(81715\)}, response.message
    assert_equal nil, response.params["braintree_transaction"]
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
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
    assert_equal 'voided', void.params["braintree_transaction"]["status"]
  end

  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'voided', void.params["braintree_transaction"]["status"]
  end

  def test_capture_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert void = @gateway.void(capture.authorization)
    assert_success void
    assert_equal 'voided', void.params["braintree_transaction"]["status"]
  end

  def test_failed_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal '1000 Approved', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'voided', void.params["braintree_transaction"]["status"]
    assert failed_void = @gateway.void(auth.authorization)
    assert_failure failed_void
    assert_equal 'Transaction can only be voided if status is authorized or submitted_for_settlement. (91504)', failed_void.message
    assert_equal nil, failed_void.params["braintree_transaction"]
  end

  def test_failed_capture_with_invalid_transaction_id
    assert response = @gateway.capture(@amount, 'invalidtransactionid')
    assert_failure response
    assert_equal 'Braintree::NotFoundError', response.message
  end

  def test_invalid_login
    gateway = BraintreeBlueGateway.new(:merchant_id => "invalid", :public_key => "invalid", :private_key => "invalid")
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Braintree::AuthenticationError', response.message
  end

  def test_successful_add_to_vault_with_store_method
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    assert_match(/\A\d+\z/, response.params["customer_vault_id"])
  end

  def test_failed_add_to_vault
    assert response = @gateway.store(credit_card('5105105105105101'))
    assert_failure response
    assert_equal 'Credit card number is invalid. (81715)', response.message
    assert_equal nil, response.params["braintree_customer"]
    assert_equal nil, response.params["customer_vault_id"]
  end

  def test_unstore_customer
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    assert customer_vault_id = response.params["customer_vault_id"]
    assert delete_response = @gateway.unstore(customer_vault_id)
    assert_success delete_response
  end

  def test_unstore_credit_card
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    assert credit_card_token = response.params["credit_card_token"]
    assert delete_response = @gateway.unstore(nil, credit_card_token: credit_card_token)
    assert_success delete_response
  end

  def test_unstore_with_delete_method
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'OK', response.message
    assert customer_vault_id = response.params["customer_vault_id"]
    assert delete_response = @gateway.delete(customer_vault_id)
    assert_success delete_response
  end

  def test_successful_update
    assert response = @gateway.store(
      credit_card('4111111111111111',
        :first_name => 'Old First', :last_name => 'Old Last',
        :month => 9, :year => 2012
      ),
      :email => "old@example.com"
    )
    assert_success response
    assert_equal 'OK', response.message
    customer_vault_id = response.params["customer_vault_id"]
    assert_match(/\A\d+\z/, customer_vault_id)
    assert_equal "old@example.com", response.params["braintree_customer"]["email"]
    assert_equal "Old First", response.params["braintree_customer"]["first_name"]
    assert_equal "Old Last", response.params["braintree_customer"]["last_name"]
    assert_equal "411111", response.params["braintree_customer"]["credit_cards"][0]["bin"]
    assert_equal "09/2012", response.params["braintree_customer"]["credit_cards"][0]["expiration_date"]
    assert_not_nil response.params["braintree_customer"]["credit_cards"][0]["token"]
    assert_equal customer_vault_id, response.params["braintree_customer"]["id"]

    assert response = @gateway.update(
      customer_vault_id,
      credit_card('5105105105105100',
        :first_name => 'New First', :last_name => 'New Last',
        :month => 10, :year => 2014
      ),
      :email => "new@example.com"
    )
    assert_success response
    assert_equal "new@example.com", response.params["braintree_customer"]["email"]
    assert_equal "New First", response.params["braintree_customer"]["first_name"]
    assert_equal "New Last", response.params["braintree_customer"]["last_name"]
    assert_equal "510510", response.params["braintree_customer"]["credit_cards"][0]["bin"]
    assert_equal "10/2014", response.params["braintree_customer"]["credit_cards"][0]["expiration_date"]
    assert_not_nil response.params["braintree_customer"]["credit_cards"][0]["token"]
    assert_equal customer_vault_id, response.params["braintree_customer"]["id"]
  end

  def test_failed_customer_update
    assert response = @gateway.store(credit_card('4111111111111111'), :email => "email@example.com")
    assert_success response
    assert_equal 'OK', response.message
    assert customer_vault_id = response.params["customer_vault_id"]

    assert response = @gateway.update(
      customer_vault_id,
      credit_card('51051051051051001')
    )
    assert_failure response
    assert_equal 'Credit card number is invalid. (81715)', response.message
    assert_equal nil, response.params["braintree_customer"]
    assert_equal nil, response.params["customer_vault_id"]
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
    assert customer_vault_id = response.params["customer_vault_id"]

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
    assert customer_vault_id = response.params["customer_vault_id"]

    assert response = @gateway.update(
      customer_vault_id,
      credit_card('4000111111111115'),
      {:verify_card => true}
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
    assert_success response, "You must get credits enabled in your Sandbox account for this to pass."
    assert_equal '1002 Processed', response.message
    assert_equal 'submitted_for_settlement', response.params["braintree_transaction"]["status"]
  end

  def test_failed_credit
    assert response = @gateway.credit(@amount, credit_card('5105105105105101'), @options)
    assert_failure response
    assert_equal 'Credit card number is invalid. (81715)', response.message, "You must get credits enabled in your Sandbox account for this to pass"
  end

  def test_successful_credit_with_merchant_account_id
    assert response = @gateway.credit(@amount, @credit_card, :merchant_account_id => fixtures(:braintree_blue)[:merchant_account_id])
    assert_success response, "You must specify a valid :merchant_account_id key in your fixtures.yml AND get credits enabled in your Sandbox account for this to pass."
    assert_equal '1002 Processed', response.message
    assert_equal 'submitted_for_settlement', response.params["braintree_transaction"]["status"]
  end

  def test_successful_authorize_with_merchant_account_id
    assert response = @gateway.authorize(@amount, @credit_card, :merchant_account_id => fixtures(:braintree_blue)[:merchant_account_id])
    assert_success response, "You must specify a valid :merchant_account_id key in your fixtures.yml for this to pass."
    assert_equal '1000 Approved', response.message
    assert_equal fixtures(:braintree_blue)[:merchant_account_id], response.params["braintree_transaction"]["merchant_account_id"]
  end

  def test_successful_validate_on_store_with_verification_merchant_account
    card = credit_card('4111111111111111', :verification_value => '101')
    assert response = @gateway.store(card, :verify_card => true, :verification_merchant_account_id => fixtures(:braintree_blue)[:merchant_account_id])
    assert_success response, "You must specify a valid :merchant_account_id key in your fixtures.yml for this to pass."
    assert_equal 'OK', response.message
  end
end
