require 'test_helper'

class EwayRapidDirectConnectionTest < Test::Unit::TestCase
  def setup
    @gateway = EwayRapidDirectConnectionGateway.new(
      :login => "44DD7CvVGwHTOZvVfIau6PHf/H779pyQ6Nl0nseYORBzslVaMQ50nf8aOKwPSsPhO71baE",
      :password => "Passw0rd"
    )

    @credit_card = credit_card('4444333322221111', options = {:month => 12})
    @declined_card = credit_card('111111111111111', options = {:month => 12})
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Transaction Approved', response.message
    assert response.test?
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    
    assert refund = @gateway.refund(100, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

end
