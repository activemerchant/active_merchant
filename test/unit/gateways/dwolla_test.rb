require 'test_helper'

class DwollaTest < Test::Unit::TestCase
  def setup
    @gateway = DwollaGateway.new(fixtures(:dwolla))

    @amount = 100
    
    @options = {:destination_id => "812-546-3855",
                :discount => 0,
                :shipping => 0,
                :tax => 0,
                :payment_callback => "http://dwolla-merchant.heroku.com/test/callback", # Only need this if you want it different than your application defines in Dwolla settings
                :payment_redirect => "http://localhost:3000/test/redirect", # Only need this if you want it different than your application defines in Dwolla settings
                :description => "testing active record",
                :ordered_items =>
                    [
                        {:name => "Test Item Name",
                                      :description => "Test Item Description",
                                      :price => 1,
                                      :quantity => 1}
                    ],
                }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @options)
    #assert_instance_of
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'C3D4DC4F-5074-44CA-8639-B679D0A70803', response.params["checkout_id"]
    assert_equal 'https://www.dwolla.com/payment/checkout/C3D4DC4F-5074-44CA-8639-B679D0A70803', response.params["redirect_url"]
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @options)
    assert_failure response
    assert_equal 'Invalid total.', response.params["error"]
    assert response.test?
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    %/{"Result":"Success","CheckoutId":"C3D4DC4F-5074-44CA-8639-B679D0A70803"}/
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    %-{"Message":"Invalid total.", "Result":"Failure"}-
  end
end
