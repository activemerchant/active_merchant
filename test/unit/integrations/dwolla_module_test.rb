require 'test_helper'

class DwollaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Dwolla::Notification, Dwolla.notification('{"Amount":0.01,"OrderId":"abc123","Status":"Completed","Error":null,"TransactionId":3165397,"CheckoutId":"ac5b910a-7ec1-4b65-9f68-90449ed030f6","Signature":"7d4c5deaf9178faae7c437fd8693fc0b97b1b22b","TestMode":"false","ClearingDate":"6/8/2013 8:07:41 PM"}', {:credential3 => '62hdv0jBjsBlD+0AmhVn9pQuULSC661AGo2SsksQTpqNUrff7Z'})
  end

  def test_return
    assert_instance_of Dwolla::Return, Dwolla.return("signature=7d4c5deaf9178faae7c437fd8693fc0b97b1b22b&orderId=abc123&amount=0.01&checkoutId=ac5b910a-7ec1-4b65-9f68-90449ed030f6&status=Completed&clearingDate=6/8/2013%208:07:41%20PM&transaction=3165397&postback=success", {:credential3 => '62hdv0jBjsBlD+0AmhVn9pQuULSC661AGo2SsksQTpqNUrff7Z'})
  end
end
