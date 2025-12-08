require 'test_helper'

class RemoteNetbanxTest < Test::Unit::TestCase
  def setup
    @gateway = NetbanxGateway.new(fixtures(:netbanx))
    @amount = 100
    @credit_card = credit_card('4530910000012345')
    @credit_card_no_match_cvv = credit_card('4530910000012345', { verification_value: 666 })
    @declined_amount = 11
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      currency: 'CAD'
    }

    @options_3ds2 = @options.merge(
      three_d_secure: {
        version: '2.1.0',
        eci: '05',
        cavv: 'AAABCIEjYgAAAAAAlCNiENiWiV+=',
        ds_transaction_id: 'a3a721f3-b6fa-4cb5-84ea-c7b5c39890a2',
        xid: 'OU9rcTRCY1VJTFlDWTFESXFtTHU=',
        directory_response_status: 'Y'
      }
    )
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert_equal response.authorization, response.params['id']
    assert_equal 'MATCH', response.params['cvvVerification']
    assert_equal 'MATCH', response.params['avsResponse']
  end

  def test_successful_purchase_avs_no_match_cvv
    response = @gateway.purchase(@amount, @credit_card_no_match_cvv, @options)
    assert_success response
    assert_equal 'X', response.avs_result['code']
    assert_equal 'N', response.cvv_result['code']
  end

  def split_names(full_name)
    names = (full_name || '').split
    return [nil, nil] if names.size == 0

    last_name  = names.pop
    first_name = names.join(' ')
    [first_name, last_name]
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: SecureRandom.uuid,
      ip: '127.0.0.1',
      billing_address: address,
      email: 'joe@example.com'
    }

    first_name, last_name = split_names(address[:name])

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_equal 'OK', response.message
    assert_equal response.authorization, response.params['id']
    assert_equal first_name, response.params['profile']['firstName']
    assert_equal last_name, response.params['profile']['lastName']
    assert_equal options[:email], response.params['profile']['email']
    assert_equal options[:ip], response.params['customerIp']
  end

  def test_successful_purchase_with_3ds2_auth
    assert response = @gateway.purchase(@amount, @credit_card, @options_3ds2)
    assert_success response
    assert_equal 'OK', response.message
    assert_equal response.authorization, response.params['id']
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card has been declined due to insufficient funds.', response.message
  end

  def test_failed_verify_before_purchase
    options = {
      verification_value: ''
    }
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response
    assert_equal 'The zip/postal code must be provided for an AVS check request.', response.message
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

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'OK', capture.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, SecureRandom.uuid)
    assert_failure response
    assert_equal 'The authorization ID included in this settlement request could not be found.', response.message
  end

  def test_successful_authorize_and_capture_with_3ds2_auth
    auth = @gateway.authorize(@amount, @credit_card, @options_3ds2)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options_3ds2)
    assert_success capture
    assert_equal 'OK', capture.message
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

  # Changed test_failed_refund to test_cancelled_refund
  # Because We added the checking status. If the transactions that are pending, API call needs to be Cancellation
  def test_cancelled_refund
    # Read comment in `test_successful_refund` method.
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture

    # The settlement you are attempting to refund has not been batched yet. There are no settled funds available to refund.
    # So the following refund shall be cancelled if you run it immediately after the capture
    assert cancelled_response = @gateway.refund(@amount, capture.authorization)
    assert_success cancelled_response
    assert_equal 'CANCELLED', cancelled_response.params['status']
  end

  def test_reject_partial_refund_on_pending_status
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture

    assert rejected_response = @gateway.refund(90, capture.authorization)
    assert_failure rejected_response
    assert_equal 'Transaction not settled. Either do a full refund or try partial refund after settlement.', rejected_response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options)
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
    assert response = @gateway.store(@credit_card, locale: 'en_GB', merchant_customer_id:, email: 'email@example.com')
    assert_success response
    assert_equal merchant_customer_id, response.params['merchantCustomerId']
    first_card = response.params['cards'].first
    assert_equal @credit_card.last_digits, first_card['lastDigits']
  end

  def test_successful_unstore
    merchant_customer_id = SecureRandom.hex
    assert response = @gateway.store(@credit_card, locale: 'en_GB', merchant_customer_id:, email: 'email@example.com')
    assert_success response
    assert_equal merchant_customer_id, response.params['merchantCustomerId']
    first_card = response.params['cards'].first
    assert_equal @credit_card.last_digits, first_card['lastDigits']
    identification = "#{response.params['id']}|#{first_card['id']}"
    assert unstore_card = @gateway.unstore(identification)
    assert_success unstore_card
    assert unstore_profile = @gateway.unstore(response.params['id'])
    assert_success unstore_profile
  end

  def test_successful_purchase_using_stored_card
    merchant_customer_id = SecureRandom.hex
    assert store = @gateway.store(@credit_card, @options.merge({ locale: 'en_GB', merchant_customer_id:, email: 'email@example.com' }))
    assert_success store

    assert response = @gateway.purchase(@amount, store.authorization.split('|').last)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_verify
    verify = @gateway.verify(@credit_card, @options)
    assert_success verify
  end

  def test_failed_verify
    options = {
      verification_value: ''
    }
    verify = @gateway.verify(@credit_card, options)
    assert_failure verify
    assert_equal 'The zip/postal code must be provided for an AVS check request.', verify.message
  end

  def test_successful_cancel_settlement
    response = @gateway.purchase(@amount, @credit_card, @options)
    authorization = response.authorization

    assert cancelled_response = @gateway.refund(@amount, authorization)
    assert_success cancelled_response
    assert_equal 'CANCELLED', cancelled_response.params['status']
  end
end
