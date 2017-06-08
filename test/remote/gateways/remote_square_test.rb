require 'test_helper'

# Tip for running just one test:
#   $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
#     test/remote/gateways/remote_square_test.rb \
#     -n test_successful_purchase


class RemoteSquareTest < Test::Unit::TestCase
  # include so that we can to use ssl_get()
  include ActiveMerchant::PostsData

  def setup
    @gateway = SquareGateway.new(fixtures(:square))
    @amount = 100
    # sandbox nonce https://docs.connect.squareup.com/articles/using-sandbox/
    @credit_card = 'fake-card-nonce-ok'
    @declined_card = 'fake-card-nonce-declined'
    @options = {
      :billing_address => address,
      :description => 'Store Purchase Note'
    }
  end

  def test_only_accepts_card_nonce_not_creditcard_pan
    credit_card_pan = '4111111111111111' # should be rejected
    response = @gateway.purchase(@amount, credit_card_pan, @options)
    assert_failure response
    assert_not_nil err = response.params['errors'].first
    assert_equal 'INVALID_REQUEST_ERROR', err['category']
    assert_equal 'NOT_FOUND', err['code']
    assert_nil response.error_code
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 1, response.responses.count
    assert_equal 'Success', response.message
    assert_nil response.error_code
  end

  def test_successful_purchase_with_more_options
    options = {
      :idemepotency_key => SecureRandom.uuid,
      :shipping_address => address,
      :billing_address => address,
      :buyer_email_address => "joe@example.com",
      :order_id => 'OrderNum123',
      :description => 'custom description note you ordered xyz'
    }

    response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_not_nil txn = response.params['transaction']
    assert_equal 'OrderNum123', txn['reference_id']
    assert_equal 'CAPTURED', txn['tenders'].first['card_details']['status']
    assert_equal 'custom description note you ordered xyz', txn['tenders'].first['note']
    assert_equal 'Success', response.message
    assert_nil response.error_code
