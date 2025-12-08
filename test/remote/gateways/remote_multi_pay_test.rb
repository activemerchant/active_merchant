require 'test_helper'

class RemoteMultiPayTest < Test::Unit::TestCase
  def setup
    @gateway = MultiPayGateway.new(fixtures(:multi_pay))

    @amount = 100
    @credit_card = credit_card('5413330089020516', month: 1, year: 2030, verification_value: '111')
    @declined_card = credit_card('4000000000000002')
    @options = {
      order_id: SecureRandom.hex(16),
      billing_address: address,
      email: 'customer@example.com'
    }
  end

  def test_successful_authorization
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'APROBADA (00)', response.message
  end

  def test_authorization_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'APROBADA (00)', response.message

    @options[:order_id] = SecureRandom.hex(16)

    capture_response = @gateway.capture(@amount, response.authorization, @options)
    assert_success capture_response
    assert_equal 'APROBADA (00)', capture_response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'APROBADA (00)', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{NO HAY TAL EMISOR}i, response.message
  end

  def test_invalid_login
    error = assert_raises(ActiveMerchant::OAuthResponseError) do
      gateway = MultiPayGateway.new(
        company: '123456',
        branch: 'branch_name',
        pos: 'terminal_id',
        user: 'username',
        password: 'password'
      )
      gateway.purchase(@amount, @credit_card, @options)
    end

    assert_match(/401/, error.message)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
  end
end
