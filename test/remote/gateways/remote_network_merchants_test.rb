require 'test_helper'

class RemoteNetworkMerchantsTest < Test::Unit::TestCase
  def setup
    @gateway = NetworkMerchantsGateway.new(fixtures(:network_merchants))

    @amount = 100
    @decline_amount = 1
    @credit_card = credit_card('4111111111111111')
    @check = check

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_check_purchase
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@decline_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_purchase_and_store
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:store => true))
    assert_success response
    assert_equal response.params['transactionid'], response.authorization
    assert response.params['customer_vault_id']
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert response.message.include?('Invalid Transaction ID / Object ID specified')
  end

  def test_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert response = @gateway.void(purchase.authorization)
    assert_success response
    assert_equal "Transaction Void Successful", response.message
  end

  def test_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_equal "SUCCESS", response.message
    assert response.authorization
  end

  def test_store
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert store.params['customer_vault_id']
    assert_equal store.params['customer_vault_id'], store.authorization
  end

  def test_store_check
    assert store = @gateway.store(@check, @options)
    assert_success store
    assert store.params['customer_vault_id']
    assert_equal store.params['customer_vault_id'], store.authorization
  end

  def test_store_failure
    @credit_card.number = "123"
    assert store = @gateway.store(@creditcard, @options)
    assert_failure store
    assert store.message.include?('Billing Information missing')
    assert_equal '', store.params['customer_vault_id']
    assert_nil store.authorization
  end

  def test_unstore
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert store.params['customer_vault_id']

    assert unstore = @gateway.unstore(store.params['customer_vault_id'])
    assert_success unstore
    assert_equal "Customer Deleted", unstore.message
  end

  def test_purchase_on_stored_card
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert store.params['customer_vault_id']

    assert purchase = @gateway.purchase(@amount, store.params['customer_vault_id'], @options)
    assert_success purchase
    assert_equal "SUCCESS", purchase.message
  end

  def test_invalid_login
    gateway = NetworkMerchantsGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Username', response.message
  end

  def test_successful_purchase_without_state
    @options[:billing_address] = {
      :name     => 'Jim Smith',
      :address1 => 'Gullhauggrenda 30',
      :address2 => 'Apt 1',
      :company  => 'Widgets Inc',
      :city     => 'Baerums Verk',
      :state    => nil,
      :zip      => '1354',
      :country  => 'NO',
      :phone    => '(555)555-5555',
      :fax      => '(555)555-6666'
    }

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end
end
