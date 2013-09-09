require 'test_helper'

class IatsPaymentsTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = IatsPaymentsGateway.new(fixtures(:iats_payments))
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @check = check
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_failed_purchase
    assert response = @gateway.purchase(200, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'This transaction has been declined', response.message
  end

  def test_bad_login
    gateway = IatsPaymentsGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    assert response = gateway.purchase(@amount, @credit_card)

    assert_equal Response, response.class
    assert_equal ["action",
                  "authorization_code",
                  "avs_result_code",
                  "card_code",
                  "response_code",
                  "response_reason_code",
                  "response_reason_text",
                  "transaction_id"], response.params.keys.sort

    assert_match(/The merchant API Login ID is invalid or the account is inactive/, response.message)

    assert_equal false, response.success?
  end
end
