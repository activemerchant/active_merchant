require 'test_helper'

class RemoteVposWithoutKeyTest < Test::Unit::TestCase
  def setup
    vpos_fixtures = fixtures(:vpos)
    vpos_fixtures.delete(:encryption_key)
    @gateway = VposGateway.new(vpos_fixtures)

    @amount = 100000
    @credit_card = credit_card('5418630110000014', month: 8, year: 2026, verification_value: '277')
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

  def test_successful_refund_using_auth
    shop_process_id = SecureRandom.random_number(10**15)

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    authorization = purchase.authorization

    assert refund = @gateway.refund(@amount, authorization, @options.merge(shop_process_id: shop_process_id))
    assert_success refund
    assert_equal 'Transaccion aprobada', refund.message
  end

  def test_successful_refund_using_shop_process_id
    shop_process_id = SecureRandom.random_number(10**15)

    assert purchase = @gateway.purchase(@amount, @credit_card, @options.merge(shop_process_id: shop_process_id))
    assert_success purchase

    assert refund = @gateway.refund(@amount, nil, original_shop_process_id: shop_process_id) # 315300749110268, 21611732218038
    assert_success refund
    assert_equal 'Transaccion aprobada', refund.message
  end

  def test_successful_credit
    assert credit = @gateway.credit(@amount, @credit_card)
    assert_success credit
    assert_equal 'Transaccion aprobada', credit.message
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @declined_card)
    assert_failure response
    assert_equal 'RefundsServiceError:TIPO DE TRANSACCION NO PERMITIDA PARA TARJETAS EXTRANJERAS', response.message
  end

  def test_successful_void
    shop_process_id = SecureRandom.random_number(10**15)
    options = @options.merge({ shop_process_id: shop_process_id })

    purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, options)
    assert_success void
    assert_equal 'RollbackSuccessful:Transacción Aprobada', void.message
  end

  def test_duplicate_void_fails
    shop_process_id = SecureRandom.random_number(10**15)
    options = @options.merge({ shop_process_id: shop_process_id })

    purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, options)
    assert_success void
    assert_equal 'RollbackSuccessful:Transacción Aprobada', void.message

    assert duplicate_void = @gateway.void(purchase.authorization, options)
    assert_failure duplicate_void
    assert_equal 'AlreadyRollbackedError:The payment has already been rollbacked.', duplicate_void.message
  end

  def test_failed_void
    response = @gateway.void('abc#123')
    assert_failure response
    assert_equal 'BuyNotFoundError:Business Error', response.message
  end

  def test_invalid_login
    gateway = VposGateway.new(private_key: '', public_key: '', encryption_key: OpenSSL::PKey::RSA.new(512), commerce: 123, commerce_branch: 45)

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

  def test_regenerate_encryption_key
    puts 'Regenerating encryption key.'
    puts 'Before running the standard vpos remote test suite, run this test individually:'
    puts '$ ruby -Ilib:test test/remote/gateways/remote_vpos_without_key_test.rb -n test_regenerate_encryption_key'
    puts 'Then copy this key into your fixtures file.'
    p @gateway.one_time_public_key
  end
end
