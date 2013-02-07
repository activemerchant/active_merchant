require 'test_helper'

class PaywayTest < Test::Unit::TestCase
  def setup
    @amount = 1100

    @options = {:order_id => generate_unique_id}

    @gateway = ActiveMerchant::Billing::PaywayGateway.new(fixtures(:payway))

    @visa = credit_card("4564710000000004",
      :month              => 2,
      :year               => 2019,
      :verification_value => "847"
    )

    @mastercard = credit_card("5163200000000008",
      :month              => 8,
      :year               => 2020,
      :verification_value => "070",
      :brand              => "master"
    )

    @expired = credit_card("4564710000000012",
      :month              => 2,
      :year               => 2005,
      :verification_value => "963"
    )

    @low = credit_card("4564710000000020",
      :month              => 5,
      :year               => 2020,
      :verification_value => "234"
    )

    @stolen_mastercard = credit_card("5163200000000016",
      :month              => 12,
      :year               => 2019,
      :verification_value => "728",
      :brand              => "master"
    )

    @invalid = credit_card("4564720000000037",
      :month              => 9,
      :year               => 2019,
      :verification_value => "030"
    )
  end

  def test_successful_visa
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    assert_response_message_prefix 'Approved', response
  end

  def test_successful_mastercard
    assert response = @gateway.purchase(@amount, @mastercard, @options)
    assert_success response
    assert_response_message_prefix 'Approved', response
  end

  def test_expired_visa
    assert response = @gateway.purchase(@amount, @expired, @options)
    assert_failure response
    assert_equal 'Declined - Expired card', response.message
  end

  def test_low_visa
    assert response = @gateway.purchase(@amount, @low, @options)
    assert_failure response
    assert_equal 'Declined - Not sufficient funds', response.message
  end

  def test_stolen_mastercard
    assert response = @gateway.purchase(@amount, @stolen_mastercard, @options)
    assert_failure response
    assert_equal 'Declined - Pick-up card', response.message
  end

  def test_invalid_visa
    assert response = @gateway.purchase(@amount, @invalid, @options)
    assert_failure response
    assert_equal 'Declined - Do not honour', response.message
  end

  def test_invalid_login
    gateway = ActiveMerchant::Billing::PaywayGateway.new(
      :username => 'bogus',
      :password => 'bogus',
      :merchant => 'TEST',
      :pem      => fixtures(:payway)['pem']
    )
    assert response = gateway.purchase(@amount, @visa, @options)
    assert_failure response
    assert_equal 'Invalid credentials', response.message
  end

  protected

  def assert_response_message_prefix(prefix, response)
    assert_equal prefix, response.message.split(' - ', 2).first
  end
end
