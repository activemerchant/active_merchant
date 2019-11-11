require 'test_helper'

class RemoteSquareTest < Test::Unit::TestCase
  def setup
    @gateway = SquareGateway.new(fixtures(:square))

    @amount = 200
    @refund_amount = 100

    @card_nonce = 'cnon:card-nonce-ok'
    @declined_card_nonce = 'cnon:card-nonce-declined'

    @options = {
      reason: 'Customer Canceled',
    }

    @customer = {
      given_name: 'John',
      family_name: 'Doe',
      company_name: 'John Doe Inc',
      email_address: 'john.doe@example.com',
      phone_number: '1231231234',
      address: {
        address_line_1: '123 Main St.',
        address_line_2: 'Apt 2A',
        address_line_3: 'Att John Doe',
        locality: 'Chicago',
        administrative_district_level_1: 'Illinois',
        administrative_district_level_2: 'United States',
        postal_code: '94103'
      }
    }
  end

  def test_successful_authorize
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert authorization = @gateway.authorize(@amount, @card_nonce, @options)
    assert_success authorization
    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_unsuccessful_authorize
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert authorization = @gateway.authorize(@amount, @declined_card_nonce, @options)
    assert_failure authorization
    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_successful_authorize_then_capture
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert authorization = @gateway.authorize(@amount, @card_nonce, @options)
    assert_success authorization

    assert capture = @gateway.capture(authorization.authorization)
    assert_success capture
    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_successful_authorize_then_void
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert authorization = @gateway.authorize(@amount, @card_nonce, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization, @options)
    assert_success void
    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_successful_purchase
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert purchase = @gateway.purchase(@amount, @card_nonce, @options)
    assert_success purchase
    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_unsuccessful_purchase
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert purchase = @gateway.purchase(@amount, @declined_card_nonce, @options)
    assert_failure purchase
    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_successful_purchase_then_refund
    @options[:idempotency_key] = SecureRandom.hex(10)
    assert purchase = @gateway.purchase(@amount, @card_nonce, @options)
    assert_success purchase

    sleep 2

    @options[:idempotency_key] = SecureRandom.hex(10)
    assert refund = @gateway.refund(@refund_amount, purchase.authorization, @options)
    assert_success refund

    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_successful_store
    @options[:customer] = @customer

    assert store = @gateway.store(@card_nonce, @options)
    pp store
    # assert_success store
    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  #
  # def test_successful_purchase_with_more_options
  #   options = {
  #     order_id: '1',
  #     ip: "127.0.0.1",
  #     email: "joe@example.com"
  #   }
  #
  #   response = @gateway.purchase(@amount, @credit_card, options)
  #   assert_success response
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  # end
  #
  # def test_failed_purchase
  #   response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end
  #
  # def test_successful_authorize_and_capture
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #
  #   assert capture = @gateway.capture(@amount, auth.authorization)
  #   assert_success capture
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', capture.message
  # end
  #
  # def test_failed_authorize
  #   response = @gateway.authorize(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED AUTHORIZE MESSAGE', response.message
  # end
  #
  # def test_partial_capture
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #
  #   assert capture = @gateway.capture(@amount-1, auth.authorization)
  #   assert_success capture
  # end
  #
  # def test_failed_capture
  #   response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED CAPTURE MESSAGE', response.message
  # end
  #
  # def test_successful_refund
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase
  #
  #   assert refund = @gateway.refund(@amount, purchase.authorization)
  #   assert_success refund
  #   assert_equal 'REPLACE WITH SUCCESSFUL REFUND MESSAGE', refund.message
  # end
  #
  # def test_partial_refund
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase
  #
  #   assert refund = @gateway.refund(@amount-1, purchase.authorization)
  #   assert_success refund
  # end
  #
  # def test_failed_refund
  #   response = @gateway.refund(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
  # end
  #
  # def test_successful_void
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #
  #   assert void = @gateway.void(auth.authorization)
  #   assert_success void
  #   assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', void.message
  # end
  #
  # def test_failed_void
  #   response = @gateway.void('')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  # end
  #
  # def test_successful_verify
  #   response = @gateway.verify(@credit_card, @options)
  #   assert_success response
  #   assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  # end
  #
  # def test_failed_verify
  #   response = @gateway.verify(@declined_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  # end
  #
  # def test_invalid_login
  #   gateway = SquareGateway.new(login: '', password: '')
  #
  #   response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED LOGIN MESSAGE}, response.message
  # end
  #
  # def test_dump_transcript
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic.  You can delete
  #   # this helper after completing your scrub implementation.
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end
  #
  # def test_transcript_scrubbing
  #   transcript = capture_transcript(@gateway) do
  #     @gateway.purchase(@amount, @credit_card, @options)
  #   end
  #   transcript = @gateway.scrub(transcript)
  #
  #   assert_scrubbed(@credit_card.number, transcript)
  #   assert_scrubbed(@credit_card.verification_value, transcript)
  #   assert_scrubbed(@gateway.options[:password], transcript)
  # end

end
