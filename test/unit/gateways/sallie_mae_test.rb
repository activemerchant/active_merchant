require 'test_helper'

class SallieMaeTest < Test::Unit::TestCase
  def setup
    @gateway = SallieMaeGateway.new(
                 :login => 'FAKEACCOUNT'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_non_test_account
    assert !@gateway.test?
  end

  def test_test_account
    gateway = SallieMaeGateway.new(:login => "TEST0")
    assert gateway.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    "Status=Accepted"
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    "Status=Declined"
  end
end
