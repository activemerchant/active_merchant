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
end
