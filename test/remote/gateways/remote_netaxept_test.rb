require 'test_helper'

class RemoteNetaxeptTest < Test::Unit::TestCase
  def setup
    @gateway = NetaxeptGateway.new(fixtures(:netaxept))

    @amount = 100
    @credit_card = credit_card('4925000000000004')
    @declined_card = credit_card('4925000000000087')

    @options = {
      :order_id => generate_unique_id
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_failed_purchase
   assert response = @gateway.purchase(@amount, @declined_card, @options)
   assert_failure response
   assert_match(/failure/i, response.message)
  end

  def test_authorize_and_capture
   assert auth = @gateway.authorize(@amount, @credit_card, @options)
   assert_success auth
   assert_equal 'OK', auth.message
   assert auth.authorization
   assert capture = @gateway.capture(@amount, auth.authorization)
   assert_success capture
  end

  def test_failed_capture
   assert response = @gateway.capture(@amount, '')
   assert_failure response
   assert_equal "Unable to find transaction", response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    response = @gateway.refund(@amount, response.authorization)
    assert_success response
  end

  def test_failed_refund
   assert response = @gateway.purchase(@amount, @credit_card, @options)
   assert_success response

   response = @gateway.refund(@amount+100, response.authorization)
   assert_failure response
   assert_equal "Unable to credit more than captured amount", response.message
  end

  def test_successful_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    response = @gateway.void(response.authorization)
    assert_success response
  end

  def test_failed_void
   assert response = @gateway.purchase(@amount, @credit_card, @options)
   assert_success response

   response = @gateway.void(response.authorization)
   assert_failure response
   assert_equal "Unable to annul, wrong state", response.message
  end

  def test_successful_amex_purchase
    credit_card = credit_card('378282246310005', :brand => 'american_express')
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_master_purchase
    credit_card = credit_card('5413000000000000', :brand => 'master')
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_error_in_transaction_setup
   assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'BOGG'))
   assert_failure response
   assert_match(/currency code/, response.message)
  end

  def test_successful_amex_purchase
   credit_card = credit_card('378282246310005', :brand => 'american_express')
   assert response = @gateway.purchase(@amount, credit_card, @options)
   assert_success response
   assert_equal 'OK', response.message
  end

  def test_successful_master_purchase
   credit_card = credit_card('5413000000000000', :brand => 'master')
   assert response = @gateway.purchase(@amount, credit_card, @options)
   assert_success response
   assert_equal 'OK', response.message
  end

  def test_error_in_payment_details
   assert response = @gateway.purchase(@amount, credit_card(''), @options)
   assert_failure response
   assert_equal "Cardnumber:Required", response.message
  end

  def test_amount_is_not_required_again_when_capturing_authorization
   assert response = @gateway.authorize(@amount, @credit_card, @options)
   assert_success response

   assert response = @gateway.capture(nil, response.authorization)
   assert_equal "OK", response.message
  end

  def test_query_fails
    query = @gateway.send(:query_transaction, "bogus", @options)
    assert_failure query
    assert_match(/unable to find/i, query.message)
  end

  def test_invalid_login
   gateway = NetaxeptGateway.new(
               :login => '',
               :password => ''
             )
   assert response = gateway.purchase(@amount, @credit_card, @options)
   assert_failure response
   assert_match(/Unable to authenticate merchant/, response.message)
  end
end
