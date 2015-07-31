require 'test_helper'

class RemoteCardknoxTest < Test::Unit::TestCase
  def setup
    @gateway = CardknoxGateway.new(fixtures(:cardknox))

    @amount = rand(499)
    @declined_amount = 500
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220', verification_value:  '518')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
       
    }
    #@check =  check(:routing_number => '021100361',:account_number => '987654321', :name => 'Jim Smith')
    #@options2 = {}

  end

  def test_successful_credit_card_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_credit_card_with_track_data_purchase
    response = @gateway.purchase(@amount, credit_card_with_track_data, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_credit_card_token_purchase  
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message

    assert purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_success purchase
    assert_equal 'Success', purchase.message
  end

  def test_successful_check_purchase
    response = @gateway.purchase(@amount, check, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_check_token_purchase 
    response = @gateway.store(check, @options)
    assert_success response
    assert_equal 'Success', response.message

    assert purchase = @gateway.purchase(@amount, response.authorization)
    assert_success purchase
    assert_equal 'Success', purchase.message
  end

  

  def test_successful_purchase_with_more_options
    options = {
     # order_id: '1',
      name:     'Jim Smith',
     
      ip: "127.0.0.1",
      email: "joe@example.com",
      invoice: '2',

      address: {
      address1: '456 My Street',  
      address2: 'Apt 1',
      company:  'Widgets Inc',
      city:     'Ottawa',
      state:    'ON',
      zip:      'K1C2N6',
      country:  'CA',
      phone:    '(555)555-5555',
      fax:      '(555)555-6666'
      },
      shipping_address: {
      name:     'Jim Smith',
      address1: '456 My Street',
      address2: 'Apt 2',
      company:  'Widgets Inc',
      city:     'Ottawa',
      state:    'ON',
      zip:      'K1C2N6',
      country:  'CA',
      phone:    '(555)555-5558',
      fax:      '(555)555-6668',
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_credit_card_purchase
    response = @gateway.purchase(@amount, '', @options)
    assert_failure response
    assert_equal 'Invalid CVV', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', auth.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid CVV', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Original transaction not specified', response.message
  end

  def test_successful_credit_card_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
     assert_failure refund
    assert_equal 'Use VOID to refund an unsettled transaction', refund.message # "Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise."
  end

  def test_successful_check_refund
    purchase = @gateway.purchase(@amount, check, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
     assert_failure refund
    assert_equal "Transaction is in a state that cannot be refunded\nParameter name: originalReferenceNumber", refund.message # "Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise."
  end
  def test_partial_credit_card_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_partial_check_refund
    purchase = @gateway.purchase(@amount, check, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_failure refund
    assert_equal "Transaction is in a state that cannot be refunded\nParameter name: originalReferenceNumber", refund.message # "Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise."
  end

  def test_failed_refund    
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'UNSUPPORTED CARD TYPE', response.message
  end

  def test_successful_credit_card_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_successful_check_void
    purchase = @gateway.purchase(@amount, check, @options)

    assert_success purchase

    assert void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void     
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Original transaction not specified', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Success}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Invalid CVV}, response.message
  end

  def test_successful_credit_card_store  #falied
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_credit_card_token_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message

    assert store = @gateway.store(response.authorization)
    assert_success store
    assert_equal 'Success', store.message    
  end

  def test_successful_check_store
    response = @gateway.store(check, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  # def test_successful_check_token_store
  #   response = @gateway.store(check)
  #   assert_success response
  #   assert_equal 'Success', response.message
  #   assert store = @gateway.store(response.authorization)
  #   assert_success store
  #   assert_equal 'Success', store.message    
  # end


  def test_invalid_login
    gateway = CardknoxGateway.new(api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Required: xKey}, response.message
  end

  #  def test_dump_transcript
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic.  You can delete
  #   # this helper after completing your scrub implementation.
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

end
