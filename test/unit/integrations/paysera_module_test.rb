require 'test_helper'

class PayseraModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @order_id = 1
    @project_id = 123
    @project_password = 'some password'
  end

  def test_helper_method
    assert_instance_of Paysera::Helper, Paysera.helper(@order_id, @project_id, :credential2 => @project_password)
  end

  def test_notification_method
    assert_instance_of Paysera::Notification, Paysera.notification(raw_data, :credential2 => @project_password)
  end

  def raw_data
    'data=data_to_send&sign=client_signature'
  end
end
