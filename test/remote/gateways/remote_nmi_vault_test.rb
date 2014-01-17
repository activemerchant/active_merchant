require 'test_helper'

class RemoteNmiVaultTest < Test::Unit::TestCase
  def setup
    @gateway = NmiVaultGateway.new(fixtures(:nmi_vault))

    @amount = 100
    @decline_amount = 1
    @too_large_amount = 101
    @credit_card = credit_card('4111111111111111', :month => '10',
      :year => '2025', :verification_value => '999')

    @options = {
      :email       => 'john@example.com',
      :order_id    => 1,
      :description => 'Test Transaction',
      :currency    => 'USD',
      :customer    => 12345678,
      :address     => {
        :company  => 'Test Company',
        :address1 => '888',
        :address2 => 'Suite 100',
        :city     => 'New York',
        :state    => 'NY',
        :country  => 'US',
        :zip      => '77777',
        :phone    => '1-800-555-1212'
      }
    }
  end

  def customer
    @gateway.store(@credit_card, @options).authorization
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Customer Added', response.message
  end

  def test_unsuccessful_store
    cc = credit_card('', :month => '10', :year => '2025',
      :verification_value => '999')
    assert response = @gateway.store(cc, @options)
    assert_failure response
    assert_equal 'Required Field cc_number is Missing or Empty', response.message
  end

  def test_successful_update
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal 'Customer Added', store.message
    options = @options.clone
    options[:email] = 'jonathan@example.com'
    assert update = @gateway.update(store.authorization, @credit_card, options)
    assert_success update
    assert_equal 'Customer Update Successful', update.message
  end

  def test_unsuccessful_update
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal 'Customer Added', store.message
    cc = credit_card('', :month => '10', :year => '2025',
      :verification_value => '999')
    assert response = @gateway.update(store.authorization, cc, @options)
    assert_failure response
    assert_equal 'Required Field cc_number is Missing or Empty', response.message
  end

  def test_successful_unstore
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal 'Customer Added', store.message
    assert unstore = @gateway.unstore(store.authorization, @options)
    assert_success unstore
    assert_equal 'Customer Deleted', unstore.message
  end

  def test_unsuccessful_unstore
    assert unstore = @gateway.unstore('', @options)
    assert_failure unstore
    assert_equal 'Invalid Customer Vault Id', unstore.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, customer, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@decline_amount, customer, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, customer, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'SUCCESS', capture.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@decline_amount, customer, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_failed_authorize_bad_customer
    assert response = @gateway.authorize(@amount, '834732897329012172389321', @options)
    assert_failure response
    assert_equal 'Invalid Customer Vault ID specified', response.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '123')
    assert_failure response
    assert_equal 'Transaction not found', response.message
  end

  def test_failed_too_large_capture
    assert auth = @gateway.authorize(@amount, customer, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization
    assert response = @gateway.capture(@too_large_amount, auth.authorization)
    assert_failure response
    assert_equal 'The specified amount of 1.01 exceeds the authorization amount of 1.00', response.message
  end

  def test_successful_void
    assert purchase = @gateway.purchase(@amount, customer, @options)
    assert_success purchase
    assert_equal 'SUCCESS', purchase.message
    assert void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal 'Transaction Void Successful', void.message
  end

  def test_unsuccessful_void
    assert void = @gateway.void('123', @options)
    assert_failure void
    assert_equal 'Transaction not found', void.message
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, customer, @options)
    assert_success purchase
    assert_equal 'SUCCESS', purchase.message
    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_unsuccessful_refund
    assert refund = @gateway.refund(@amount, '123', @options)
    assert_failure refund
    assert_equal 'Transaction not found', refund.message
  end

  def test_unsuccessful_refund_too_large
    assert purchase = @gateway.purchase(@amount, customer, @options)
    assert_success purchase
    assert_equal 'SUCCESS', purchase.message
    assert refund = @gateway.refund(101, purchase.authorization, @options)
    assert_failure refund
    assert_equal 'Refund amount may not exceed the transaction balance', refund.message
  end

  def test_invalid_login
    gateway = NmiVaultGateway.new(
                :login => 'demo123',
                :password => 'password123'
              )
    # Force the gateway to use the credential we passed
    ActiveMerchant::Billing::Base.mode = :production
    assert response = gateway.purchase(@amount, customer, @options)
    assert_failure response
    assert_equal 'Authentication Failed', response.message
  ensure
    ActiveMerchant::Billing::Base.mode = :test
  end
end
