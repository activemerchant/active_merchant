require 'test_helper'

class CashnetTest < Test::Unit::TestCase
  def setup
    @gateway = CashnetGateway.new(fixtures(:cashnet))
    @amount = 100
    @credit_card = credit_card(
      '5454545454545454',
      month: 12,
      year: Time.new.year + 1
    )
    @options = {
      order_id: generate_unique_id,
      billing_address: address
    }
  end

  def test_successful_purchase
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.test?
    assert_equal 'Success', purchase.message
  end

  def test_successful_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.test?
    assert_equal 'Success', purchase.message
    assert purchase.authorization

    assert refund = @gateway.refund(@amount, purchase.authorization, {})
    assert_success refund
    assert refund.test?
    assert_equal 'Success', refund.message
  end

  def test_successful_refund_with_options
    assert purchase = @gateway.purchase(@amount, @credit_card, custcode: 'TheCustCode')
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, email: 'wow@example.com', custcode: 'TheCustCode')
    assert_success refund
  end

  def test_failed_purchase
    assert response = @gateway.purchase(-44, @credit_card, @options)
    assert_failure response
    assert_match %r{Negative amount is not allowed}, response.message
    assert_equal '5', response.params['result']
  end

  def test_failed_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount + 50, purchase.authorization)
    assert_failure refund
    assert_match %r{Amount to refund exceeds}, refund.message
    assert_equal '302', refund.params['result']
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
