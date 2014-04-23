require 'test_helper'

class PagSeguroModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    Net::HTTP.expects(:get_response).returns(stub(body: "<xml></xml>"))
    assert_instance_of PagSeguro::Notification, PagSeguro.notification('notificationCode=1234')
  end

  def test_return_method
    assert_instance_of ActiveMerchant::Billing::Integrations::Return, PagSeguro.return('{"name":"cody"}', {})
  end

end
