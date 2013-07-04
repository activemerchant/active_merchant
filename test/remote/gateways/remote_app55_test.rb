require 'test_helper'

class RemoteApp55Test < Test::Unit::TestCase
  def setup
    @gateway = App55Gateway.new(fixtures(:app55))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @duff_card = credit_card('400030001111222')
    @customer = generate_unique_id

    @options = {
      billing_address: address,
      description: 'app55 active merchant remote test',
      currency: "GBP"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.params["sig"]
    assert_not_nil response.params["transaction"]["auth_code"]
    assert_not_nil response.params["transaction"]["id"]
    assert_equal response.params["transaction"]["id"], response.authorization
    assert_equal @options[:description], response.params["transaction"]["description"]
    assert_equal @options[:currency], response.params["transaction"]["currency"]
    assert_equal "%.2f" % (@amount / 100), response.params["transaction"]["amount"]
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @duff_card, @options)
    assert_failure response
    assert_equal "Invalid card number supplied.", response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert response = @gateway.authorize(amount, @credit_card, @options)
    assert_success response
    assert response.params["transaction"]
    assert_equal @options[:description], response.params["transaction"]["description"]
    assert_equal @options[:currency], response.params["transaction"]["currency"]
    assert_equal "%.2f" % (@amount / 100), response.params["transaction"]["amount"]

    assert capture = @gateway.capture(amount, response.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert !response.params["transaction"]
  end

  def test_invalid_login
    gateway = App55Gateway.new(
      api_key: 'xNSACPYP9ZDUr4860gV9vqvR7TxmVMJP',
      api_secret: 'bogus'
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The supplied API Secret does not appear to be valid.', response.message
  end
end
