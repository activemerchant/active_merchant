require 'test_helper'

class RemoteEwayRapid31Test < Test::Unit::TestCase
  def setup
    @gateway = EwayRapid31Gateway.new(fixtures(:eway_rapid))

    @amount = 100
    @credit_card = credit_card('4444333322221111')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :email => 'jim.smith@example.com',
      :transaction_type => 'MOTO',
      :ip => '127.0.0.1'
    }

    # ActiveMerchant::Billing::Gateway.wiredump_device = Logger.new(STDOUT)
  end

  def test_invalid_login
    gateway = EwayRapid31Gateway.new(
                :login => '',
                :password => ''
              )

    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Unauthorized', response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount + 1, @credit_card, @options)
    assert_failure response
    assert_equal 'Refer to Issuer', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_unsuccessful_store
    credit_card = credit_card('4444333322221111', :month => 13)

    assert response = @gateway.store(credit_card, @options)
    assert_failure response
    assert_equal 'Invalid EWAY_CARDEXPIRYMONTH', response.message
  end

  def test_successful_purchase_with_token
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
    assert 'Transaction Approved', response.message
  end

  def test_unsuccessful_purchase_with_token
    assert response = @gateway.purchase(@amount, 0, @options)
    assert_failure response
    assert 'V6040,V6021,V6022,V6101,V6102', response.message
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert response = @gateway.refund(@amount, purchase.params['TransactionID'], @options)
    assert_success response
  end

  def test_unsuccessful_refund
    assert response = @gateway.refund(@amount, 0, @options)
    assert_failure response
    assert 'S5010', response.message
  end

  def test_successful_update
    assert store = @gateway.store(@credit_card, @options)
    assert_success store

    new_credit_card = credit_card('4444333322221111', :month => 3, :year => Time.now.year + 5)

    assert response = @gateway.update(store.authorization, new_credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal response.params['Customer']['CardDetails']['ExpiryMonth'], sprintf('%02d', new_credit_card.month)
    assert_equal response.params['Customer']['CardDetails']['ExpiryYear'], new_credit_card.year.to_s[2,2]
  end

  def test_unsuccessful_update
    assert response = @gateway.update(0, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid TokenCustomerID', response.message
  end

  #def test_authorize_and_capture
  #  amount = @amount
  #  assert auth = @gateway.authorize(amount, @credit_card, @options)
  #  assert_success auth
  #  assert_equal 'Success', auth.message
  #  assert auth.authorization
  #  assert capture = @gateway.capture(amount, auth.authorization)
  #  assert_success capture
  #end

  #def test_failed_capture
  #  assert response = @gateway.capture(@amount, '')
  #  assert_failure response
  #  assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  #end
end
