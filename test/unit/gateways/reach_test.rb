require 'test_helper'

class ReachTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ReachGateway.new(fixtures(:reach))
    @credit_card = credit_card
    @amount = 100

    @options = {
      email: 'johndoe@reach.com',
      order_id: '123',
      currency: 'USD',
      billing_address: {
        address1: '1670',
        address2: '1670 NW 82ND AVE',
        city: 'Miami',
        state: 'FL',
        zip: '32191',
        country: 'US'
      }
    }
  end

  def test_required_merchant_id_and_secret
    error = assert_raises(ArgumentError) { ReachGateway.new }
    assert_equal 'Missing required parameter: merchant_id', error.message
  end

  def test_supported_card_types
    assert_equal ReachGateway.supported_cardtypes, %i[visa diners_club american_express jcb master discover maestro]
  end

  def test_should_be_able_format_a_request
    post = {
      request: { someId: 'abc123' },
      card: { number: '12132323', name: 'John doe' }
    }

    formatted = @gateway.send :format_and_sign, post

    refute_empty formatted[:signature]
    assert_kind_of String, formatted[:request]
    assert_kind_of String, formatted[:card]

    assert_equal 'abc123', JSON.parse(formatted[:request])['someId']
    assert_equal '12132323', JSON.parse(formatted[:card])['number']
    assert formatted[:signature].present?
  end

  def test_successfully_build_a_purchase
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      card = JSON.parse(URI.decode_www_form(data)[1][1])

      # request
      assert_equal request['ReferenceId'], @options[:order_id]
      assert_equal request['Consumer']['Email'], @options[:email]
      assert_equal request['ConsumerCurrency'], @options[:currency]
      assert_equal request['Capture'], false

      # card
      assert_equal card['Number'], @credit_card.number
      assert_equal card['Name'], @credit_card.name
      assert_equal card['VerificationCode'], @credit_card.verification_value
    end.respond_with(successful_purchase_response)
  end

  def test_successfully_build_a_purchase_with_fingerprint
    stub_comms do
      @options[:device_fingerprint] = '54fd66c2-b5b5-4dbd-ab89-12a8b6177347'
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      assert_equal request['DeviceFingerprint'], @options[:device_fingerprint]
      assert_equal request['ViaAgent'], false
    end.respond_with(successful_purchase_response)
  end

  def test_properly_set_capture_flag_on_purchase
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      assert_equal true, request['Capture']
    end.respond_with(successful_purchase_response)
  end

  def test_sending_item_sku_and_item_price
    @options[:item_sku] = '1212121212'
    @options[:item_quantity] = 250

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])

      # request
      assert_equal request['Items'].first['Sku'], @options[:item_sku]
      assert_equal request['Items'].first['Quantity'], @options[:item_quantity]
    end.respond_with(successful_purchase_response)
  end

  def test_successfull_retrieve_error_message
    response = { response: { Error: { ReasonCode: 'is an error' } } }

    message = @gateway.send(:message_from, response)
    assert_equal 'is an error', message
  end

  def test_safe_retrieve_error_message
    response = { response: { Error: { Code: 'is an error' } } }

    message = @gateway.send(:message_from, response)
    assert_nil message
  end

  def test_sucess_from_on_sucess_result
    response = { response: { OrderId: '' } }

    assert @gateway.send(:success_from, response)
  end

  def test_sucess_from_on_failure
    response = { response: { Error: 'is an error' } }

    refute @gateway.send(:success_from, response)
  end

  private

  def successful_purchase_response
    'response=%7B%22OrderId%22%3A%22e8f8c529-15c7-46c1-b28b-9d43bb5efe92%22%2C%22UnderReview%22%3Afalse%2C%22Expiry%22%3A%222022-11-03T12%3A47%3A21Z%22%2C%22Authorized%22%3Atrue%2C%22Completed%22%3Afalse%2C%22Captured%22%3Afalse%7D&signature=JqLa7Y68OYRgRcA5ALHOZwXXzdZFeNzqHma2RT2JWAg%3D'
  end
end
