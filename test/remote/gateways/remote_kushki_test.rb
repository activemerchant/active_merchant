require 'test_helper'

class RemoteKushkiTest < Test::Unit::TestCase
  def setup
    @gateway = KushkiGateway.new(fixtures(:kushki))
    @amount = 100
    @credit_card = credit_card('4000100011112224', verification_value: '777')
    @declined_card = credit_card('4000300011112220')
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_purchase_brazil
    response = @gateway.purchase(@amount, @credit_card, { currency: 'BRL' })
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_purchase_with_options
    options = {
      currency: 'USD',
      amount: {
        subtotal_iva_0: '4.95',
        subtotal_iva: '10',
        iva: '1.54',
        ice: '3.50'
      },
      contact_details: {
        document_type: 'CC',
        document_number: '123456',
        email: 'who_dis@monkeys.tv',
        first_name: 'Who',
        last_name: 'Dis',
        second_last_name: 'Buscemi',
        phone_number: '+13125556789'
      },
      metadata: {
        productos: 'bananas',
        nombre_apellido: 'Kirk'
      },
      months: 2,
      deferred_grace_months: '05',
      deferred_credit_type: '01',
      deferred_months: 3
    }

    amount = 100 * (
      options[:amount][:subtotal_iva_0].to_f +
      options[:amount][:subtotal_iva].to_f +
      options[:amount][:iva].to_f +
      options[:amount][:ice].to_f
    )

    response = @gateway.purchase(amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_purchase_with_extra_taxes_cop
    options = {
      currency: 'COP',
      amount: {
        subtotal_iva_0: '4.95',
        subtotal_iva: '10',
        iva: '1.54',
        ice: '3.50',
        extra_taxes: {
          propina: 0.1,
          tasa_aeroportuaria: 0.2,
          agencia_de_viaje: 0.3,
          iac: 0.4
        }
      }
    }

    amount = 100 * (
      options[:amount][:subtotal_iva_0].to_f +
      options[:amount][:subtotal_iva].to_f +
      options[:amount][:iva].to_f +
      options[:amount][:ice].to_f +
      options[:amount][:extra_taxes][:propina].to_f +
      options[:amount][:extra_taxes][:tasa_aeroportuaria].to_f +
      options[:amount][:extra_taxes][:agencia_de_viaje].to_f +
      options[:amount][:extra_taxes][:iac].to_f
    )

    response = @gateway.purchase(amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_purchase_with_extra_taxes_usd
    options = {
      currency: 'USD',
      amount: {
        subtotal_iva_0: '4.95',
        subtotal_iva: '10',
        iva: '1.54',
        ice: '3.50',
        extra_taxes: {
          propina: 0.1,
          tasa_aeroportuaria: 0.2,
          agencia_de_viaje: 0.3,
          iac: 0.4
        }
      }
    }

    amount = 100 * (
      options[:amount][:subtotal_iva_0].to_f +
      options[:amount][:subtotal_iva].to_f +
      options[:amount][:iva].to_f +
      options[:amount][:ice].to_f +
      options[:amount][:extra_taxes][:propina].to_f +
      options[:amount][:extra_taxes][:tasa_aeroportuaria].to_f +
      options[:amount][:extra_taxes][:agencia_de_viaje].to_f +
      options[:amount][:extra_taxes][:iac].to_f
    )

    response = @gateway.purchase(amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_failed_purchase
    options = {
      amount: {
        subtotal_iva: '200'
      }
    }

    response = @gateway.purchase(@amount, @declined_card, options)
    assert_failure response
    assert_equal 'Monto de la transacción es diferente al monto de la venta inicial', response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, { currency: 'PEN' })
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_authorize_brazil
    response = @gateway.authorize(@amount, @credit_card, { currency: 'BRL' })
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_approval_code_comes_back_when_passing_full_response
    options = {
      full_response: true
    }
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_not_empty response.params.dig('details', 'approvalCode')
    assert_equal 'Succeeded', response.message
  end

  def test_failed_authorize
    options = {
      amount: {
        subtotal_iva: '200'
      }
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_failure response
    assert_equal 'K220', response.responses.last.error_code
    assert_equal 'Monto de la transacción es diferente al monto de la venta inicial', response.message
  end

  def test_successful_3ds2_authorize_with_visa_card
    options = {
      currency: 'PEN',
      three_d_secure: {
        version: '2.2.0',
        cavv: 'AAABBoVBaZKAR3BkdkFpELpWIiE=',
        xid: 'NEpab1F1MEdtaWJ2bEY3ckYxQzE=',
        eci: '07'
      }
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_3ds2_authorize_with_master_card
    options = {
      currency: 'PEN',
      three_d_secure: {
        version: '2.2.0',
        cavv: 'AAABBoVBaZKAR3BkdkFpELpWIiE=',
        eci: '00',
        ds_transaction_id: 'b23e0264-1209-41L6-Jca4-b82143c1a782'
      }
    }

    credit_card = credit_card('5223450000000007', brand: 'master', verification_value: '777')
    response = @gateway.authorize(@amount, credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_3ds2_purchase
    options = {
      three_d_secure: {
        version: '2.2.0',
        cavv: 'AAABBoVBaZKAR3BkdkFpELpWIiE=',
        xid: 'NEpab1F1MEdtaWJ2bEY3ckYxQzE=',
        eci: '07'
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_failed_3ds2_authorize
    options = {
      currency: 'PEN',
      three_d_secure: {
        version: '2.2.0',
        authentication_response_status: 'Y',
        cavv: 'AAABBoVBaZKAR3BkdkFpELpWIiE=',
        xid: 'NEpab1F1MEdtaWJ2bEY3ckYxQzE='
      }
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_failure response
    assert_equal 'K001', response.responses.last.error_code
  end

  def test_failed_3ds2_authorize_with_different_card
    options = {
      currency: 'PEN',
      three_d_secure: {
        version: '2.2.0',
        cavv: 'AAABBoVBaZKAR3BkdkFpELpWIiE=',
        xid: 'NEpab1F1MEdtaWJ2bEY3ckYxQzE='
      }
    }
    credit_card = credit_card('6011111111111117', brand: 'discover', verification_value: '777')
    assert_raise ArgumentError do
      @gateway.authorize(@amount, credit_card, options)
    end
  end

  def test_successful_capture
    auth = @gateway.authorize(@amount, @credit_card)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_capture
    options = {
      amount: {
        subtotal_iva: '200'
      }
    }
    auth = @gateway.authorize(@amount, @credit_card)
    assert_success auth

    capture = @gateway.capture(@amount, auth.authorization, options)
    assert_failure capture
    assert_equal 'K012', capture.error_code
    assert_equal 'Monto de captura inválido.', capture.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    assert refund = @gateway.refund(@amount, nil)
    assert_failure refund
    assert_equal 'Missing Authentication Token', refund.message
  end

  def test_successful_void
    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    response = @gateway.void('000')
    assert_failure response
    assert_equal 'Cuerpo de la petición inválido.', response.message
  end

  def test_invalid_login
    gateway = KushkiGateway.new(public_merchant_id: '', private_merchant_id: '')

    response = gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_match %r{Unauthorized}, response.message
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?

    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:private_merchant_id], transcript)
  end
end
