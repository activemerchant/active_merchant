require File.dirname(__FILE__) + '/../test_helper'

class RemotePaySecureTest < Test::Unit::TestCase
  AMOUNT = 100

  def setup
    @gateway = PaySecureGateway.new(fixtures(:pay_secure))

    @credit_card = credit_card('4000100011112224')
    @options = { :order_id => generate_order_id }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(AMOUNT, @credit_card, @options)
    assert_success response
    assert_equal PaySecureGateway::SUCCESS_MESSAGE, response.message
    assert response.test?
  end

  def test_unsuccessful_purchase
    @credit_card.year = '2006'
    assert response = @gateway.purchase(AMOUNT, @credit_card, @options)
    assert_equal 'Declined, card expired', response.message
    assert_failure response
  end
  
  def test_invalid_login
    gateway = PaySecureGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(AMOUNT, @credit_card, @options)
    assert_equal "MissingField: 'MERCHANT_ID'", response.message
    assert_failure response
  end
end
