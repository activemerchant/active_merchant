require 'test_helper'

class RemoteTwocheckoutTest < Test::Unit::TestCase
  def setup
    @gateway = TwocheckoutGateway.new(fixtures(:twocheckout))
    @amount = 100
    @token = @gateway.options[:token]
    @bad_token = 'YTdhODcxZTQtNDFlMi00NDE2LWFhNTEtNDgyMDZiZDJkNWIx'
    @options = {
      email:  'example@2co.com',
      billing_address: address,
      shipping_address: address,
      description: 'twocheckout active merchant unit test',
      order_id: '123',
      currency: 'USD'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @token, @options)
    assert_success response
    assert_not_nil response.params['response']['transactionId']
    assert_not_nil response.params['response']['merchantOrderId']
    assert_equal response.authorization, response.params['response']['orderNumber']
    assert_equal @options[:currency], response.params['response']['currencyCode']
    assert_equal '%.2f' % (@amount / 100), response.params['response']['total']
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @bad_token, @options)
    assert_failure response
    assert_equal 'Bad request - parameter error', response.message
  end

  def test_invalid_login
    @gateway = TwocheckoutGateway.new(
      login: '',
      api_key: ''
    )
    assert response = @gateway.purchase(@amount, @token, @options)
    assert_failure response
    assert_equal 'Unauthorized', response.message
  end
end
