require 'test_helper'

class MollieIdealModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of MollieIdeal::Notification, MollieIdeal.notification("transaction_id=482d599bbcc7795727650330ad65fe9b", :partner_id => '1234')
  end

  def test_mollie_api_uri
    MollieIdeal.stubs(:testmode).returns(false)
	uri = MollieIdeal.mollie_api_uri(:banklist, {})
	assert_equal 'https://secure.mollie.nl/xml/ideal?a=banklist', uri.to_s

	uri = MollieIdeal.mollie_api_uri(:fetch,
		:partner_id => '1487031', :bank_id => 9999, :amount => 123, :description => 'order #123',
		:reporturl => 'https://pingback.com', :returnurl => 'https://return.com'
	)

	assert_equal 'partner_id=1487031&bank_id=9999&amount=123&description=order+%23123&reporturl=https%3A%2F%2Fpingback.com&returnurl=https%3A%2F%2Freturn.com&a=fetch', uri.query
  end

  def test_mollie_api_url_include_testmode
    MollieIdeal.stubs(:testmode).returns(true)
    uri = MollieIdeal.mollie_api_uri(:banklist, {})
    assert_equal 'https://secure.mollie.nl/xml/ideal?testmode=true&a=banklist', uri.to_s
  end
end
