require 'test_helper'

class RemoteFlo2cashSimpleTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = Flo2cashSimpleGateway.new(fixtures(:flo2cash_simple))

    @amount = 100
    @credit_card = credit_card('5123456789012346', brand: :master, month: 5, year: 2017, verification_value: 111 )
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_invalid_login
    gateway = Flo2cashSimpleGateway.new(
      username: 'N/A',
      password: 'N/A',
      account_id: '100'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Authentication error. Username and/or Password are incorrect", response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction Declined - Bank Error', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
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
