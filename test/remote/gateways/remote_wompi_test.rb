require 'test_helper'

class RemoteWompiTest < Test::Unit::TestCase
  def setup
    @gateway = WompiGateway.new(fixtures(:wompi))

    @amount = 1_000_000
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4111111111111111')
    @options = {
      address: address({ country: 'CO' }),
      description: 'Store Purchase',
      reference: SecureRandom.uuid,
      currency: 'COP',
      customer: {
        email: 'john.smith@test.com',
        full_name: 'John smith',
        mob_phone: '08032000001',
      },
    }

    @debit_information = {
      type: 'PSE',
      user_type: 0,
      user_legal_id_type: 'CC',
      user_legal_id: '1999888777',
      financial_institution_code: '1',
      payment_description: 'Pago a Tienda Wompi',
    }
  end

  def test_approved_pse_transaction
    response = @gateway.pse_financial_institutions
    assert_equal 'APPROVED', response.message

    purchase_response = @gateway.purchase(@amount, @debit_information, @options)
    assert_equal 'PENDING', purchase_response.message

    sleep 10 # simulate long polling. Doesn't always work.

    response =
      @gateway.query_transaction(purchase_response.params['data']['reference'])

    ticket_id =
      response.params['data'].first['payment_method']['extra']['ticket_id']
    assert_equal "https://sandbox.wompi.co/v1/pse/redirect?ticket_id=#{ticket_id}",
                 response.params['data'].first['payment_method']['extra'][
                   'async_payment_url'
                 ]
  end

  def test_query_acceptance_token
    response = @gateway.query_acceptance_token
    assert_success response
    assert_match /.{20}\..{284}\..{43}/, response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'CREATED', response.message
    assert_match /tok_test_\d{4}_[a-zA-Z0-9]{32}/, response.authorization
  end

  def test_fail_store
    response = @gateway.store(credit_card('4'), @options)
    assert_failure response
    assert_equal "number: debe coincidir con el patron \"^\\d{12,19}$\"",
                 response.message
  end

  def test_approved_purchase
    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'PENDING', purchase_response.message

    response =
      @gateway.query_transaction(purchase_response.params['data']['reference'])

    sleep 10 # Wait for purchase to approve. Doesn't always work.

    assert_equal 'APPROVED', response.message
  end

  def test_approved_purchase_with_multiple_token
    @options.merge!(multiple_payments_token: true)
  end

  def test_pending_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_equal 'PENDING', response.message
  end

  def test_declined_purchase
    purchase_response = @gateway.purchase(@amount, @declined_card, @options)
    response =
      @gateway.query_transaction(purchase_response.params['data']['reference'])
    assert_equal 'DECLINED', response.message
  end

  def test_financial_institutions
    response = @gateway.pse_financial_institutions

    assert_equal 'APPROVED', response.message
  end

  def test_transcript_scrubbing
    transcript =
      capture_transcript(@gateway) do
        tokenizations_response = @gateway.store(@credit_card, @options)
        options = @options.merge(token: tokenizations_response.authorization)
        response = @gateway.purchase(@amount, @credit_card, options)
      end

    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(
      /(\\?\\?\\?"cvv\\?\\?\\?":\\?\\?\\?"?)#{@credit_card.verification_value}+/,
      transcript,
    )
    assert_scrubbed(@gateway.options[:private_key], transcript)
  end
end
