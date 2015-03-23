require 'test_helper'

class RemoteFlo2cashTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = Flo2cashGateway.new(fixtures(:flo2cash))

    @amount = 100
    @credit_card = credit_card('5123456789012346', brand: :master, month: 5, year: 2017, verification_value: 111)
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_invalid_login
    gateway = Flo2cashGateway.new(
      username: 'N/A',
      password: 'N/A',
      account_id: '100'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Authentication error. Username and/or Password are incorrect", response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction Declined - Bank Error', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.responses.first.error_code
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\w+$), response.authorization

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction Declined - Bank Error', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal "Original transaction not found", response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal "Original transaction not found", response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
