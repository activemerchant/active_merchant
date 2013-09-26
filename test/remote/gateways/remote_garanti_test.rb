require 'test_helper'

# NOTE: tests may fail randomly because Garanti returns random(!) responses for their test server
class RemoteGarantiTest < Test::Unit::TestCase

  def setup
    if RUBY_VERSION < '1.9' && $KCODE == "NONE"
      @original_kcode = $KCODE
      $KCODE = 'u'
    end

    @gateway = GarantiGateway.new(fixtures(:garanti))

    @amount = 1 # 1 cents = 0.01$
    @declined_card = credit_card('4000100011112224')
    @credit_card = credit_card('4000300011112220')

    @options = {
      :order_id => ActiveMerchant::Utils.generate_unique_id,
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def teardown
    $KCODE = @original_kcode if @original_kcode
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match /Declined/, response.message
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
    assert_match /Declined/, response.message
  end

  def test_invalid_login
    gateway = GarantiGateway.new(
                :provision_user_id => 'PROVAUT',
                :user_id => 'PROVAUT',
                :terminal_id => '10000174',
                :merchant_id => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '0651', response.params["reason_code"]
  end
end
