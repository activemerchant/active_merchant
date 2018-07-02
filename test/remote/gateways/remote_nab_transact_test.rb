require 'test_helper'

class RemoteNabTransactTest < Test::Unit::TestCase

  def setup
    @gateway = NabTransactGateway.new(fixtures(:nab_transact))
    @privileged_gateway = NabTransactGateway.new(fixtures(:nab_transact_privileged))

    @amount = 200
    @credit_card = credit_card('4444333322221111')

    @declined_card = credit_card('4111111111111234')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'NAB Transact Purchase'
    }
  end

  # Order totals to simulate approved transactions:
  #   $1.00 $1.08 $105.00 $105.08 (or any total ending in 00, 08, 11 or 16)

  # Order totals to simulate declined transactions:
  #   $1.51 $1.05 $105.51 $105.05 (or any total not ending in 00, 08, 11 or 16)

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_purchase_insufficient_funds
    #Any total not ending in 00/08/11/16
    failing_amount = 151 #Specifically tests 'Insufficient Funds'
    assert response = @gateway.purchase(failing_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  def test_unsuccessful_purchase_do_not_honour
    #Any total not ending in 00/08/11/16
    failing_amount = 105 #Specifically tests 'do not honour'
    assert response = @gateway.purchase(failing_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Do Not Honour', response.message
  end

  def test_unsuccessful_purchase_bad_credit_card
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid Credit Card Number', response.message
  end

  # Unfortunately there is no "real" way to test the dynamic card acceptor,
  # however the "Integration Guide - XML API for Payments" documentation states:
  #   If enabled on your NAB Transact account, the Dynamic Card Acceptor details
  #   will be accepted via metadata tags added to your XML request. Note that
  #   permission for this feature must be enabled on your account or you will
  #   receive a response of “555 – Permission denied”.
  #
  # I couldn't find any other reference to this error code, so we can set the
  # fields on an account with the dynamic card acceptor feature disabled and
  # ensure we get the error.
  def test_successful_purchase_with_card_acceptor
    card_acceptor_options = {
      :merchant_name => 'ActiveMerchant',
      :merchant_location => 'Melbourne'
    }
    card_acceptor_options.each do |key, value|
      options = @options.merge({key => value})
      assert response = @gateway.purchase(@amount, @credit_card, options)
      assert_failure response
      assert_equal 'Permission denied', response.message

      assert response = @privileged_gateway.purchase(@amount, @credit_card, options)
      assert_success response
      assert_equal 'Approved', response.message
    end
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    authorization = auth.authorization

    assert capture = @gateway.capture(@amount, authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_unsuccessful_authorize_insufficient_funds
    # amount of 151 is the test amount for "Insufficient Funds"
    failing_amount = 151

    assert response = @gateway.authorize(failing_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  def test_unsuccessful_authorize_do_not_honour
    # amount of 105 for "Do Not Honour"
    failing_amount = 105

    assert response = @gateway.authorize(failing_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Do Not Honour', response.message
  end

  def test_unsuccessful_capture_amount_greater_than_authorized
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    authorization = auth.authorization

    assert capture = @gateway.capture(@amount+100, authorization)
    assert_failure capture
    assert_equal 'Preauth was done for smaller amount', capture.message
  end

  def test_authorize_and_capture_with_card_acceptor
    card_acceptor_options = {
      :merchant_name => 'ActiveMerchant',
      :merchant_location => 'Melbourne'
    }
    card_acceptor_options.each do |key, value|
      options = @options.merge({key => value})
      assert response = @gateway.authorize(@amount, @credit_card, options)
      assert_failure response
      assert_equal 'Permission denied', response.message

      assert response = @privileged_gateway.authorize(@amount, @credit_card, options)
      assert_success response
      assert_equal 'Approved', response.message

      authorization = response.authorization

      assert response = @privileged_gateway.capture(@amount, authorization)
      assert_success response
      assert_equal 'Approved', response.message
    end
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    authorization = response.authorization
    assert response = @gateway.refund(@amount, authorization)
    assert_success response
    assert_equal 'Approved', response.message
  end

  # You need to speak to NAB Transact to have this feature enabled on
  # your account otherwise you will receive a "Permission denied" error
  def test_credit
    assert response = @gateway.credit(@amount, @credit_card, {:order_id => '1'})
    assert_failure response
    assert_equal 'Permission denied', response.message

    assert response = @privileged_gateway.credit(@amount, @credit_card, {:order_id => '1'})
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    authorization = response.authorization
    assert response = @gateway.refund(@amount+1, authorization)
    assert_failure response
    assert_equal 'Only $2.0 available for refund', response.message
  end

  def test_invalid_login
    gateway = NabTransactGateway.new(
                :login => 'ABCFAKE',
                :password => 'changeit'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid merchant ID', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Successful', response.message
  end

  def test_unsuccessful_store
    assert response = @gateway.store(@declined_card)
    assert_failure response
    assert_equal 'Invalid Credit Card Number', response.message
  end

  def test_duplicate_store
    @gateway.unstore(1236)

    assert response = @gateway.store(@credit_card, {:billing_id => 1236})
    assert_success response
    assert_equal 'Successful', response.message

    assert response = @gateway.store(@credit_card, {:billing_id => 1236})
    assert_failure response
    assert_equal 'Duplicate CRN Found', response.message
  end

  def test_unstore
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'Successful', response.message

    assert card_id = response.authorization
    assert unstore_response = @gateway.unstore(card_id)
    assert_success unstore_response
    assert_equal "Successful", unstore_response.message
  end

  def test_successful_purchase_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'Successful', response.message

    purchase_response = @gateway.purchase(12000, response.authorization)
    assert_success purchase_response
    assert_equal 'Approved', purchase_response.message
  end

  def test_failure_trigger_purchase
    gateway_id = '1234'
    trigger_amount = 0
    @gateway.unstore(gateway_id)

    assert response = @gateway.store(@credit_card, {:billing_id => gateway_id, :amount => 150})
    assert_success response
    assert_equal 'Successful', response.message

    purchase_response = @gateway.purchase(trigger_amount, gateway_id)

    assert gateway_id = purchase_response.params["crn"]
    assert_failure purchase_response
    assert_equal 'Invalid Amount', purchase_response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

end
