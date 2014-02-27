require 'test_helper'

class MollieIdealNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  CHECK_XML_RESPONSE = <<-XML
      <?xml version="1.0"?>
      <response>
          <order>
              <transaction_id>482d599bbcc7795727650330ad65fe9b</transaction_id>
              <amount>123</amount>
              <currency>EUR</currency>
              <payed>true</payed>
              <status>Success</status>
              <consumer>
                  <consumerName>Hr J Janssen</consumerName>
                  <consumerAccount>P001234567</consumerAccount>
                  <consumerCity>Amsterdam</consumerCity>
              </consumer>
              <message>This iDEAL-order has successfuly been payed for, and this is the first time you check it.</message>
          </order>
      </response>
  XML

  def setup
    @required_options = { :partner_id => '1234567' }
    @notification = MollieIdeal::Notification.new("transaction_id=482d599bbcc7795727650330ad65fe9b", @required_options)
  end

  def test_accessors
    assert @notification.complete?
    assert_equal "482d599bbcc7795727650330ad65fe9b", @notification.transaction_id
    assert_equal "1234567", @notification.partner_id
  end

  def test_acknowledgement_sets_parameters
    MollieIdeal.expects(:mollie_api_request).returns(REXML::Document.new(CHECK_XML_RESPONSE))
    assert @notification.acknowledge

    assert_equal 'Completed', @notification.status
    assert_equal "EUR", @notification.currency
    assert_equal 123, @notification.gross_cents

    assert_equal "Hr J Janssen", @notification.params['consumer_name']
    assert_equal "P001234567", @notification.params['consumer_account']
    assert_equal "Amsterdam", @notification.params['consumer_city']
    assert_equal "true", @notification.params['paid']
  end

  def test_duplicate_acknowledgement
    duplicate_check_response = CHECK_XML_RESPONSE.
      sub('<status>Success</status>', '<status>CheckedBefore</status>').
      sub('<payed>true</payed>', '<payed>false</payed>')

    MollieIdeal.expects(:mollie_api_request).returns(REXML::Document.new(duplicate_check_response))
    assert !@notification.acknowledge
    assert_equal 'Failed', @notification.status
  end

  def test_respond_to_acknowledge
    assert @notification.respond_to?(:acknowledge)
  end

  def test_raises_without_required_options
    assert_raises(ArgumentError) { MollieIdeal::Notification.new("", :partner_id => '123') }
    assert_raises(ArgumentError) { MollieIdeal::Notification.new('transaction_id=123', {}) }
  end

  def test_accepts_crential1_instead_of_partner_id
    notification = MollieIdeal::Notification.new('transaction_id=123', :credential1 => '123')
    assert_equal '123', notification.partner_id
  end
end
