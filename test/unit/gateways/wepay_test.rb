require 'test_helper'

class WepayTest < Test::Unit::TestCase
  def setup
    @gateway = WepayGateway.new(
                            :client_id => 'client_id',
                            :account_id => 'account_id',
                            :access_token => 'access_token',
                            :use_staging => true
               )

    @credit_card = credit_card
    @amount = 100
    @options = {
      :amount            => '24.95',
      :short_description => 'A brand new soccer ball',
      :type              => 'GOODS'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).at_most(2).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 1117213582, response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).at_most(2).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_purchase_response
    "{\"checkout_id\":1117213582,\"checkout_uri\":\"https:\/\/stage.wepay.com\/api\/checkout\/1117213582\/974ff0c0\"}"
  end

  def failed_purchase_response
    "{\"error\":\"access_denied\",\"error_description\":\"invalid account_id, account does not exist or does not belong to user\",\"error_code\":3002}"
  end
end
