require 'test_helper'

class RemotePayprosTest < Test::Unit::TestCase

  def setup
    @gateway = PayprosGateway.new(fixtures(:paypros))
    
    @amounts = {
      :success => 1,
      :declined => 10,
      :hold_card => 28,
      :mpd_charge => 1
    }
    @credit_card = credit_card('4788250000028291')
    
    @options = { 
      :order_id => Array.new(9, '').collect{("1".."9").to_a[rand(10)]}.join,
      :billing_address => address,
      :description => 'Store Purchase'
    }
    
    @card_swipe = fixtures(:paypros_swipe_data)
  end
  
  def test_mpd_add_user_with_auth_and_void
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    assert response = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success response
    
    payer_id = response.params["payer_identifier"]
    
    assert_equal "1", response.params["mpd_response_code"]
    assert_not_nil payer_id
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
    
    assert void = @gateway.void(response.authorization)
    assert_success void
    assert_equal 'Successful transaction: The transaction completed successfully.', void.message
  end

  def test_mpd_add_user_with_purchase
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    assert response = @gateway.purchase(@amounts[:success], @credit_card, @options)
    assert_success response
    payer_id = response.params["payer_identifier"]
    
    assert_equal "1", response.params["mpd_response_code"]
    assert_not_nil payer_id
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
  end
  
  def test_mpd_add_user_and_run_purchase
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    assert response = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success response
    
    payer_id = response.params["payer_identifier"]
    
    assert_equal "1", response.params["mpd_response_code"]
    assert_not_nil payer_id
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
    
    @options[:payer_identifier] = payer_id
    @options[:span] = span
    @options[:order_id] = Array.new(9, '').collect{("1".."9").to_a[rand(10)]}.join
    
    assert purchase = @gateway.purchase(@amounts[:mpd_charge], nil, @options)
    assert_success purchase
    assert_equal "1", purchase.params["mpd_response_code"]
    assert_equal payer_id, purchase.params["payer_identifier"]
    assert_equal (@amounts[:mpd_charge] / 100.0).to_s, purchase.params["captured_amount"]
    assert_equal 'Successful transaction: The transaction completed successfully.', purchase.message
  end
  
  
  def test_mpd_add_user_and_run_purchase_and_void
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    assert response = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success response
    
    payer_id = response.params["payer_identifier"]
    
    assert_equal "1", response.params["mpd_response_code"]
    assert_not_nil payer_id
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
    
    @options[:payer_identifier] = payer_id
    @options[:span] = span
    @options[:order_id] = Array.new(9, '').collect{("1".."9").to_a[rand(10)]}.join
    
    assert purchase = @gateway.purchase(@amounts[:mpd_charge], nil, @options)
    assert_success purchase
    assert_equal "1", purchase.params["mpd_response_code"]
    assert_equal payer_id, purchase.params["payer_identifier"]
    assert_equal (@amounts[:mpd_charge] / 100.0).to_s, purchase.params["captured_amount"]
    assert_equal 'Successful transaction: The transaction completed successfully.', purchase.message
    
    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Successful transaction: The transaction completed successfully.', void.message
  end
  
  
  def test_mpd_add_then_update_and_charge
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    assert response = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success response
    
    payer_id = response.params["payer_identifier"]
    
    assert_equal "1", response.params["mpd_response_code"]
    assert_not_nil payer_id
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
    
    # Change the card data
    @options[:order_id] = Array.new(9, '').collect{("1".."9").to_a[rand(10)]}.join
    @options[:span] = span
    @options[:payer_identifier] = payer_id
    
    credit_card_2 = credit_card('5149612222222229')
    span2 = credit_card_2.last_digits
    
    assert response_2 = @gateway.authorize(@amounts[:success], credit_card_2, @options)
    payer_id_2 = response_2.params["payer_identifier"]
    
    assert_equal "1", response_2.params["mpd_response_code"]
    assert_not_nil payer_id_2
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
    assert_equal payer_id, payer_id_2
    assert_equal span2, response_2.params["span"] 
    
    # Check that a charge uses the new span
    @options[:order_id] = Array.new(9, '').collect{("1".."9").to_a[rand(10)]}.join
    @options[:span] = span2
    assert updated_charge = @gateway.purchase(@amounts[:mpd_charge], nil, @options)
    assert_success updated_charge
    
    assert_equal span2, updated_charge.params["span"]
    assert_equal payer_id, updated_charge.params["payer_identifier"]
    assert_equal (@amounts[:mpd_charge] / 100.0).to_s, updated_charge.params["captured_amount"]
    assert_equal 'Successful transaction: The transaction completed successfully.', updated_charge.message
  end
  
  def test_mpd_failed_authorization
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    assert response = @gateway.authorize(@amounts[:declined], @credit_card, @options)
    assert_failure response
    
    payer_id = response.params["payer_identifier"]
    
    assert_equal "1", response.params["mpd_response_code"]
    assert_not_nil payer_id
    assert_equal 'Declined transaction: The transaction is declined.', response.message
  end
  
  def test_mpd_add_failed_updated
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    assert response = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success response
    
    payer_id = response.params["payer_identifier"]
    
    assert_equal "1", response.params["mpd_response_code"]
    assert_not_nil payer_id
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
    
    # Try to change the card data
    @options[:order_id] = Array.new(9, '').collect{("1".."9").to_a[rand(10)]}.join
    @options[:span] = span
    @options[:payer_identifier] = payer_id
    
    credit_card_2 = credit_card('5149612222222229')
    span2 = credit_card_2.last_digits
    
    assert response_2 = @gateway.authorize(@amounts[:declined], credit_card_2, @options)
    assert_failure response_2
    payer_id_2 = response_2.params["payer_identifier"]
    
    assert_nil response_2.params["mpd_response_code"]
    assert_nil payer_id_2
  end

  def test_mpd_add_user_failed_purchase
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    assert response = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success response
    
    payer_id = response.params["payer_identifier"]
    
    assert_equal "1", response.params["mpd_response_code"]
    assert_not_nil payer_id
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
    
    @options[:payer_identifier] = payer_id
    @options[:span] = span
    @options[:order_id] = Array.new(9, '').collect{("1".."9").to_a[rand(10)]}.join
    
    assert purchase = @gateway.purchase(@amounts[:declined], nil, @options)
    assert_failure purchase
    assert_nil purchase.params["mpd_response_code"]
    assert_nil purchase.params["payer_identifier"]
    assert_equal "0.00", purchase.params["captured_amount"]
    assert_equal 'Declined transaction: The transaction is declined.', purchase.message
  end
  
  def test_mpd_failed_with_bad_payer_id
    span = @credit_card.last_digits
    @options[:manage_payer_data] = true
    
    @options[:span] = span
    @options[:payer_identifier] = "00000000-0000-0000-0000-111111111111"
    
    assert response = @gateway.purchase(@amounts[:success], nil, @options)
    assert_failure response
    
    assert_equal "6", response.params["response_code"]
    assert_equal 'Transaction Not Possible: specified payer data is not under management', response.message
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success response
    assert_equal 'Successful transaction: The transaction completed successfully.', response.message
  end
  
  def test_failed_authorization
    assert response = @gateway.authorize(@amounts[:declined], @credit_card, @options)
    assert_failure response
    assert_equal 'Declined transaction: The transaction is declined.', response.message
  end
  
  def test_successful_purchase
     assert response = @gateway.purchase(@amounts[:success], @credit_card, @options)
     assert_success response
     assert !response.fraud_review?
     assert_equal 'Successful transaction: The transaction completed successfully.', response.message
  end
  
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amounts[:declined], @credit_card, @options)
    assert_failure response
    assert !response.fraud_review?
    assert_equal 'Declined transaction: The transaction is declined.', response.message
  end
  
  def test_fraud_purchase
    assert response = @gateway.purchase(@amounts[:hold_card], @credit_card, @options)
    assert_failure response
    assert response.fraud_review?
    assert_equal 'Declined transaction: Please hold the card and call issuer.', response.message
  end
  
  def test_authorize_and_capture
    amount = @amounts[:success]
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction: The transaction completed successfully.', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success authorization
    
    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'Successful transaction: The transaction completed successfully.', void.message
  end
  
  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amounts[:success], @credit_card, @options)
    assert_success purchase
    
    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Successful transaction: The transaction completed successfully.', void.message
  end
  
  def test_auth_capture_and_void
    amount = @amounts[:success]
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction: The transaction completed successfully.', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    
    assert void = @gateway.void(capture.authorization)
    assert_success void
    assert_equal 'Successful transaction: The transaction completed successfully.', void.message
  end
  
  def test_failed_capture
    assert response = @gateway.capture(@amounts[:success], '')
    assert_failure response
    assert_equal 'Missing required request field: Order ID.', response.message
  end
  
  def test_successful_authorization_swipe
    unless @card_swipe == 'ignore'
      @options.delete(:billing_address)
      assert response = @gateway.authorize(@amounts[:success], @card_swipe, @options)
      assert_success response
      assert !response.fraud_review?
      assert_equal 'Successful transaction: The transaction completed successfully.', response.message
    end
  end
  
  def test_purchase_and_query
    assert purchase = @gateway.purchase(@amounts[:success], @credit_card, @options)
    assert_success purchase
    
    assert query = @gateway.query_purchase(purchase.authorization)
    assert_success query
    assert_equal 'Successful transaction: The transaction completed successfully.', query.message
  end
  
  def test_invalid_login
    gateway = PayprosGateway.new(
                :login => ''
              )
    assert response = gateway.purchase(@amounts[:success], @credit_card, @options)
    assert_failure response
    assert_equal 'Missing Required Request Field: Account Token.', response.message
  end
end
