require 'test_helper'

class FlowTest < Test::Unit::TestCase
  def setup
    @gateway = FlowGateway.new(api_key: 'test', organization: 'org-test')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      customer: {}
    }

    @internal_client = @gateway.instance_variable_get(:@client)
  end

  def test_successful_purchase_with_token
    auths_stub = stub(:authorizations)
    @internal_client.expects(:authorizations).returns(auths_stub)
    auths_stub.expects(:post).with('org-test', anything).returns(successful_authorize_response)
    captures_stub = stub(:captures)
    @internal_client.expects(:captures).returns(captures_stub)
    captures_stub.expects(:post).with('org-test', anything).returns(successful_capture_response)
    response = @gateway.purchase(@amount, 'card-token', @options)
    assert_success response

    assert_equal 'auth-id', response.authorization
  end

  def test_failed_purchase_with_failed_authorization
    auths_stub = stub(:authorizations)
    @internal_client.expects(:authorizations).returns(auths_stub)
    auths_stub.expects(:post).with('org-test', anything).returns(failed_authorize_response)

    response = @gateway.purchase(@amount, 'card-token', @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  private

  def successful_authorize_response
    Io::Flow::V0::Models::Authorization.new(
      id: 'auth-id',
      key: 'auth-id',
      card: Io::Flow::V0::Models::CardReference.new(
        id: 'card-id',
        token: 'card-token'
      ),
      amount: BigDecimal.new(@amount),
      currency: 'USD',
      customer: Io::Flow::V0::Models::Customer.new(
        name: Io::Flow::V0::Models::Name.new(first: 'Joe', last: 'Smith'),
      ),
      attributes: {},
      result: Io::Flow::V0::Models::AuthorizationResult.new(
        status: Io::Flow::V0::Models::AuthorizationStatus.new('authorized'),
        decline_code: nil,
        avs: Io::Flow::V0::Models::Avs.new(
          code: Io::Flow::V0::Models::AvsCode.new('match')
        ),
      )
    )
  end

  def failed_authorize_response
    Io::Flow::V0::Models::Authorization.new(
      id: 'auth-id',
      key: 'auth-id',
      card: Io::Flow::V0::Models::CardReference.new(
        id: 'card-id',
        token: 'card-token'
      ),
      amount: BigDecimal.new(@amount),
      currency: 'USD',
      customer: Io::Flow::V0::Models::Customer.new(
        name: Io::Flow::V0::Models::Name.new(first: 'Joe', last: 'Smith'),
      ),
      attributes: {},
      result: Io::Flow::V0::Models::AuthorizationResult.new(
        status: Io::Flow::V0::Models::AuthorizationStatus.new('declined'),
        decline_code: Io::Flow::V0::Models::AuthorizationDeclineCode.new('error'),
        avs: Io::Flow::V0::Models::Avs.new(
          code: Io::Flow::V0::Models::AvsCode.new('match')
        )
      )
    )
  end

  def successful_capture_response
    Io::Flow::V0::Models::Capture.new(
      id: 'capture-id',
      key: 'capture-id',
      authorization: Io::Flow::V0::Models::AuthorizationReference.new(
        id: 'auth-id'
      ),
      amount: BigDecimal.new(100, 2),
      currency: 'USD'
    )
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
