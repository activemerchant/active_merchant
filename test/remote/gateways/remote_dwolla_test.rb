require 'test_helper'

class RemoteDwollaTest < Test::Unit::TestCase
  

  def setup
    ActiveMerchant::Billing::Base.mode = :test

    @gateway = DwollaGateway.new(fixtures(:dwolla))
    
    @amount = 1
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
     @bad_options = {:destination_id => "812-546-3855",
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
                                      :quantity => 0}
                    ],
                }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @options)
    assert_success response
    assert_equal 'Successfully purchase order setup.', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @bad_options)
    assert_failure response
    assert_equal 'Failed purchase order setup', response.message
  end

  def test_invalid_login
    gateway = DwollaGateway.new(
                :public_key => '',
                :private_key => ''
              )
    assert response = gateway.purchase(@amount, @options)
    assert_failure response
    assert_equal 'Failed purchase order setup', response.message
    assert_equal 'Invalid application credentials.', response.params["error"]
  end
end
