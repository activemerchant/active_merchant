require 'test_helper'

class RemoteUsaEpayTransactionTest < Test::Unit::TestCase
  def setup
    @gateway = UsaEpayTransactionGateway.new(fixtures(:usa_epay))
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    @credit_card_with_track_data = credit_card_with_track_data('4000100011112224')
    @options = { :billing_address => address(:zip => "27614", :state => "NC"), :shipping_address => address }
    @amount = 100
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Success', response.message
    assert_success response
  end

  def test_successful_purchase_with_track_data
    assert response = @gateway.purchase(@amount, @credit_card_with_track_data, @options)
    assert_equal 'Success', response.message
    assert_success response
  end

  def test_successful_authorization_with_manual_entry
    @credit_card.manual_entry = true
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Success', response.message
    assert_success response
  end

   def test_successful_purchase_with_manual_entry
    @credit_card.manual_entry = true
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Success', response.message
    assert_success response
   end

  def test_successful_purchase_with_extra_details
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:order_id => generate_unique_id, :description => "socool"))
    assert_equal 'Success', response.message
    assert_success response
  end

  def test_successful_purchase_with_extra_test_mode
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:test_mode => true))
    assert_equal 'Success', response.message
    assert_success response
  end

  def test_unsuccessful_purchase
    # For some reason this will fail with "You have tried this card too
    # many times, please contact merchant" unless a unique order id is
    # passed.
    assert response = @gateway.purchase(@amount, @declined_card, @options.merge(:order_id => generate_unique_id))
    assert_failure response
    assert_match(/declined/i, response.message)
    assert Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Unable to find original transaction.', response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert refund = @gateway.refund(@amount - 20, response.authorization)
    assert_success refund
  end

  def test_successful_refund_with_track_data
    assert response = @gateway.purchase(@amount, @credit_card_with_track_data, @options)
    assert_success response
    assert response.authorization
    assert refund = @gateway.refund(@amount - 20, response.authorization)
    assert_success refund
  end

  def test_unsuccessful_refund
    assert refund = @gateway.refund(@amount - 20, "unknown_authorization")
    assert_failure refund
    assert_match(/Unable to find original transaction/, refund.message)
  end

  def test_successful_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_unsuccessful_void
    assert void = @gateway.void("unknown_authorization")
    assert_failure void
    assert_match(/Unable to locate transaction/, void.message)
  end

  def test_successful_void_release
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.void(response.authorization, void_mode: :void_release)
    assert_success void
  end

  def test_unsuccessful_void_release
    assert void = @gateway.void("unknown_authorization", void_mode: :void_release)
    assert_failure void
    assert_match(/Unable to locate transaction/, void.message)
  end

  def test_invalid_key
    gateway = UsaEpayTransactionGateway.new(:login => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Specified source key not found.', response.message
    assert_failure response
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "Success", response.message
    assert_success response.responses.last, "The void should succeed"
  end

  def test_failed_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match "Card Declined (00)", response.message
  end

end
