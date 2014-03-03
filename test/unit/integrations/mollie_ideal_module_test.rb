require 'test_helper'

class MollieIdealModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of MollieIdeal::Notification, MollieIdeal.notification("id=482d599bbcc7795727650330ad65fe9b", :credential1 => '1234')
  end

  def test_return_method
    assert_instance_of MollieIdeal::Return, MollieIdeal.return("", :credential1 => '1234')
  end

  def test_live?
    ActiveMerchant::Billing::Base.stubs(:integration_mode).returns(:development)
    assert !MollieIdeal.live?

    ActiveMerchant::Billing::Base.stubs(:integration_mode).returns(:production)
    assert MollieIdeal.live?
  end

  def test_required_redirect_parameter
    ActiveMerchant::Billing::Base.stubs(:integration_mode).returns(:development)

    assert MollieIdeal.requires_redirect_param?
    assert_equal [["TBM Bank", "ideal_TESTNL99"]], MollieIdeal.redirect_param_options
  end

  def test_retrieve_issuers
    MollieIdeal.expects(:mollie_api_request).returns(ISSERS_RESPONSE_JSON)
    issuers = MollieIdeal.retrieve_issuers(@api_key, 'ideal')
    assert_equal [["TBM Bank", "ideal_TESTNL99"]], issuers
  end

  ISSERS_RESPONSE_JSON = JSON.parse(<<-JSON)
    {
      "totalCount":1,
      "offset":0,
      "count":1,
      "data":[
        {
          "id":"ideal_TESTNL99",
          "name":"TBM Bank",
          "method":"ideal"
        }
      ]
    }
  JSON
end
