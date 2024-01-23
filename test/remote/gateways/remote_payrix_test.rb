# @format

require 'test_helper'

class RemotePayrixTest < Test::Unit::TestCase
  AMOUNTS = {
    invalid_card: 31,
    expired_card: 54,
    declined: 51,
    insufficient_funds: 61,
    technical_failure: 96
  }

  def setup
    @gateway = PayrixGateway.new(fixtures(:payrix))

    @amount = 100_00
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')

    @options = {
      billing_address: address,
      description: 'Store Purchase',
      return_url: 'https://app.black.test/payrix',
      transaction_reference: SecureRandom.hex(16),
      email: 'user@example.com'
    }
  end

  def test_successful_setup_purchase
    response = @gateway.setup_purchase(@amount, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_setup_purchase_with_more_options
    options = @options.merge({ ip: '127.0.0.1', phone: '021 902 123' })

    response = @gateway.setup_purchase(@amount, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_setup_purchase
    options = @options.merge({ transaction_reference: nil })
    response = @gateway.setup_purchase(@amount, options)
    assert_failure response
    assert_equal 'Reference is required', response.message
  end

  def test_failed_setup_purchase_and_details_for_token
    response =
      @gateway.setup_purchase(@amount + AMOUNTS[:invalid_card], @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.params['token']

    details_response = @gateway.details_for(response.params['token'])
    assert_failure details_response
  end

  def test_successful_setup_authorize
    response = @gateway.setup_authorize(@amount, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  # def test_failed_setup_authorize
  #   response = @gateway.setup_authorize(@amount, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED AUTHORIZE MESSAGE', response.message
  # end

  # def test_successful_setup_verify
  #   response = @gateway.setup_verify(@options)
  #   assert_success response
  #   assert_match(/REPLACE WITH SUCCESS MESSAGE/, response.message)
  # end

  # def test_failed_setup_verify
  #   response = @gateway.setup_verify(@options)
  #   assert_failure response
  #   assert_match(/REPLACE WITH FAILED PURCHASE MESSAGE/, response.message)
  # end

  def test_invalid_login
    gateway =
      PayrixGateway.new(fixtures(:payrix).merge(login: '', password: ''))

    response = gateway.setup_purchase(@amount, @options)
    assert_failure response
    assert_match(/The Password field is required./, response.message)
  end
end
