require 'test_helper'

class RemoteHiPayTest < Test::Unit::TestCase
  def setup
    @gateway = HiPayGateway.new(fixtures(:hi_pay))
    @bad_gateway = HiPayGateway.new(username: 'bad', password: 'password')

    @amount = 500
    @credit_card = credit_card('4111111111111111', verification_value: '514', first_name: 'John', last_name: 'Smith', month: 12, year: 2025)
    @bad_credit_card = credit_card('5144144373781246')
    @master_credit_card = credit_card('5399999999999999')

    @options = {
      order_id: "Sp_ORDER_#{SecureRandom.random_number(1000000000)}",
      description: 'An authorize',
      email: 'john.smith@test.com'
    }

    @billing_address = address
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal response.message, 'Authorized'
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_include 'Captured', response.message

    assert_kind_of MultiResponse, response
    assert_equal 2, response.responses.size
  end

  def test_successful_purchase_with_mastercard
    response = @gateway.purchase(@amount, @master_credit_card, @options)
    assert_success response
    assert_include 'Captured', response.message

    assert_kind_of MultiResponse, response
    assert_equal 2, response.responses.size
  end

  def test_failed_purchase_due_failed_tokenization
    response = @bad_gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_include 'Incorrect Credentials _ Username and/or password is incorrect', response.message
    assert_include '1000001', response.error_code

    assert_kind_of MultiResponse, response
    # Failed in tokenization step
    assert_equal 1, response.responses.size
  end

  def test_failed_purchase_due_authentication_requested
    response = @gateway.purchase(@amount, @bad_credit_card, @options)
    assert_failure response
    assert_include 'Authentication requested', response.message
    assert_include '1000001', response.error_code

    assert_kind_of MultiResponse, response
    # Complete tokenization, failed in the purhcase step
    assert_equal 2, response.responses.size
  end

  def test_successful_purchase_with_billing_address
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ billing_address: @billing_address }))

    assert_success response
    assert_equal response.message, 'Captured'
  end

  def test_successful_capture
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_response
    assert_include 'Authorized', authorize_response.message

    response = @gateway.capture(@amount, authorize_response.authorization, @options)
    assert_success response
    assert_include 'Captured', response.message
    assert_equal authorize_response.authorization, response.authorization
  end

  def test_successful_authorize_with_store
    store_response = @gateway.store(@credit_card, @options)
    assert_nil store_response.message
    assert_success store_response
    assert_not_empty store_response.authorization

    response = @gateway.authorize(@amount, store_response.authorization, @options)
    assert_success response
    assert_include 'Authorized', response.message
  end

  def test_successful_multiple_purchases_with_single_store
    store_response = @gateway.store(@credit_card, @options)
    assert_nil store_response.message
    assert_success store_response
    assert_not_empty store_response.authorization

    response1 = @gateway.purchase(@amount, store_response.authorization, @options)
    assert_success response1
    assert_include 'Captured', response1.message

    @options[:order_id] = "Sp_ORDER_2_#{SecureRandom.random_number(1000000000)}"

    response2 = @gateway.purchase(@amount, store_response.authorization, @options)
    assert_success response2
    assert_include 'Captured', response2.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end
end
