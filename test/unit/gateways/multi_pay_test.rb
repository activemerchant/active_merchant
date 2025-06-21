require 'test_helper'

class MultiPayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MultiPayGateway.new(
      company: 'company123',
      branch: 'branch456',
      pos: 'pos123',
      user: 'test_user',
      password: 'test_password'
    )
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: 'f63b625e-331e-490a-b15c-50b4087ca64f',
      description: 'Store Purchase',
      currency: 'CLP',
      user_id: 'user123'
    }
  end

  def test_required_credentials
    error = assert_raises ArgumentError do
      MultiPayGateway.new
    end

    assert_equal 'Missing required parameter: company', error.message
  end

  def test_supported_card_types
    assert_equal MultiPayGateway.supported_cardtypes, %i[visa master american_express]
  end

  def test_supported_countries
    assert_equal MultiPayGateway.supported_countries, ['CL']
  end

  def test_support_scrubbing_flag_enabled
    assert @gateway.supports_scrubbing?
  end

  def test_successful_access_token_fetch
    @gateway.expects(:ssl_post).returns(successful_access_token_response)

    response = @gateway.send(:fetch_access_token)
    assert_success response
    assert_equal 'test_access_token', @gateway.instance_variable_get(:@options)[:access_token]
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).times(2).returns(successful_access_token_response, successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal '123456', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).times(2).returns(successful_access_token_response, successful_capture_response)

    response = @gateway.capture(@amount, '123456', @options)

    assert_success response
    assert_equal 'TRANSACCION APROBADA POR EL ADAPTER', response.message
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_access_token_response, successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '123456', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).times(2).returns(successful_access_token_response, failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).times(2).returns(successful_access_token_response, failed_capture_response)

    response = @gateway.capture(@amount, '123456', @options)

    assert_failure response
    assert_equal 'Settlement failed', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?

    pre_scrubbed = <<-PRE_SCRUBBED
      Authorization: Bearer test_access_token
      Authorization: Basic userpassword
      \"CardNumber\":\"4111111111111111\"
      \"SecurityCode\":\"123\"
    PRE_SCRUBBED

    post_scrubbed = <<-POST_SCRUBBED
      Authorization: Bearer [FILTERED]
      Authorization: Basic [FILTERED]
      \"CardNumber\":\"[FILTERED]\"
      \"SecurityCode\":\"[FILTERED]\"
    POST_SCRUBBED

    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_successful_authorize_with_dollar_format
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'USD'))
    end.check_request(skip_response: true) do |endpoint, data, _headers|
      if endpoint.include?('token')
        assert_match(/grant_type=client_credentials/, endpoint)
      else
        data = JSON.parse(data)
        assert_equal '1.00', data['Amount']
        assert_equal '840', data['CurrencyCode']
      end
    end
  end

  def test_successful_authorize_with_cents_format
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'CLP'))
    end.check_request(skip_response: true) do |endpoint, data, _headers|
      if endpoint.include?('token')
        assert_match(/grant_type=client_credentials/, endpoint)
      else
        data = JSON.parse(data)
        assert_equal '100', data['Amount']
        assert_equal '152', data['CurrencyCode']
      end
    end
  end

  private

  def successful_access_token_response
    {
      access_token: 'test_access_token',
      token_type: 'Bearer',
      expires_in: 3600
    }.to_json
  end

  def successful_authorize_response
    {
      AuthorizeSaleResponse: {
        Reference: '123456',
        AuthResultCode: '00',
        ResponseMessage: 'Approved'
      }
    }.to_json
  end

  def successful_capture_response
    {
      SettlementResponse: {
        Status: 'Success',
        AuthResultCode: '00',
        ResponseMessage: 'TRANSACCION APROBADA POR EL ADAPTER'
      }
    }.to_json
  end

  def successful_purchase_response
    {
      SaleResponse: {
        Reference: '123456',
        AuthResultCode: '00',
        ResponseMessage: 'Approved'
      }
    }.to_json
  end

  def failed_authorize_response
    {
      AuthorizeSaleResponse: {
        AuthResultCode: '001',
        ResponseMessage: 'Declined'
      }
    }.to_json
  end

  def failed_capture_response
    {
      SettlementResponse: {
        AuthResultCode: '002',
        ResponseMessage: 'Settlement failed'
      }
    }.to_json
  end
end
