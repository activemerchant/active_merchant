require 'test_helper'

class RemoteCardPointeTest < Test::Unit::TestCase
  def setup
    @gateway = CardPointeGateway.new(fixtures(:card_pointe))
    @merchid = fixtures(:card_pointe)[:merchid]

    @amount = 100
    @credit_card = credit_card('6011361000006668')
    @update_card = credit_card('4761739001010010')
    @expired_card = credit_card('6011361000006668',
      :month => '12',
      :year  => '2000'
    )
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_more_options
    options = @options.merge(
      :order_id => generate_unique_id,
      :ip => '127.0.0.1',
      :email => 'joe@example.com'
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(112400, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    # assert_equal 'Wrong expiration', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    response = @gateway.authorize(155400, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert_equal 'Over daily limit', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
    assert_equal '0.99', capture.params['amount']
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
    assert_equal '0.99', refund.params['amount']
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
    assert_equal 'Txn not found', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
    assert_equal 'Invalid field', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal '0.00', response.params['amount']
  end

  def test_failed_verify
    response = @gateway.verify(@expired_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:expired_card], response.error_code
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_successful_store_and_purchase
    store = @gateway.store(@credit_card, @options)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
  end

  def test_successful_update
    store = @gateway.store(@credit_card, @options)
    assert_success store
    profileid, acctid = store.authorization.split('/')

    update = @gateway.update(store.authorization, @update_card, @options)
    assert_success update
    assert_equal profileid, update.params['profileid']
    assert_equal acctid, update.params['acctid']
  end

  def test_successful_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store

    unstore = @gateway.unstore(store.authorization, @options)
    assert_success unstore
  end

  def test_invalid_login
    gateway = CardPointeGateway.new(username: '', password: '', merchid: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Unauthorized}, response.message
  end

  def test_dump_transcript
    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic.  You can delete
    # this helper after completing your scrub implementation.
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    # assert_scrubbed(@credit_card.number, transcript)
    # assert_scrubbed(@credit_card.verification_value, transcript)
    # assert_scrubbed(@gateway.options[:password], transcript)
    assert_scrubbed('dGVzdGluZzp0ZXN0aW5nMTIz', transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@merchid, transcript)
    assert_scrubbed("#{@credit_card.month}/#{@credit_card.year}", transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

end
