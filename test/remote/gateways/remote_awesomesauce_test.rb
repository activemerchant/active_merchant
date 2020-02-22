require 'test_helper'

class RemoteAwesomesauceTest < Test::Unit::TestCase
  def setup
    @gateway = AwesomesauceGateway.new(fixtures(:awesomesauce))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @options = {}
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    puts response
    assert_success response
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
  
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(102, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    print auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(101, @credit_card, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(110, '')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end


  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(100, @credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    response = @gateway.verify(103, @credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret], transcript)
  end

end
