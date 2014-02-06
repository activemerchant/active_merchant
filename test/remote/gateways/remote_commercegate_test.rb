require 'test_helper'

class RemoteCommercegateTest < Test::Unit::TestCase
  def setup
    @gateway = CommercegateGateway.new(fixtures(:commercegate))

    @amount = 1000

    @options = {
      address: address
    }

    @credit_card = credit_card(fixtures(:commercegate)[:card_number])
    @expired_credit_card = credit_card(fixtures(:commercegate)[:card_number], year: Time.now.year-1)
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.params['action'], 'AUTH'
    assert_equal 'U', response.avs_result["code"]
    assert_equal 'M', response.cvv_result["code"]
  end

  def test_successful_authorize_without_options
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response
    assert_equal response.params['action'], 'AUTH'
    assert_nil response.avs_result["code"]
    assert_equal 'M', response.cvv_result["code"]
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.params['action'], 'SALE'
    assert_equal 'U', response.avs_result["code"]
    assert_equal 'M', response.cvv_result["code"]
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @expired_credit_card, @options)
    assert_failure response
    assert_not_nil response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '123', @options)
    assert_failure response
    assert_equal 'Previous transaction not found', response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert trans_id = response.params['transID']

    assert response = @gateway.refund(@amount, trans_id, @options)
    assert_success response
    assert_equal response.params['action'], 'REFUND'
  end

  def test_successful_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert trans_id = response.params['transID']
    assert response = @gateway.void(trans_id)
    assert_success response
    assert_equal response.params['action'], 'VOID_AUTH'
  end

  def test_invalid_login
    gateway = CommercegateGateway.new(
      login: '',
      password: '',
      site_id: '',
      offer_id: ''
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
