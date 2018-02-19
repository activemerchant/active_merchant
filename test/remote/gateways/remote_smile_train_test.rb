require 'test_helper'

class RemoteSmileTrainTest < Test::Unit::TestCase
  def setup
    @gateway = SmileTrainGateway.new(fixtures(:smile_train))

    @amount = 500
    @declined_amount = 200000
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000111111111115')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      first_name: 'Longjane',
      last_name: 'Longsen',
      email: "jane@example.com",
      submitted_by: 'John Doe'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Donation has been processed.', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge(
      email_subscription: true,
      mail_subscription: true,
      mobile_subscription: true,
      phone_subscription: true,
      gift_aid_choice: true,
      gender: 'Female',
      dob: '1960-01-01',
      submitted_by: 'John Doe',
      mailcode: 'A123456YYYZZZ'
    )
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Donation has been processed.', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Donation has been failed.', response.message
  end

  def test_invalid_login
    gateway = SmileTrainGateway.new(email: '', token: '')

    assert_raises(ActiveMerchant::ResponseError) do
      gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    token = Base64.strict_encode64("#{@options[:email]}:#{@options[:token]}")

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(token, transcript)
  end

end
