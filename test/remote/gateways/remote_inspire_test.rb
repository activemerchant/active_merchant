require 'test_helper'

class RemoteBraintreeTest < Test::Unit::TestCase
  def setup
    @gateway = InspireGateway.new(fixtures(:inspire))

    @amount = rand(10000) + 1001
    @credit_card = credit_card('4111111111111111', :brand => 'visa')
    @declined_amount = rand(99)
    @options = {  :order_id => generate_unique_id,
                  :billing_address => address
               }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_successful_purchase_with_echeck
    check = ActiveMerchant::Billing::Check.new(
              :name => 'Fredd Bloggs',
              :routing_number => '111000025', # Valid ABA # - Bank of America, TX
              :account_number => '999999999999',
              :account_holder_type => 'personal',
              :account_type => 'checking'
            )
    response = @gateway.purchase(@amount, check, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_successful_add_to_vault
    @options[:store] = true
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_successful_add_to_vault_with_store_method
    response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_successful_add_to_vault_and_use
    @options[:store] = true
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_not_nil customer_id = response.params["customer_vault_id"]

    second_response = @gateway.purchase(@amount*2, customer_id, @options)
    assert_equal 'This transaction has been approved', second_response.message
    assert_success second_response
  end

  def test_add_to_vault_with_custom_vault_id
    @options[:store] = rand(100000)+10001
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal @options[:store], response.params["customer_vault_id"].to_i
  end

  def test_add_to_vault_with_custom_vault_id_with_store_method
    @options[:billing_id] = rand(100000)+10001
    response = @gateway.store(@credit_card, @options.dup)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal @options[:billing_id], response.params["customer_vault_id"].to_i
  end

  def test_update_vault
    test_add_to_vault_with_custom_vault_id
    @credit_card = credit_card('4111111111111111', :month => 10)
    response = @gateway.update(@options[:store], @credit_card)
    assert_success response
    assert_equal 'Customer Update Successful', response.message
  end

  def test_delete_from_vault
    test_add_to_vault_with_custom_vault_id
    response = @gateway.delete(@options[:store])
    assert_success response
    assert_equal 'Customer Deleted', response.message
  end

  def test_delete_from_vault_with_unstore_method
    test_add_to_vault_with_custom_vault_id
    response = @gateway.unstore(@options[:store])
    assert_success response
    assert_equal 'Customer Deleted', response.message
  end

  def test_declined_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'This transaction has been declined', response.message
  end

  def test_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message
    assert auth.authorization

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_authorize_and_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message
    assert auth.authorization

    void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transaction Void Successful', void.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_match %r{Invalid Transaction ID \/ Object ID specified:}, response.message
  end

  def test_refund
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    response = @gateway.refund(nil, response.authorization)
    assert_success response
  end

  def test_partial_refund
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    response = @gateway.refund(@amount-500, response.authorization)
    assert_success response
  end

  def test_failed_refund
    response = @gateway.refund(nil, "bogus")
    assert_failure response
  end

  def test_invalid_login
    gateway = InspireGateway.new(
                :login => '',
                :password => ''
              )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Invalid Username', response.message
    assert_failure response
  end
end


