require 'test_helper'

class RemoteFinansbankTest < Test::Unit::TestCase
  def setup
    if RUBY_VERSION < '1.9' && $KCODE == "NONE"
      @original_kcode = $KCODE
      $KCODE = 'u'
    end

    @gateway = FinansbankGateway.new(fixtures(:finansbank))

    @amount = 100

    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '#' + ActiveMerchant::Utils.generate_unique_id,
      :billing_address => address,
      :description => 'Store Purchase',
      :email => 'xyz@gmail.com'
    }
  end

  def teardown
    $KCODE = @original_kcode if @original_kcode
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_invalid_login
    gateway = FinansbankGateway.new(
      :login => '',
      :password => '',
      :client_id => ''
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
