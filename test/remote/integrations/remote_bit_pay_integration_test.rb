require 'test_helper'
require 'remote/integrations/remote_integration_helper'

class RemoteBitPayIntegrationTest < Test::Unit::TestCase
  include RemoteIntegrationHelper

  def setup
    @api_key = fixtures(:bit_pay)[:api_key]
  end

  def test_invoice_id_properly_generated
    helper = ActiveMerchant::Billing::Integrations::BitPay::Helper.new(123, @api_key, :amount => 100, :currency => 'USD')
    assert helper.form_fields["id"]
  end 

end
