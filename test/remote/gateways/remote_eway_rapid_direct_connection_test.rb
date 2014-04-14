require 'test_helper'

class RemoteEwayRapidDirectConnectionTest < Test::Unit::TestCase
  def setup
    @gateway = EwayRapidDirectConnectionGateway.new( login: "44DD7CvVGwHTOZvVfIau6PHf/H779pyQ6Nl0nseYORBzslVaMQ50nf8aOKwPSsPhO71baE",
                                                     password: "Passw0rd")

    @amount = 10000
    @credit_card = credit_card('4444333322221111' , options = {:month => 12})
    @declined_card = credit_card('111111111111111', options = {:month => 12})

    @options = {
      :order_id => "1",
      :billing_address => {
          :title    => "Ms.",
          :name     => "Baker",
          :company  => "Elsewhere Inc.",
          :address1 => "4321 Their St.",
          :address2 => "Apt 2",
          :city     => "Chicago",
          :state    => "IL",
          :zip      => "60625",
          :country  => "US",
          :phone    => "1115555555",
          :fax      => "1115556666"
        },
      :description => "Store Purchase",
      :redirect_url => "http://bogus.com"
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid EWAY_CARDNUMBER', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    
    assert refund = @gateway.refund(10000, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1000, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_invalid_login
    gateway = EwayRapidDirectConnectionGateway.new(
      login: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

end
