require 'test_helper'

class RemoteVposTest < Test::Unit::TestCase
  def setup
    @gateway = VposGateway.new(fixtures(:vpos))

    @amount = 100000
    @credit_card = credit_card('5418630110000014', month: 8, year: 2021, verification_value: '258')
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaccion aprobada', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'IMPORTE DE LA TRN INFERIOR AL M¿NIMO PERMITIDO', response.message
  end

  def test_successful_void
    shop_process_id = SecureRandom.random_number(10**15)
    options = @options.merge({ shop_process_id: shop_process_id })

    purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, options)
    assert_success void
    assert_equal 'RollbackSuccessful', void.message
  end

  def test_duplicate_void_fails
    shop_process_id = SecureRandom.random_number(10**15)
    options = @options.merge({ shop_process_id: shop_process_id })

    purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, options)
    assert_success void
    assert_equal 'RollbackSuccessful', void.message

    assert duplicate_void = @gateway.void(purchase.authorization, options)
    assert_failure duplicate_void
    assert_equal 'AlreadyRollbackedError', duplicate_void.message
  end

  def test_failed_void
    response = @gateway.void('abc#123')
    assert_failure response
    assert_equal 'BuyNotFoundError', response.message
  end

  def test_invalid_login
    gateway = VposGateway.new(private_key: '', public_key: '', commerce: 123, commerce_branch: 45)

    response = gateway.void('')
    assert_failure response
    assert_match %r{InvalidPublicKeyError}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    # does not contain anything other than '[FILTERED]'
    assert_no_match(/token\\":\\"[^\[FILTERED\]]/, transcript)
    assert_no_match(/card_encrypted_data\\":\\"[^\[FILTERED\]]/, transcript)
  end
end
