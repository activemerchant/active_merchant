require 'test_helper'

class MaksuturvaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Maksuturva::Notification, Maksuturva.notification("pmt_action" => "NEW_PAYMENT_EXTENDED", "pmt_version" => "0004", "pmt_id" => "2", "pmt_reference" => "134662", "pmt_amount" => "200,00", "pmt_currency" => "EUR", "pmt_sellercosts" => "0,00", "pmt_paymentmethod" => "FI01", "pmt_escrow" => "N", "pmt_hash" => "BDF4F41FA194612017CBE13CF7670971")
  end
end
