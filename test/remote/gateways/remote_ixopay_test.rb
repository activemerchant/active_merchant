require 'test_helper'

class RemoteIxopayTest < Test::Unit::TestCase
  def setup
    @gateway = IxopayGateway.new(fixtures(:ixopay))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000300011112220')

    @options = {
      billing_address: address,
      shipping_address: address,
      email: 'test@example.com',
      description: 'Store Purchase',
      ip: '192.168.1.1',
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'FINISHED', response.message
    assert_match(/[0-9a-zA-Z]+(|[0-9a-zA-Z]+)*/, response.authorization)

    assert_equal @credit_card.name,           response.params.dig('return_data', 'creditcard_data', 'card_holder')
    assert_equal '%02d' % @credit_card.month, response.params.dig('return_data', 'creditcard_data', 'expiry_month')
    assert_equal @credit_card.year.to_s,      response.params.dig('return_data', 'creditcard_data', 'expiry_year')
    assert_equal @credit_card.number[0..5],   response.params.dig('return_data', 'creditcard_data', 'first_six_digits')
    assert_equal @credit_card.number.split(//).last(4).join, response.params.dig('return_data', 'creditcard_data', 'last_four_digits')
    assert_equal 'FINISHED',                  response.params['return_type']

    assert_not_nil response.params['purchase_id']
    assert_not_nil response.params['reference_id']
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, {})

    assert_failure response
    assert_equal 'The transaction was declined', response.message
    assert_equal '2003', response.error_code
  end

  def test_failed_authentication
    gateway = IxopayGateway.new(username: 'baduser', password: 'badpass', secret: 'badsecret')
    response = gateway.purchase(@amount, @credit_card, {})

    assert_failure response

    assert_equal 'Invalid Signature: Invalid authorization header', response.message
    assert_equal '1004', response.error_code
  end

  def test_successful_authorize#_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'FINISHED', auth.message
    assert_not_nil auth.params['purchase_id']
    assert_not_nil auth.params['reference_id']
    assert_not_nil auth.authorization

    #assert capture = @gateway.capture(@amount, auth.authorization)
    #assert_success capture
    #assert_equal 'REPLACE WITH SUCCESS MESSAGE', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The transaction was declined', response.message
    assert_equal 'ERROR',                        response.params['return_type']
    assert_equal '2003', response.error_code
  end

  def test_partial_capture
    omit 'Not yet implemented'

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    omit 'Not yet implemented'

    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED CAPTURE MESSAGE', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'FINISHED', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, nil)
    assert_failure response
    assert_equal 'Transaction of type "refund" requires a referenceTransactionId', response.message
  end

  def test_successful_void
    omit 'Not yet implemented'

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', void.message
  end

  def test_failed_void
    omit 'Not yet implemented'

    response = @gateway.void('')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  end

  def test_successful_verify
    omit 'Not yet implemented'

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  end

  def test_failed_verify
    omit 'Not yet implemented'

    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  end

  def test_invalid_login
    omit 'Not yet implemented'

    gateway = IxopayGateway.new(login: '', password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{REPLACE WITH FAILED LOGIN MESSAGE}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end

    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
