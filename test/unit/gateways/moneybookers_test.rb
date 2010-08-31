require "test_helper"

class MoneybookersTest < Test::Unit::TestCase
  def setup
    @amount = 100
    @options = {
      :pay_to_email => 'test@urbanvention.com',
      :order_id        => '1',
      :billing_address => address,
      :return_url      => 'localhost:3000/payment_confirmed',
      :cancel_url      => 'localhost:3000/payment_canceled',
      :test            => true
    }
    @gateway = MoneybookersGateway.new(@options)
  end

  def test_successful_purchase
    # TODO stop hitting the API here. This should go into the remote testing
    # @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.setup_purchase(@amount)
    assert request  = @gateway.request
    assert response = @gateway.response
    assert_instance_of MoneybookersResponse, response
    assert_success response

    # Replace with authorization number from the successful response
    assert response.token =~ /\w{32}/
    assert @gateway.checkout_url =~ /\?sid=\w{32}/
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.setup_purchase(@amount)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  # TODO add mock object for gateway response
  def successful_purchase_response
  end

  # Place raw failed response from gateway here
  # TODO add mock object for gateway response
  def failed_purchase_response
  end
end
