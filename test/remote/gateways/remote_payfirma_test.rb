require 'test_helper'

class RemotePayfirmaTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = PayfirmaGateway.new(fixtures(:payfirma))

    @credit_card = credit_card('4111111111111111', :verification_value => '123')
    @approved_amount = 100
    @declined_amount = 200
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@approved_amount, @credit_card)
    assert_success response
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@approved_amount, @credit_card)
    assert_success response
  end

  def test_successful_authorization_and_capture
    assert authorization = @gateway.authorize(@approved_amount, @credit_card)
    assert_success authorization

    assert capture = @gateway.capture(@approved_amount, authorization.authorization)
    assert_success capture
  end

  def test_successful_purchase_and_refund
    assert purchase = @gateway.purchase(@approved_amount, @credit_card)
    assert_success purchase

    assert refund = @gateway.refund(@approved_amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card)
    assert_failure response
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, :email => "francois@example.com")
    assert_success response
  end
end
