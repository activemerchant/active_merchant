require 'test_helper'

class RemoteBe2billTest < Test::Unit::TestCase
  def setup
    @gateway = Be2billGateway.new(fixtures(:be2bill))

    @amount        = 100
    @credit_card   = credit_card('4000100011112224')
    @declined_card = credit_card('5555557376384001')

    @amounts = {
      Date.today.to_s               => 50,
      1.month.from_now.to_date.to_s => 50
    }

    @options = {
      :order_id     => '1',
      :description  => 'Store Purchase',
      :customer_id  => '1',
      :referrer     => 'google.com',
      :user_agent   => 'Firefox 25',
      :ip           => '127.0.0.1',
      :email        => 'customer@yopmail.com'
    }

    @refund_options = {
      :order_id     => '1',
      :description  => 'Refund Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved : The transaction has been accepted.', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined (4001 - The bank refused the transaction.', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved : The transaction has been accepted.', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Declined (1001 - The parameter "TRANSACTIONID" is missing.', response.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined (4001 - The bank refused the transaction.', response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.refund(@amount, response.authorization, @refund_options)
    assert_success response
    assert_equal 'Approved : The transaction has been accepted.', response.message
  end

  def test_failed_refund
    assert response = @gateway.refund(@amount, '', @refund_options)
    assert_failure response
    assert_equal 'Declined (1001 - The parameter "TRANSACTIONID" is missing.', response.message
  end

  def test_successful_void
    assert response = @gateway.purchase(@amounts, @credit_card, @options)
    assert_success response

    assert response = @gateway.void(response.authorization, @options)
    assert_success response
    assert_equal 'Approved : The transaction has been accepted.', response.message
  end

  def test_failed_void
    assert response = @gateway.void('')
    assert_failure response
    assert_equal 'Declined (1001 - The parameter "SCHEDULEID" is missing.', response.message
  end

  def test_invalid_login
    gateway = Be2billGateway.new(
      :login    => '',
      :password => ''
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined (1001 - The parameter "IDENTIFIER" is missing.', response.message
  end
end
