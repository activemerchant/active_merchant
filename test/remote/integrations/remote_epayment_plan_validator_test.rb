require 'test_helper'

class RemoteEPaymentPlanIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
  end

  def tear_down
    ActiveMerchant::Billing::Base.integration_mode = :test
  end

end
