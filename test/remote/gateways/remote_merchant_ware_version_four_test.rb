require 'test_helper'

class RemoteMerchantWareVersionFourTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantWareVersionFourGateway.new(fixtures(:merchant_ware_version_four))

    @amount = rand(1000) + 200

    @credit_card = credit_card('5424180279791732', {:brand => 'master'})

    @options = {
      :order_id => generate_unique_id[0,8],
      :billing_address => address
    }

    @reference_purchase_options = {
      :order_id => generate_unique_id[0,8]
    }
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_unsuccessful_authorization
    @credit_card.number = "1234567890123"
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_unsuccessful_purchase
    @credit_card.number = "1234567890123"
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_authorize_and_capture_and_refund
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture

    assert refund = @gateway.refund(@amount, capture.authorization, @options)
    assert_success refund
    assert_not_nil refund.authorization
  end

  def test_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_not_nil refund.authorization
  end

  def test_purchase_and_reference_purchase
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert reference_purchase = @gateway.purchase(@amount,
                                                  purchase.authorization,
                                                  @reference_purchase_options)
    assert_success reference_purchase
    assert_not_nil reference_purchase.authorization
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_equal "token should be at least 1 to at most 100 characters in size.\nParameter name: token", response.message
  end

  def test_invalid_login
    gateway = MerchantWareVersionFourGateway.new(
                :login => '',
                :password => '',
                :name => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Credentials.', response.message
  end
end