end

  # General purchase and authorize tests.

  def test_failed_purchase_decline
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 1, response.responses.count
    assert_equal 'Card declined.', response.message
    assert_equal 'card_declined', response.error_code
  end

  def test_failed_purchase_invalid_cvv
    response = @gateway.purchase(@amount, 'fake-card-nonce-rejected-cvv', @options)
    assert_failure response
    assert_equal 'Card verification code check failed.', response.message
    assert_equal 'incorrect_cvc', response.error_code
  end

  def test_failed_purchase_rejected_avs_zip
    response = @gateway.purchase(@amount, 'fake-card-nonce-rejected-postalcode', @options)
    assert_failure response
    assert_equal 'Postal code check failed.', response.message
    assert_equal 'incorrect_zip', response.error_code
  end

  def test_failed_purchase_expiration_incorrect
    response = @gateway.purchase(@amount, 'fake-card-nonce-rejected-expiration', @options)
    assert_failure response
    assert_equal 'Invalid card expiration date.', response.message
    assert_equal 'invalid_expiry_date', response.error_code
  end

  def test_successful_authorize_and_capture
    @options.merge!({:delay_capture => true})
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 1, auth.responses.count
    assert_nil auth.error_code
    assert_equal 'AUTHORIZED', auth.params['transaction']['tenders'].first['card_details']['status']
    assert_not_nil txn_id = auth.authorization

    assert capture = @gateway.capture(@amount, txn_id)
    assert_success capture

    assert_equal 'Success', capture.message
    assert_nil capture.error_code
    
    # Does not return the transaction back when capturing, so manually fetch it to verify.
    location_id = fixtures(:square)[:location_id]
    resource = SquareGateway::live_url + "locations/#{location_id}/transactions/#{txn_id}"
    json = JSON.parse(ssl_get(resource, @gateway.send(:headers)))
    assert_equal 'CAPTURED', json['transaction']['tenders'].first['card_details']['status']
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 1, response.responses.count

    assert_equal 'Card declined.', response.message
    assert_equal 'card_declined', response.error_code
  end

  # Not (yet, Q3 '16) Implemented by Square
  # def test_partial_capture
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth

  #   assert capture = @gateway.capture(@amount-1, auth.authorization)
  #   assert_success capture
  # end

  def test_failed_capture
    response = @gateway.capture(@amount, 'missing-txn-id')
    assert_failure response
    assert_equal "Location `#{fixtures(:square)[:location_id]}` does not have a transaction with ID `missing-txn-id`.", response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    tender_id = purchase.params['transaction']['tenders'].first['id']
    options = {:tender_id => tender_id, :reason => 'oops!', :idemepotency_key => 'abc12'}

    assert refund = @gateway.refund(@amount, purchase.authorization, options)
    assert_success refund
    assert_equal 'Success', refund.message
    assert_nil refund.error_code
    assert_equal 'oops!', refund.params['refund']['reason']
    assert_equal tender_id, refund.params['refund']['tender_id']
    assert_equal purchase.authorization, refund.params['refund']['transaction_id']
    assert_equal @amount, refund.params['refund']['amount_money']['amount']
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    tender_id = purchase.params['transaction']['tenders'].first['id']
    options = {:tender_id => tender_id, :reason => 'oops!', :idemepotency_key => 'abc12'}

    assert refund = @gateway.refund(@amount-1, purchase.authorization, options)
    assert_success refund
    assert_equal @amount-1, refund.params['refund']['amount_money']['amount']
  end

  def test_error_refund_required_field
    expected_called = false
    begin
      @gateway.refund(@amount, '')
    rescue ArgumentError => e
      expected_called = true
    end
    assert_true expected_called
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'non-existant-authorization', {:tender_id => 'abc'})
    assert_failure response
    assert_equal "Location `#{fixtures(:square)[:location_id]}` does not have a transaction tender with ID `abc`.", response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    response = @gateway.void('non-existant-authorization')
    assert_failure response
    assert_equal "Location `#{fixtures(:square)[:location_id]}` does not have a transaction with ID `non-existant-authorization`.", response.message
    assert_nil response.error_code
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Success}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Card declined.}, response.message
  end


  # All customer / stored card related below.


  def test_store_customer_save_card
    assert response = @gateway.store(@credit_card, {
      :given_name => 'fname', :family_name => 'lname', 
      :company_name => 'abc inc', :nickname => 'fred', 
      :phone_number => '444-111-1232', :email => 'a@example.com',
      :description => 'describe me', :reference_id => 'ref-abc01',
      :billing_address => {
        :zip => '94103'
      }, 
      :cardholder_name => 'Alexander Hamilton',
      :address => { :address1 => '456 My Street', :address2 => 'Apt 1',
        :address3 => 'line 3', :city => 'Ottawa', :sublocality => 'county X',
        :sublocality_2 => 'sublocality 2', :sublocality_3 => 'sublocality 3',
        :state => 'ON', :administrative_district_level_2 => 'admin district 2',
        :administrative_district_level_3 => 'admin district 3', 
        :zip => 'K1C2N6', :country => 'CA'}
      })
    assert_equal 2, response.responses.count
    assert_success first = response.responses[0]
    assert_success second = response.responses[1]
    assert_match /Success/, first.message
    assert_match /Success/, second.message

    assert_equal "describe me", first.params['customer']['note']
    assert_equal "a@example.com", first.params['customer']['email_address']
    assert_equal "fname", first.params['customer']['given_name']
    assert_equal "lname", first.params['customer']['family_name']
    assert_equal "abc inc", first.params['customer']['company_name']
    assert_equal "fred", first.params['customer']['nickname']
    assert_equal "444-111-1232", first.params['customer']['phone_number']
    assert_equal "ref-abc01", first.params['customer']['reference_id']
    assert_not_nil first.params['customer']['address']
    assert_equal '456 My Street', first.params['customer']['address']['address_line_1']
    assert_equal 'Apt 1', first.params['customer']['address']['address_line_2']
    assert_equal 'line 3', first.params['customer']['address']['address_line_3']
    
    assert_equal 'Ottawa', first.params['customer']['address']['locality']
    assert_equal 'county X', first.params['customer']['address']['sublocality']
    assert_equal 'sublocality 2', first.params['customer']['address']['sublocality_2']
    assert_equal 'sublocality 3', first.params['customer']['address']['sublocality_3']

    assert_equal 'ON', first.params['customer']['address']['administrative_district_level_1']
    assert_equal 'admin district 2', first.params['customer']['address']['administrative_district_level_2']
    assert_equal 'admin district 3', first.params['customer']['address']['administrative_district_level_3']

    assert_equal 'K1C2N6', first.params['customer']['address']['postal_code']
    assert_equal 'CA', first.params['customer']['address']['country']

    assert_not_nil second.params['card']['id']
    assert_not_nil second.params['card']['last_4']
    assert_not_nil second.params['card']['exp_month']
    assert_not_nil second.params['card']['exp_year']
    assert_not_nil second.params['card']['card_brand']    
    assert_equal 'Alexander Hamilton', second.params['card']['cardholder_name']
    assert_equal '94103', second.params['card']['billing_address']['postal_code']
  end

  def test_failed_store_invalid_card_does_not_validate_when_verify_called_on_storing
    assert response = @gateway.store(@declined_card, { # minimal fields
      :billing_address => {:zip => '94103'}, :email => 'a@example.com'})
    assert_success first = response.responses[0]
    assert customer_id = first.params['customer']['id']
    assert_failure second = response.responses[1]
    assert_equal 'processing_error', second.error_code
    assert_equal 'Invalid card data.', second.message
  end

  def test_create_customer_update_customer_add_card_delete_card
    assert response = @gateway.create_customer({
      :email => 'a@example.com', :reference_id => 'ref-abc01'})
    assert_success first = response.responses[0]
    assert_match /Success/, first.message
    assert customer_id = first.params['customer']['id']
    assert_equal "ref-abc01", first.params['customer']['reference_id']
    assert_equal "a@example.com", first.params['customer']['email_address']

    assert response = @gateway.update_customer(customer_id, 
      {:email => 'new@me.com'})
    assert_success response
    
    # changed
    assert_equal "new@me.com", response.params['customer']['email_address'] 

    # didn't change
    assert_equal "ref-abc01", response.params['customer']['reference_id']

    options = {:customer_id => customer_id, :billing_address => {:zip => '94103'}}
    assert response = @gateway.store(@credit_card, options)
    assert_equal 1, response.responses.count
    assert_success response.responses[0]
    assert_not_nil card_id = response.params['card']['id']

    assert response = @gateway.unstore(card_id, {:customer => {:id => customer_id}})
    assert_success response
  end

  def test_successful_purchase_with_customer_card_on_file__existing_customer_and_card
    assert response = @gateway.store(@credit_card, { # minimal fields
      :billing_address => {:zip => '94103'}, :email => 'a@example.com'})
    assert_success first = response.responses[0]
    assert customer_id = first.params['customer']['id']
    assert_success second = response.responses[1]
    assert card_id = second.params['card']['id']

    assert response = @gateway.purchase(200, nil, {:customer => {:id => customer_id, :card_id => card_id}})
    assert_success response
    assert_equal customer_id, response.params['transaction']['tenders'].first['customer_id']
    assert_equal card_id, response.params['transaction']['tenders'].first['card_details']['card']['id']
    assert_equal 'CAPTURED', response.params['transaction']['tenders'].first['card_details']['status']
  end

  def test_successful_purchase_with_customer_card_on_file__existing_customer_new_card_by_nonce
    assert response = @gateway.store(@credit_card, { # minimal fields
      :billing_address => {:zip => '94103'}, :email => 'a@example.com'})
    assert_success first = response.responses[0]
    assert customer_id = first.params['customer']['id']
    assert_success second = response.responses[1]
    assert old_card_id = second.params['card']['id']

    # Must send in the new billing zip for the new card.
    assert response = @gateway.purchase(200, @credit_card, {:customer => {:id => customer_id,
      :billing_address => {:zip => '94103'}}})
    assert_success response
    assert_equal customer_id, response.params['transaction']['tenders'].first['customer_id']
    assert new_card_id = response.params['transaction']['tenders'].first['card_details']['card']['id']
    assert_not_equal old_card_id, new_card_id
    assert_equal 'CAPTURED', response.params['transaction']['tenders'].first['card_details']['status']
  end

  def test_successful_purchase_with_customer_card_on_file__new_customer_new_card
    assert response = @gateway.purchase(200, @credit_card,  :customer => {
      :given_name => 'fname', :family_name => 'lname', :company_name => 'abc inc',
      :nickname => 'fred', :phone_number => '444-111-1232', :email => 'a@example.com',
      :description => 'describe me', :reference_id => 'ref-abc01',
      :billing_address => {
        :zip => '94103'
      }, 
      :cardholder_name => 'Alexander Hamilton',
      :address => { :address1 => '456 My Street', :address2 => 'Apt 1', :address3 => 'line 3',
        :city => 'Ottawa', :sublocality => 'county X', :sublocality_2 => 'sublocality 2', :sublocality_3 => 'sublocality 3',
        :state => 'ON', :administrative_district_level_2 => 'admin district 2', 
        :administrative_district_level_3 => 'admin district 3', :zip => 'K1C2N6', :country => 'CA'}
      })
    assert_equal 3, response.responses.size #create customer, link card, purchase
    assert_success first = response.responses[0]
    assert customer_id = first.params['customer']['id']
    
    assert_success second = response.responses[1]
    assert card_id = second.params['card']['id']
    
    assert_success third = response.responses[2]
    assert_equal customer_id, third.params['transaction']['tenders'].first['customer_id']
    assert_equal card_id, third.params['transaction']['tenders'].first['card_details']['card']['id']
    assert_equal 'ON_FILE', third.params['transaction']['tenders'].first['card_details']['entry_method']
    assert_equal 'CAPTURED', third.params['transaction']['tenders'].first['card_details']['status']
  end

  def test_successful_authorize_with_customer_card_on_file
    assert response = @gateway.store(@credit_card, { # minimal fields
      :billing_address => {:zip => '94103'}, :email => 'a@example.com'})
    assert_success first = response.responses[0]
    assert customer_id = first.params['customer']['id']
    assert_success second = response.responses[1]
    assert card_id = second.params['card']['id']

    assert response = @gateway.authorize(200, nil, {:customer => {:id => customer_id, :card_id => card_id}})
    assert_success response
    assert_equal customer_id, response.params['transaction']['tenders'].first['customer_id']
    assert_equal card_id, response.params['transaction']['tenders'].first['card_details']['card']['id']
    assert_equal 'AUTHORIZED', response.params['transaction']['tenders'].first['card_details']['status']
  end


  # Other tests below.


  def test_invalid_login
    gateway = SquareGateway.new(:login => '', :password => '', :location_id => 'fake', :test => false)

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'config_error', response.error_code
    assert_match %r{The `Authorization` http header of your request was malformed}, response.message
  end

  # Keeping this in here for when new tests are added, uncomment and run to save
  # a fresh dump.
  # def test_dump_transcript
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic.  You can delete
  #   # this helper after completing your scrub implementation.
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  #   # Note, I needed to add to the `headers` method in square.rb a line
  #   # to prevent gzip in the response: 
  #   #    'Accept-Encoding' => ''
  # end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card, transcript) # scrub nonce
    assert_scrubbed(@gateway.options[:password], transcript) # scrub access token
  end

end
