require 'test_helper'

class RemotePlaceToPayTest < Test::Unit::TestCase
  def setup
    @gateway = PlaceToPayGateway.new(fixtures(:place_to_pay))

    @amount = 100
    @credit_card = credit_card('36545400000008', { brand: 'Dinners' })
    @declined_card = credit_card('36545400000248', { brand: 'Dinners' })
    @three_ds_card = credit_card('4532840681197602')
    @options = {
      reference: SecureRandom.uuid.remove('-'),
      description: 'Description',
      currency: 'USD'
    }
    @credit_options = {
      credit: {
        code: 1,
        type: '00',
        group_code: 'C',
        installment: 1,
        installments: 1
      }
    }
  end

  def test_successful_information_gathering
    response = @gateway.information(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  def test_successful_information_gathering_for_en_locale
    response = @gateway.information(@amount, @credit_card, @options.merge(locale: 'en_US'))
    assert_success response
    assert_equal 'The request has been successfully processed', response.message    
  end

  def test_successful_interest_calculation
    response = @gateway.interests(@amount, @credit_card, @options.merge(@credit_options))
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  def test_fail_lookup
    response = @gateway.lookup(
      @amount,
      @three_ds_card,
      @options.merge(@credit_options).merge({ return_url: 'http://localhost'}))
    assert_failure response
    assert_equal 'El comercio no tiene configurados datos de 3DS', response.message
  end

  def test_query
    response = @gateway.query(
      @amount,
      @three_ds_card,
      @options.merge(@credit_options).merge({ identifier: '1'}))
    assert_failure response
    assert_equal 'El comercio no tiene configurados datos de 3DS', response.message
  end

  def test_successful_otp_generation
    response = @gateway.otp(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  def test_fail_otp_generation
    response = @gateway.otp(@amount, credit_card('4012888888881881'), @options)
    assert_failure response
    assert_equal 'OTP is not required with this card', response.message
  end

  def test_successful_otp_validation
    response = @gateway.otp_validation(@amount, @credit_card, @options.merge(otp: '123456'))
    assert_success response
    assert_equal 'OTP Validation successful', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options.merge(otp: '123456'))
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  def test_successful_purchase_with_otp
    response = @gateway.purchase(@amount, @credit_card, @options.merge(otp: '123456'))
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Rechazada', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(/(\\?\\?\\?"cvv\\?\\?\\?":\\?\\?\\?"?)#{@credit_card.verification_value}+/, transcript)
  end
end
