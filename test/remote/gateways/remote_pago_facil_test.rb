require 'test_helper'

class RemotePagoFacilTest < Test::Unit::TestCase
  def setup
    @gateway = PagoFacilGateway.new(fixtures(:pago_facil))

    @amount = 100

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      number: '4111111111111111',
      verification_value: '123',
      first_name: 'Juan',
      last_name: 'Reyes Garza',
      month: 9,
      year: Time.now.year + 1
    )

    @declined_card = ActiveMerchant::Billing::CreditCard.new(
      number: '4000300011112220',
      verification_value: '123',
      first_name: 'Juan',
      last_name: 'Reyes Garza',
      month: 9,
      year: Time.now.year + 1
    )

    @options = {
      order_id: '1',
      billing_address: {
        name: 'Juan Reyes Garza',
        address1: 'Anatole France 311',
        address2: 'Polanco',
        city: 'Miguel Hidalgo',
        state: 'Distrito Federal',
        country: 'Mexico',
        zip: '11560',
        phone: '5550220910'
      },
      email: 'comprador@correo.com',
      description: 'Store Purchase',
      cellphone: '5550123456'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    raise response.inspect
    assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  end

  def test_invalid_login
    gateway = PagoFacilGateway.new(
      login: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
