require File.expand_path('../../../test_helper', __FILE__)

# Note: the sandbox doesn't support void, capture nor refund
class RemotePayULatamTest < Test::Unit::TestCase
  def setup
    # PayULatamGateway's test server has an improperly installed cert
    PayULatamGateway.ssl_strict = false

    # The tests will work with Brazil only, the payload will be different in other countries
    # See http://docs.payulatam.com/en/api-integration/proof-of-payment/
    @gateway       = PayULatamGateway.new(:merchant_id => 500365, :api_login => '403ba744e9827f3', :api_key => '676k86ks53la6tni6clgd30jf6', :country_account_id => '500719')

    @amount        = 900
    # Enter APPROVED for the cardholder name value if you want the transaction to be approved or REJECTED if you want it to be rejected
    @credit_card   = credit_card('4111111111111111', :last_name => 'APPROVED', :month => 12)
    @declined_card = credit_card('4111111111111111', :last_name => 'REJECTED', :month => 12)

    @options = {
        # Required information
        order_id:              Time.now.to_i.to_s,
        language:              'en',
        description:           'Store Purchase',
        # Buyer information
        buyer_dni_number:      '29847984',
        buyer_cnpj:            '01310074836',
        email:                 'buyer@mail.com',
        billing_address:       {
            :name     => 'Buyer fullname',
            :address1 => 'AV Soa',
            :city     => 'Sao Paulo',
            :state    => 'SP',
            :zip      => '78556836',
            :country  => 'BR',
            :phone    => '211525246'
        },
        shipping_address:      {
            :name     => 'Buyer fullname',
            :address1 => 'AV Soa',
            :city     => 'Sao Paulo',
            :state    => 'SP',
            :zip      => '78556836',
            :country  => 'BR',
            :phone    => '211525246'
        },
        # Payer information
        payer_user_id:         Time.now.to_i.to_s,
        payer_email:           'payer@example.com',
        payer_dni_number:      '5415668464654',
        payer_billing_address: {
            name:     'Adriana Tavares da Silva',
            address1: 'Rua da Quitanda 187',
            address2: 'Building 187',
            city:     'Rio de Janeiro',
            state:    'RJ',
            zip:      '20091-005',
            country:  'BR',
            phone:    '+552121114700'
        },
        # Other information
        cookie:                'cookie_52278879710130',
        ip:                    '127.0.0.1',
        user_agent:            'Firefox',
        currency:              'BRL',
        # Breaks Panama
        #payment_country:       'BR',
        # For token based transactions only
        security_code:         '123'
    }
  end

  def test_successful_store_and_purchase
    assert response = @gateway.store(@credit_card, @options)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_equal 'The transaction was approved', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction was approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The transaction has been declined by the bank or there has been an error with the payment network', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(nil, '', @options)
    assert_failure response
  end

  def test_failed_refund
    response = @gateway.refund(nil, '', @options)
    assert_failure response
  end

  def test_failed_void
    response = @gateway.void('', @options)
    assert_failure response
  end

  def test_invalid_login
    gateway  = PayULatamGateway.new(
        merchant_id:        '12345',
        api_login:          'login',
        api_key:            'password',
        country_account_id: 'abcde'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
