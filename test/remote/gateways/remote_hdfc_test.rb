require 'test_helper'

class RemoteHdfcTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = HdfcGateway.new(fixtures(:hdfc))

    @amount = 100
    @credit_card = credit_card("4012001037141112")

    # Use an American Express card to simulate a failure since HDFC does not
    # support any proper decline cards outside of 3D secure failures.
    @declined_card = credit_card("377182068239368", :brand => :american_express)

    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => "Store Purchase"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid Brand.", response.message
    assert_equal "GW00160", response.params["error_code_tag"]
  end

  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+\|.+$), response.authorization

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid Brand.", response.message
    assert_equal "GW00160", response.params["error_code_tag"]
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
  end

  def test_passing_billing_address
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:billing_address => address))
    assert_success response
  end

  def test_invalid_login
    gateway = HdfcGateway.new(
                :login => "",
                :password => ""
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "TranPortal ID required.", response.message
  end
end
