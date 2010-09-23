require 'test_helper'

class SecureNetTest < Test::Unit::TestCase

  def setup
    Base.mode = :test
    @gateway = SecureNetGateway.new(fixtures(:secure_net))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @bad_card_number = credit_card('1111222233334444')

    n = Time.now
    order_id = n.to_i.to_s + n.usec.to_s
    @options = { 
      :order_id => order_id,
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_expired_credit_card
    @credit_card.year = 2004 
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'CREDIT CARD HAS EXPIRED', response.message
  end

  def test_invalid_login
    gateway = SecureNetGateway.new(
                :login => '9988776',
                :password => 'RabbitEarsPo'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'SECURE KEY IS INVALID FOR SECURENET ID PROVIDED', response.message
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, @credit_card, auth.authorization, @options)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_successful_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization

    assert void = @gateway.void(@amount, @credit_card, auth.authorization, @options)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization

    assert void = @gateway.void(@amount, @credit_card, '123456', @options)
    assert_failure void
    assert_equal 'TRANSACTION ID DOES NOT EXIST FOR VOID', void.message
  end

  def test_unsuccessful_capture
    assert response = @gateway.capture(@amount, @credit_card, '', @options)
    assert_failure response
    assert_equal 'PREVIOUS TRANSACTION ID IS REQUIRED', response.message
  end

  def test_unsuccessful_credit_with_no_previous_transaction
    assert credit = @gateway.credit(@amount, @credit_card, '', @options)
    assert_failure credit
    assert_equal 'PREVIOUS TRANSACTION ID IS REQUIRED', credit.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @bad_card_number, @options)
    assert_failure response
    assert_equal "CARD TYPE COULDN'T BE IDENTIFIED.", response.message
  end

  def test_unsuccessful_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'Approved', purchase.message
    assert purchase.authorization

    assert credit = @gateway.credit(@amount, @credit_card, purchase.authorization, @options)
    assert_failure credit
    assert_equal 'CREDIT CANNOT BE COMPLETED ON AN UNSETTLED TRANSACTION', credit.message
  end

end
