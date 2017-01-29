require 'test_helper'

class RemoteNetbanxTest < Test::Unit::TestCase
  def setup
    @gateway = NetbanxGateway.new(fixtures(:netbanx))

    @amount = 100
    @credit_card = credit_card('4530910000012345')
    @declined_amount = 11
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert_equal response.authorization, response.params['id']
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: SecureRandom.uuid,
      ip: "127.0.0.1",
      billing_address: address,
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_equal 'OK', response.message
    assert_equal response.authorization, response.params['id']
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card has been declined due to insufficient funds.', response.message
  end

  def test_successful_authorize
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card has been declined due to insufficient funds.', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'OK', capture.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, SecureRandom.uuid)
    assert_failure response
    assert_equal 'The authorization ID included in this settlement request could not be found.', response.message
  end

  # def test_successful_refund
  #   # Unfortunately when testing a refund, you need to wait until the transaction
  #   # if batch settled by the test system, this can take up to 2h.
  #   # This is the reason why these tests are commented out. You can run them
  #   # manually once you have batched/completed transactions.
  #   #
  #   # Otherwise you will get an error like:
  #   # You tried a credit transaction for a settlement that has not been batched,
  #   # so there is no balance available to be credited. A settlement is typically
  #   # in a pending state until midnight of the day that it is requested, at
  #   # which point it is batched. You cannot credit that settlement until it has
  #   # been batched. Verify the credit card for which you are attempting the
  #   # credit, and retry the transaction. Otherwise, wait until the settlement
  #   # has been batched and retry the transaction.

  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth

  #   assert capture = @gateway.capture(@amount, auth.authorization)
  #   assert_success capture

  #   # replace this with the transaction that you can verify via the back-office
  #   # or API that it's in `completed` state. And use this in the refund
  #   # call below
  #   # authorization = "fd5d6776-29b7-4108-b98a-7a4603db9ff0"

  #   assert refund = @gateway.refund(@amount, authorization)
  #   assert_success refund
  #   assert_equal 'OK', refund.message
  # end

  # def test_partial_refund
  #   # Read comment in `test_successful_refund` method.
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth

  #   assert capture = @gateway.capture(@amount, auth.authorization)
  #   assert_success capture

  #   # replace this with the transaction that you can verify via the back-office
  #   # or API that it's in `completed` state. And use this in the refund
  #   # call below
  #   # authorization = "REPLACE-ME"

  #   assert refund = @gateway.refund(@amount-1, capture.authorization)
  #   assert_success refund
  #   assert_equal 'OK', refund.message
  # end

  def test_failed_refund
    # Read comment in `test_successful_refund` method.
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    # the following shall fail if you run it immediately after the capture
    # as noted in the comment from `test_successful_refund`
    assert refund = @gateway.refund(@amount, capture.authorization)
    assert_failure refund
    assert_equal 'The settlement you are attempting to refund has not been batched yet. There are no settled funds available to refund.', refund.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'OK', void.message
  end

  def test_failed_void
    response = @gateway.void(SecureRandom.uuid)
    assert_failure response
    assert_equal 'The confirmation number included in this request could not be found.', response.message
  end

  def test_invalid_login
    gateway = NetbanxGateway.new(api_key: 'foobar', account_number: '12345')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid Login}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(Base64.strict_encode64(@gateway.options[:api_key]).strip, transcript)
  end

  def test_successful_store
    merchant_customer_id = SecureRandom.hex
    assert response = @gateway.store(@credit_card, locale: 'en_GB', merchant_customer_id: merchant_customer_id, email: "email@example.com")
    assert_success response
    assert_equal merchant_customer_id, response.params["merchantCustomerId"]
    first_card = response.params["cards"].first
    assert_equal @credit_card.last_digits, first_card["lastDigits"]
  end

  def test_successful_unstore
    merchant_customer_id = SecureRandom.hex
    assert response = @gateway.store(@credit_card, locale: 'en_GB', merchant_customer_id: merchant_customer_id, email: "email@example.com")
    assert_success response
    assert_equal merchant_customer_id, response.params["merchantCustomerId"]
    first_card = response.params["cards"].first
    assert_equal @credit_card.last_digits, first_card["lastDigits"]
    identification = "#{response.params['id']}|#{first_card['id']}"
    assert unstore_card = @gateway.unstore(identification)
    assert_success unstore_card
    assert unstore_profile = @gateway.unstore(response.params['id'])
    assert_success unstore_profile
  end

  def test_successful_purchase_using_stored_card
    merchant_customer_id = SecureRandom.hex
    assert store = @gateway.store(@credit_card, @options.merge({locale: 'en_GB', merchant_customer_id: merchant_customer_id, email: 'email@example.com'}))
    assert_success store

    assert response = @gateway.purchase(@amount, store.authorization.split('|').last)
    assert_success response
    assert_equal "OK", response.message
  end
end
