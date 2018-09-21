require 'test_helper'

class RemoteBeanstreamIppTest < Test::Unit::TestCase
  def setup
    @ipp_options = fixtures(:ipp)
    @ipp_options[:region] = :pacific
    @gateway = BeanstreamGateway.new(@ipp_options)

    @credit_card_visa = credit_card('4005550000000001')

    @credit_card_visa_declined = credit_card('4123456789010053')

    @credit_card_mastercard = credit_card('5123456789012346')

    @credit_card_mastercard_declined = credit_card('5123456789010043')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
    }

    @amount = 200
    @amount_fail = 105
  end

  def test_dump_transcript
    skip('Transcript scrubbing for this gateway has been tested.')
    dump_transcript_and_fail(@gateway, @amount, @credit_card_visa, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card_visa, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card_visa.number, transcript)
    assert_scrubbed(@credit_card_visa.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card_visa, @options)

    assert_success response
    assert_equal '', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card_visa_declined, @options)

    assert_failure response
    assert_equal 'Do Not Honour', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_purchase_mastercard
    response = @gateway.purchase(@amount, @credit_card_mastercard, @options)
    assert_success response
    assert_equal '', response.message
  end

  def test_failed_purchase_mastercard
    response = @gateway.purchase(@amount, @credit_card_mastercard_declined, @options)

    assert_failure response
    assert_equal 'Pick Up Card', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:pickup_card], response.error_code
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card_visa, @options)
    assert_success response
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount_fail, @credit_card_visa, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card_visa, @options)
    response = @gateway.refund(@amount, response.authorization, @options)
    assert_success response
    assert_equal '', response.message
  end

  def test_failed_refund
    response = @gateway.purchase(@amount, @credit_card_visa, @options)
    response = @gateway.refund(300, response.authorization, @options)
    assert_failure response
    assert_equal 'Refund amount exceeds original purchase or capture plus any previous refund total', response.message
  end

  def test_invalid_login
    gateway = BeanstreamGateway.new(
      login: '',
      username: '',
      password: '',
      region: :pacific
    )

    options_test = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
    }

    response = gateway.purchase(@amount, @credit_card_visa, options_test)
    assert_failure response
  end
end
