require 'test_helper'

class RemotePayHubTest < Test::Unit::TestCase
  def setup
    @gateway = PayHubGateway.new(fixtures(:pay_hub))
    @amount = 100
    @credit_card = credit_card('5466410004374507', valid_credit_card_credentials)
    @invalid_amount_card = credit_card('371449635398431', invalid_credit_card_credentials)
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
    assert response.success?
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_purchase
    amount = 0.20
    response = @gateway.purchase(amount, @invalid_amount_card, @options)

    assert !response.success?
    assert_equal 'INVALID AMOUNT', response.message
  end

  def test_successful_auth
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert response.success?
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_auth
    amount = 0.20
    response = @gateway.authorize(amount, @credit_card, @options)

    assert !response.success?
    assert_equal 'INVALID AMOUNT', response.message
  end


  def test_unsuccessful_capture
    response = @gateway.capture(@amount, 123)

    assert_failure response
    assert !response.success?
    assert_equal 'UNABLE TO CAPTURE', response.message
  end

  def test_partial_capture
    amount = 10
    auth_response = @gateway.authorize(@amount, @credit_card, @options)

    response = @gateway.capture(amount, auth_response.authorization)

    assert_success response
    assert response.success?
    assert_equal 'TRANSACTION CAPTURED SUCCESSFULLY', response.message
  end

  def test_successful_void
    purchase_response = @gateway.purchase(@amount, @credit_card, @options)

    response = @gateway.void(purchase_response.authorization)

    assert_success response
    assert response.success?
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_void
    response = @gateway.void(347)

    assert_failure response
    assert !response.success?
    assert_equal 'Unable to void previous transaction.', response.message
  end

  def test_successful_refund
    response = @gateway.refund(@amount, 123)

    assert_success response
    assert response.success?
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_refund
    response = @gateway.refund(@amount, 981)
    assert_failure response
    assert !response.success?
    assert_equal 'Unable to refund the previous transaction.', response.message
  end

  private

  def valid_credit_card_credentials
    {
      :month => '06',
      :year => '2020',
      :verification_value => '998'
    }
  end

  def invalid_credit_card_credentials
    {
      :month => '06',
      :year => '2020',
      :verification_value => '9997'
    }
  end
end
