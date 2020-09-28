require "test_helper"

class RemoteLatitude19Test < Test::Unit::TestCase
  def setup
    @gateway = Latitude19Gateway.new(fixtures(:latitude19))

    @amount = 100
    @credit_card = credit_card("4000100011112224", verification_value: "747")
    @declined_card = credit_card("0000000000000000")

    @options = {
      order_id: generate_unique_id,
      billing_address: address
    }
  end

  def test_invalid_login
    gateway = Latitude19Gateway.new(account_number: "", configuration_id: "", secret: "")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Approved", response.message
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
    assert_equal "Approved", response.message
    assert_match %r(^auth\|\w+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization, @options)
    assert_success capture
    assert_equal "Approved", capture.message
  end

  # def test_failed_authorize
  #   response = @gateway.authorize(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  #   assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  # end

  def test_failed_capture
    authorization = "auth" + "|" + SecureRandom.hex(6)
    response = @gateway.capture(@amount, authorization, @options)
    assert_failure response
    assert_equal "Not submitted", response.message
    assert_equal "400", response.error_code
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal "Approved", void.message

    # response = @gateway.authorize(@amount, @credit_card, @options)
    # assert_success response
    # assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", response.message

    # capture = @gateway.capture(@amount, response.authorization, @options)
    # assert_success capture
    # assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", capture.message

    # void = @gateway.void(capture.authorization, @options)
    # assert_success void
    # assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", void.message

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal "Approved", void.message
  end

  def test_failed_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    authorization = auth.authorization[0..9] + "XX"
    response = @gateway.void(authorization, @options)

    assert_failure response
    assert_equal "Not submitted", response.message
    assert_equal "400", response.error_code
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Approved", response.message
  end

  # def test_failed_credit
  #   response = @gateway.credit(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  # end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "Approved", response.message
  end

  # def test_failed_verify
  #   response = @gateway.verify(@declined_card, @options)
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  #   assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  # end

  def test_successful_store
    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal "Approved", store.message

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert_equal "Approved", purchase.message

    credit = @gateway.credit(@amount, store.authorization, @options)
    assert_success credit
    assert_equal "Approved", credit.message

    verify = @gateway.verify(store.authorization, @options)
    assert_success verify
    assert_equal "Approved", verify.message
  end

  # def test_failed_store
  #   response = @gateway.store(@declined_card, @options)
  #   assert_failure response
  #   assert_equal "REPLACE WITH FAILED MESSAGE", response.message
  #   assert_equal "REPLACE WITH FAILED CODE", response.params["error"]
  # end

  # def test_dump_transcript
  #   #skip("Transcript scrubbing for this gateway has been tested.")

  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:secret], clean_transcript)
  end
end
