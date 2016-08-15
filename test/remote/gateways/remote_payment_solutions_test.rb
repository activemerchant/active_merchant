require 'test_helper'

class RemotePaymentSolutionsTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentSolutionsGateway.new(fixtures(:payment_solutions))

    @amount = 100
    @declined_amount = 200000
    @credit_card = credit_card('4111111111111111')
    @options = {
      order_id: SecureRandom.hex(10),
      billing_address: address({
        city:     'Hollywood',
        state:    'CA',
        zip:      '90210',
        country:  'USA',}),
      description: 'Store Purchase'
    }
    @declined_options = {
      billing_address: address({
        city:     'Hollywood',
        state:    'CA',
        zip:      '46282',
        country:  'USA',}),
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This Transaction has been approved.', response.message
  end

  def test_successful_purchase_with_more_options
    more_options = {
      order_id: '2',
      ip: "127.0.0.1",
      billing_address: address({
        city:     'Hollywood',
        state:    'CA',
        zip:      '90210',
        country:  'USA',
        email: "joe@example.com",}),
      program_code: '1',
      pay_code: 'IGS25XX46027DCP',
      market_source: SecureRandom.uuid
    }

    @options.merge!(more_options)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This Transaction has been approved.', response.message
  end

  def test_successful_purchase_recurring
    more_options = {
      order_id: '2',
      frequency: 'Quarterly',
      pay_type: 'Sustainer',
      ip: "127.0.0.1",
      email: "joe@example.com",
      program_code: '2',
      pay_code: 'IGS25XX46027DCP',
      market_source: SecureRandom.uuid
    }

    @options.merge!(more_options)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This Transaction has been approved.', response.message
  end


  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @declined_options)
    assert_failure response
    assert_equal 'This transaction has been declined.', response.message
  end

  def test_invalid_login
    gateway = PaymentSolutionsGateway.new(username: '', password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid Authentication}, response.message
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
