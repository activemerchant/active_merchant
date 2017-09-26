require 'test_helper'

class RemoteCredoraxTest < Test::Unit::TestCase
  def setup
    @gateway = CredoraxGateway.new(fixtures(:credorax))

    @amount = 100
    @credit_card = credit_card('4176661000001015', verification_value: "281", month: "12", year: "2017")
    @declined_card = credit_card('4176661000001015', verification_value: "000", month: "12", year: "2017")
    @options = {
      order_id: "1",
      currency: "EUR",
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_invalid_login
    gateway = CredoraxGateway.new(merchant_id: "", cipher_key: "")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "1", response.params["H9"]
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Do not Honour", response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Do not Honour", response.message
  end

  def test_failed_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(0, auth.authorization)
    assert_failure capture
    assert_equal "Invalid amount", capture.message
  end

  def test_successful_purchase_and_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_successful_authorize_and_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_successful_capture_and_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message

    void = @gateway.void(capture.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_failed_void
    response = @gateway.void("")
    assert_failure response
    assert_equal "Internal server error. Please contact Credorax support.", response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
  end

  def test_successful_refund_and_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message

    void = @gateway.void(refund.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, "123;123;123")
    assert_failure response
    assert_equal "Internal server error. Please contact Credorax support.", response.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_credit
    response = @gateway.credit(0, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid amount", response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "Do not Honour", response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  # #########################################################################
  # # CERTIFICATION SPECIFIC REMOTE TESTS
  # #########################################################################
  #
  # # Send [a5] currency code parameter as "AFN"
  # def test_certification_error_unregistered_currency
  #   @options[:echo] = "33BE888"
  #   @options[:currency] = "AFN"
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
  #
  # # Send [b2] parameter as "6"
  # def test_certification_error_unregistered_card
  #   @options[:echo] = "33BE889"
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
  #
  # # In the future, merchant expected to investigate each such case offline.
  # def test_certification_error_no_response_from_the_gate
  #   @options[:echo] = "33BE88A"
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
  #
  # # Merchant is expected to verify if the code is "0" - in this case the
  # # transaction should be considered approved. In all other cases the
  # # offline investigation should take place.
  # def test_certification_error_unknown_result_code
  #   @options[:echo] = "33BE88B"
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
  #
  # # Merchant is expected to verify if the code is "00" - in this case the
  # # transaction should be considered approved. In all other cases the
  # # transaction is declined. The exact reason should be investigated offline.
  # def test_certification_error_unknown_response_reason_code
  #   @options[:echo] = "33BE88C"
  #   @options[:email] = "brucewayne@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Gotham Drive",
  #     city: "Toronto",
  #     zip: "B2M 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800)228626"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Bruce",
  #                              last_name: "Wayne")
  #
  #   response = @gateway.purchase(@amount, credit_card, @options)
  #   assert_failure response
  # end
  #
  # # All fields marked as mandatory are expected to be populated with the
  # # above default values. Mandatory fields with no values on the
  # # certification template should be populated with your own meaningful
  # # values and comply with our API specifications. The d2 parameter is
  # # mandatory during certification only to allow for tracking of tests.
  # # Expected result of this test: Time out
  # def test_certification_time_out
  #   @options[:echo] = "33BE88D"
  #   @options[:email] = "brucewayne@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Gotham Drive",
  #     city: "Toronto",
  #     zip: "B2M 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800)228626"
  #   }
  #
  #   credit_card = credit_card('5473470000000010',
  #                              brand: "master",
  #                              verification_value: "939",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Bruce",
  #                              last_name: "Wayne")
  #
  #   response = @gateway.purchase(@amount, credit_card, @options)
  #   assert_failure response
  # end
  #
  # # All fields marked as mandatory are expected to be populated
  # # with the above default values. Mandatory fields with no values
  # # on the certification template should be populated with your
  # # own meaningful values and comply with our API specifications.
  # # The d2 parameter is mandatory during certification only to
  # # allow for tracking of tests.
  # def test_certification_za_zb_zc
  #   @options[:echo] = "33BE88E"
  #   @options[:email] = "brucewayne@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Gotham Drive",
  #     city: "Toronto",
  #     zip: "B2M 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800)228626"
  #   }
  #
  #   credit_card = credit_card('5473470000000010',
  #                              verification_value: "939",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Bruce",
  #                              last_name: "Wayne")
  #
  #   purchase = @gateway.purchase(@amount, credit_card, @options)
  #   assert_success purchase
  #   assert_equal "Succeeded", purchase.message
  #
  #   refund_options = {echo: "33BE892"}
  #   refund = @gateway.refund(@amount, purchase.authorization, refund_options)
  #   assert_success refund
  #   assert_equal "Succeeded", refund.message
  #
  #   void_options = {echo: "33BE895"}
  #   void = @gateway.void(refund.authorization, void_options)
  #   assert_success void
  #   assert_equal "Succeeded", refund.message
  # end
  #
  # # All fields marked as mandatory are expected to be populated
  # # with the above default values. Mandatory fields with no values
  # # on the certification template should be populated with your
  # # own meaningful values and comply with our API specifications.
  # # The d2 parameter is mandatory during certification only to
  # # allow for tracking of tests.
  # def test_certification_zg_zh
  #   @options[:echo] = "33BE88F"
  #   @options[:email] = "clark.kent@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "2020 Krypton Drive",
  #     city: "Toronto",
  #     zip: "S2M 1YR",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800) 78737626"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Clark",
  #                              last_name: "Kent")
  #
  #   response = @gateway.authorize(@amount, credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  #
  #   capture_options = {echo: "33BE890"}
  #   capture = @gateway.capture(@amount, response.authorization, capture_options)
  #   assert_success capture
  #   assert_equal "Succeeded", capture.message
  # end
  #
  # # All fields marked as mandatory are expected to be populated
  # # with the above default values. Mandatory fields with no values
  # # on the certification template should be populated with your
  # # own meaningful values and comply with our API specifications.
  # # The d2 parameter is mandatory during certification only to
  # # allow for tracking of tests.
  # def test_certification_zg_zj
  #   @options[:echo] = "33BE88F"
  #   @options[:email] = "clark.kent@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "2020 Krypton Drive",
  #     city: "Toronto",
  #     zip: "S2M 1YR",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800) 78737626"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Clark",
  #                              last_name: "Kent")
  #
  #   response = @gateway.authorize(@amount, credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  #
  #   auth_void_options = {echo: "33BE891"}
  #   auth_void = @gateway.void(response.authorization, auth_void_options)
  #   assert_success auth_void
  #   assert_equal "Succeeded", auth_void.message
  # end
  #
  # # All fields marked as mandatory are expected to be populated
  # # with the above default values. Mandatory fields with no values
  # # on the certification template should be populated with your
  # # own meaningful values and comply with our API specifications.
  # # The d2 parameter is mandatory during certification only to
  # # allow for tracking of tests.
  # #
  # # Certification for independent credit (credit)
  # def test_certification_zd
  #   @options[:echo] = "33BE893"
  #   @options[:email] = "wadewilson@marvel.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Deadpool Drive",
  #     city: "Toronto",
  #     zip: "D2P 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "+1(555)123-4567"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Wade",
  #                              last_name: "Wilson")
  #
  #   response = @gateway.credit(@amount, credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  # end
  #
  # # Use the above values to fill the mandatory parameters in your
  # # certification test transactions. Note:The d2 parameter is only
  # # mandatory during certification to allow for tracking of tests.
  # #
  # # Certification for purchase void
  # def test_certification_zf
  #   @options[:echo] = "33BE88E"
  #   @options[:email] = "brucewayne@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Gotham Drive",
  #     city: "Toronto",
  #     zip: "B2M 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800)228626"
  #   }
  #
  #   credit_card = credit_card('5473470000000010',
  #                              verification_value: "939",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Bruce",
  #                              last_name: "Wayne")
  #
  #   response = @gateway.purchase(@amount, credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  #
  #   void_options = {echo: "33BE894"}
  #   void = @gateway.void(response.authorization, void_options)
  #   assert_success void
  #   assert_equal "Succeeded", void.message
  # end
  #
  # # Use the above values to fill the mandatory parameters in your
  # # certification test transactions. Note:The d2 parameter is only
  # # mandatory during certification to allow for tracking of tests.
  # #
  # # Certification for capture void
  # def test_certification_zi
  #   @options[:echo] = "33BE88F"
  #   @options[:email] = "clark.kent@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "2020 Krypton Drive",
  #     city: "Toronto",
  #     zip: "S2M 1YR",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800) 78737626"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Clark",
  #                              last_name: "Kent")
  #
  #   authorize = @gateway.authorize(@amount, credit_card, @options)
  #   assert_success authorize
  #   assert_equal "Succeeded", authorize.message
  #
  #   capture_options = {echo: "33BE890"}
  #   capture = @gateway.capture(@amount, authorize.authorization, capture_options)
  #   assert_success capture
  #   assert_equal "Succeeded", capture.message
  #
  #   void_options = {echo: "33BE896"}
  #   void = @gateway.void(capture.authorization, void_options)
  #   assert_success void
  #   assert_equal "Succeeded", void.message
  # end
end
