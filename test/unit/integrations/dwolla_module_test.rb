# Dwolla ActiveMerchant Integration
# http://www.dwolla.com/
# Authors: Michael Schonfeld <michael@dwolla.com>, Gordon Zheng <gordon@dwolla.com>
# Date: May 1, 2013

require 'test_helper'

class DwollaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Dwolla::Notification, Dwolla.notification('{"Amount": 0.01, "CheckoutId": "f32b1e55-9612-4b6d-90f9-1c1519e588da", "ClearingDate": "8/28/2012 3:17:18 PM", "Error": null, "OrderId": null, "Signature": "098d3f32654bd8eebc9db323228879fa2ea12459", "Status": "Completed", "TestMode": "false", "TransactionId": 1312616}', {:credential2 => 'mysecret'})
  end

  def test_return
    assert_instance_of Dwolla::Return, Dwolla.return("signature=098d3f32654bd8eebc9db323228879fa2ea12459&test=true&orderId=&amount=0.01&checkoutId=f32b1e55-9612-4b6d-90f9-1c1519e588da&status=Completed&clearingDate=8/28/2012%203:17:18%20PM&transaction=1312616&postback=success", {:credential2 => 'mysecret'})
  end
end 
