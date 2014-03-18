require 'test_helper'

class RemoteFirstGivingTest < Test::Unit::TestCase


  def setup
    @gateway = FirstGivingGateway.new(fixtures(:first_giving))

    @amount = 100
    @credit_card = credit_card("4457010000000009")
    @declined_card = credit_card("445701000000000")

    @options = {
      billing_address: address(state: "MA", zip: "01803", country: "US"),
      ip: "127.0.0.1"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal(
      "Unfortunately, we were unable to perform credit card number validation. The credit card number validator responded with the following message  ccNumber failed data validation for the following reasons :  creditcardLength: 445701000000000 contains an invalid amount of digits.",
      response.message,
      response.params.inspect
    )
  end

  def test_successful_refund
   assert purchase = @gateway.purchase(@amount, @credit_card, @options)
   assert_success purchase

   assert response = @gateway.refund(@amount, purchase.authorization)
   assert_equal "REFUND_REQUESTED_AWAITING_REFUND", response.message
  end

  def test_failed_refund
    assert response = @gateway.refund(@amount, "1234")
    assert_failure response
    assert_equal "An error occurred. Please check your input and try again.", response.message
  end

  def test_invalid_login
    gateway = FirstGivingGateway.new(
                application_key: "25151616",
                security_token:  "63131jnkj",
                charity_id: "1234"
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "An error occurred. Please check your input and try again.", response.message
  end
end
