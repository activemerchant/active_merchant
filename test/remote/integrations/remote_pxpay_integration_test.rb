require 'test_helper'

class RemotePxpayIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @pxpay = Pxpay::Notification.new('')
    @username = "ShopifyWSDev"
    @key = "test1234"
  end

  def tear_down
    ActiveMerchant::Billing::Base.integration_mode = :test
  end
  
  def test_raw
    assert_equal "https://www.sandbox.paypal.com/cgi-bin/webscr", Paypal.service_url
    assert_nothing_raised do
      assert_equal false, @paypal.acknowledge
    end
  end
  
  def test_valid_sender_always_true
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert @paypal.valid_sender?(nil)
    assert @paypal.valid_sender?('127.0.0.1')
  end

  def test_invalid_credentials_returns_failed_request
    puts "doing remote test"
    request = ""
    payment_service_for('44',@username, :service => :pxpay,  :amount => "157.0"){|service|

      service.customer_id 8
      service.customer :first_name => 'g',
                       :last_name => 'g',
                       :email => 'g@g.com',
                       :phone => '3'

      service.billing_address :zip => 'g',
                       :country => 'United States of America',
                       :address1 => 'g'

      service.ship_to_address :first_name => 'g',
                              :last_name => 'g',
                              :city => '',
                              :address1 => 'g',
                              :address2 => '',
                              :state => 'ut',
                              :country => 'United States of America',
                              :zip => 'g'

      service.return_url "http://t/pxpay/return_url"
      service.cancel_return_url "http://t/pxpay/cancel_url"
    }

  end
end
