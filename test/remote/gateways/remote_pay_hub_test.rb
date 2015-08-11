require 'test_helper'

class RemotePayHubTest < Test::Unit::TestCase
  def setup
    @gateway = PayHubGateway.new(fixtures(:pay_hub))
    @amount = 100
    @credit_card = credit_card('5466410004374507', verification_value: "998")
    @invalid_card = credit_card('371449635398431', verification_value: "9997")
    @options = {
      :first_name => 'Garrya',
      :last_name => 'Barrya',
      :email => 'payhubtest@mailinator.com',
      :address => {
        :address1 => '123a ahappy St.',
        :city => 'Happya City',
        :state => 'CA',
        :zip => '94901'
      }
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_purchase
    amount = 20
    response = @gateway.purchase(amount, @invalid_card, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_successful_auth
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_auth
    response = @gateway.authorize(20, @invalid_card, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_unsuccessful_capture
    assert_failure @gateway.capture(@amount, "bogus")
  end

  def test_partial_capture
    auth_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth_response

    response = @gateway.capture(10, auth_response.authorization)
    assert_success response
    assert_equal 'TRANSACTION CAPTURED SUCCESSFULLY', response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    response = @gateway.refund(nil, response.authorization)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_refund
    assert_failure @gateway.refund(@amount, "bogus")
  end

  def test_successful_verify
    assert_success @gateway.verify(@credit_card)
  end

  def test_failed_verify
    assert_failure @gateway.verify(credit_card("4111111111111111"))
  end
end
