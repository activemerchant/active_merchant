require "test_helper"

class RemoteLatitude19Test < Test::Unit::TestCase
  def setup
    @gateway = Latitude19Gateway.new(fixtures(:latitude19))

    @amount = 100
    @credit_card = credit_card("4000100011112224")
    @declined_card = credit_card("4000300011112220")

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: "Store Purchase"
    }
  end

  # def test_invalid_login
  #   gateway = Latitude19Gateway.new(login: "", password: "")
  #   response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response

  #   # Use this version if you need to capture a raised error.
  #   # authentication_exception = assert_raise ActiveMerchant::ResponseError do
  #   #   gateway.purchase(@amount, @credit_card, @options)
  #   # end
  #   # response = authentication_exception.response
  #   # assert_match(/Authentication error/, response.body)
  # end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", response.message
    assert response.test?
  end

  # def test_failed_purchase
  #   response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  # end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", response.message
    assert_match %r(^\w+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization, @options)
    assert_success capture
    assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", capture.message
  end

  # def test_failed_authorize
  #   response = @gateway.authorize(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  #   assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  # end

  # def test_failed_capture
  #   response = @gateway.capture(@amount, "")
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  #   assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  # end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_failed_void
    response = @gateway.void("")
    assert_failure response
    assert_equal "REPLACE WITH FAILED MESSAGE", response.message
    assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, "")
    assert_failure response
    assert_equal "REPLACE WITH FAILED MESSAGE", response.message
    assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", response.message
  end

  # def test_failed_credit
  #   response = @gateway.credit(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  # end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "pgwResponseCodeDescription|Approved|responseText|85 -- AVS ACCEPTED|processorResponseCode|85", response.message
  end

  # def test_failed_verify
  #   response = @gateway.verify(@declined_card, @options)
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  #   assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  # end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_store
    response = @gateway.store(@declined_card, @options)
    assert_failure response
    assert_equal "REPLACE WITH FAILED MESSAGE", response.message
    assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  end

  def test_dump_transcript
    #skip("Transcript scrubbing for this gateway has been tested.")

    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:password], clean_transcript)
  end
end
