require 'test_helper'
class RemoteNabTransactTest < Test::Unit::TestCase

  def setup
    @gateway = NabTransactGateway.new(fixtures(:nab_transact))

    @amount = 200
    @credit_card = credit_card('4444333322221111')

    @declined_card = credit_card('4111111111111234')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'NAB Transact Purchase'
    }
  end

  # Order totals to simulate approved transactions:
  #   $1.00 $1.08 $105.00 $105.08 (or any total ending in 00, 08, 11 or 16)

  # Order totals to simulate declined transactions:
  #   $1.51 $1.05 $105.51 $105.05 (or any total not ending in 00, 08, 11 or 16)

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_purchase_insufficient_funds
    #Any total not ending in 00/08/11/16
    failing_amount = 151 #Specifically tests 'Insufficient Funds'
    assert response = @gateway.purchase(failing_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  def test_unsuccessful_purchase_do_not_honour
    #Any total not ending in 00/08/11/16
    failing_amount = 105 #Specifically tests 'do not honour'
    assert response = @gateway.purchase(failing_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Do Not Honour', response.message
  end

  def test_unsuccessful_purchase_bad_credit_card
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid Credit Card Number', response.message
  end

  def test_invalid_login
    gateway = NabTransactGateway.new(
                :login => 'ABCFAKE',
                :password => 'changeit'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid merchant ID', response.message
  end

  def test_successful_store
    @gateway.unstore(1234)

    assert response = @gateway.store(@credit_card, {:billing_id => 1234, :amount => 150})
    assert_success response
    assert_equal 'Successful', response.message
  end

  def test_unsuccessful_store
    @gateway.unstore(1235)

    assert response = @gateway.store(@declined_card, {:billing_id => 1235, :amount => 150})
    assert_failure response
    assert_equal 'Invalid Credit Card Number', response.message
  end

  def test_duplicate_store
    @gateway.unstore(1236)

    assert response = @gateway.store(@credit_card, {:billing_id => 1236, :amount => 150})
    assert_success response
    assert_equal 'Successful', response.message

    assert response = @gateway.store(@credit_card, {:billing_id => 1236, :amount => 150})
    assert_failure response
    assert_equal 'Duplicate CRN Found', response.message
  end

  def test_unstore
    gateway_id = '1234'
    @gateway.unstore(gateway_id)

    assert response = @gateway.store(@credit_card, {:billing_id => gateway_id, :amount => 150})
    assert_success response
    assert_equal 'Successful', response.message

    assert gateway_id = response.params["crn"]
    assert unstore_response = @gateway.unstore(gateway_id)
    assert_success unstore_response
  end

  def test_successful_trigger_purchase
    gateway_id = '1234'
    trigger_amount = 12000
    @gateway.unstore(gateway_id)

    assert response = @gateway.store(@credit_card, {:billing_id => gateway_id, :amount => 150})
    assert_success response
    assert_equal 'Successful', response.message

    purchase_response = @gateway.purchase(trigger_amount, gateway_id)

    assert gateway_id = purchase_response.params["crn"]
    assert trigger_amount = purchase_response.params["amount"]
    assert_success purchase_response
    assert_equal 'Approved', purchase_response.message
  end

  def test_failure_trigger_purchase
    gateway_id = '1234'
    trigger_amount = 0
    @gateway.unstore(gateway_id)

    assert response = @gateway.store(@credit_card, {:billing_id => gateway_id, :amount => 150})
    assert_success response
    assert_equal 'Successful', response.message

    purchase_response = @gateway.purchase(trigger_amount, gateway_id)

    assert gateway_id = purchase_response.params["crn"]
    assert_failure purchase_response
    assert_equal 'Invalid Amount', purchase_response.message
  end

end