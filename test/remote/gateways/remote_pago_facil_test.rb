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
      number: '1111111111111111',
      verification_value: '123',
      first_name: 'Juan',
      last_name: 'Reyes Garza',
      month: 9,
      year: Time.now.year + 1
    )

    @options = {
      order_id: '1',
      billing_address: {
        address1: 'Anatole France 311',
        address2: 'Polanco',
        city: 'Miguel Hidalgo',
        state: 'Distrito Federal',
        country: 'Mexico',
        zip: '11560',
        phone: '5550220910'
      },
      email: 'comprador@correo.com',
      cellphone: '5550123456'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_random_response_success(response) do |random_response|
      assert random_response.authorization
      assert_equal 'Transaction has been successful!-Approved', random_response.message
    end
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Errores en los datos de entrada Validaciones', response.message
  end

  def test_invalid_login
    gateway = PagoFacilGateway.new(
      branch_id: '',
      merchant_id: '',
      service_id: 3
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_succesful_purchase_usd
    options = @options.merge(currency: 'USD')
    response = @gateway.purchase(@amount, @credit_card, options)

    assert_random_response_success(response) do |random_response|
      assert_equal 'USD', random_response.params['dataVal']['divisa']
      assert random_response.authorization
      assert_equal 'Transaction has been successful!-Approved', random_response.message
    end
  end

  # Even when all the parameters are correct the PagoFacil's test service will
  # respond randomly (can be approved or declined). When for this reason the
  # service returns a "declined" response, the response should have the error
  # message 'Declined_(General)'
  def assert_random_response_success(random_response)
    if random_response.success?
      yield random_response
    else
      assert_equal 'Declined_(General).', random_response.params.fetch('error')
    end
  end
end
