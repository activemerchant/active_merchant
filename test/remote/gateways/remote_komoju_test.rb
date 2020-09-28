require 'test_helper'
require 'securerandom'

class RemoteKomojuTest < Test::Unit::TestCase
  def setup
    @gateway = KomojuGateway.new(fixtures(:komoju))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4123111111111059')
    @fraudulent_card = credit_card('4123111111111083')

    @options = {
      :order_id => generate_unique_id,
      :description => 'Store Purchase',
      :tax => '10.0',
      :ip => "192.168.0.1",
      :email => "valid@email.com",
      :browser_language => "en",
      :browser_user_agent => "user_agent"
    }
  end

  def test_successful_credit_card_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization.present?
    assert_equal 'Transaction succeeded', response.message
    assert_equal 100, response.params['amount']
    assert_equal "1111", response.params['payment_details']['last_four_digits']
    assert_equal true, response.params['captured_at'].present?
  end

  def test_successful_credit_card_purchase_with_minimal_options
    response = @gateway.purchase(@amount, @credit_card, {})
    assert_success response
    assert response.authorization.present?
    assert_equal 'Transaction succeeded', response.message
    assert_equal 100, response.params['amount']
    assert_equal "1111", response.params['payment_details']['last_four_digits']
    assert_equal true, response.params['captured_at'].present?
  end

  def test_successful_credit_card_refund
    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response
    assert purchase_response.authorization.present?
    refund_response = @gateway.refund(@amount, purchase_response.authorization, {})
    assert_success refund_response
    assert_equal 'refunded', refund_response.params['status']
  end

  def test_failed_credit_card_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.authorization.blank?
    assert_equal 'card_declined', response.error_code
  end

  def test_detected_fraud
    response = @gateway.purchase(@amount, @fraudulent_card, @options)
    assert_failure response
    assert response.authorization.blank?
    assert_equal 'fraudulent', response.error_code
  end

  def test_invalid_login
    gateway = KomojuGateway.new(:login => 'abc')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
