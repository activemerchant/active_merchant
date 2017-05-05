require 'test_helper'

class MollieIdealNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @required_options = { :credential1 => '1234567' }
    @notification = MollieIdeal::Notification.new("id=tr_h2PhlwFaX8", @required_options)

    MollieIdeal::API.stubs(:new).with('1234567').returns(@mock_api = mock())
  end

  def test_accessors
    assert @notification.complete?
    assert_equal "tr_h2PhlwFaX8", @notification.transaction_id
    assert_equal "1234567", @notification.api_key
  end

  def test_acknowledgement_sets_params
    @mock_api.expects(:get_request).returns(SUCCESSFUL_CHECK_PAYMENT_STATUS_RESPONSE)
    assert @notification.acknowledge

    assert_equal 'Completed', @notification.status
    assert_equal "EUR", @notification.currency
    assert_equal 12345, @notification.gross_cents
    assert_equal "123.45", @notification.gross
    assert_equal Money.new(12345, 'EUR'), @notification.amount

    assert_equal "123", @notification.item_id
  end

  def test_respond_to_acknowledge
    assert @notification.respond_to?(:acknowledge)
  end

  def test_raises_without_required_options
    assert_raises(ArgumentError) { MollieIdeal::Notification.new("", :credential1 => '123') }
    assert_raises(ArgumentError) { MollieIdeal::Notification.new('id=123', {}) }
  end

  SUCCESSFUL_CHECK_PAYMENT_STATUS_RESPONSE = JSON.parse(<<-JSON)
    {
      "id":"tr_h2PhlwFaX8",
      "mode":"test",
      "createdDatetime":"2014-03-03T10:17:05.0Z",
      "status":"paid",
      "amount":"123.45",
      "description":"My order description",
      "method":"ideal",
      "metadata":{
        "order":"123"
      },
      "details":null,
      "links":{
        "paymentUrl":"https://www.mollie.nl/paymentscreen/ideal/testmode?transaction_id=20a5a25c2bce925b4fabefd0410927ca&bank_trxid=0148703115482464",
        "redirectUrl":"https://example.com/return"
      }
    }
  JSON

  PENDING_CHECK_PAYMENT_STATUS_RESPONSE = JSON.parse(<<-JSON)
    {
      "id":"tr_h2PhlwFaX8",
      "mode":"test",
      "createdDatetime":"2014-03-03T10:17:05.0Z",
      "status":"open",
      "amount":"123.45",
      "description":"My order description",
      "method":"ideal",
      "metadata":{
        "order":"123"
      },
      "details":null,
      "links":{
        "paymentUrl":"https://www.mollie.nl/paymentscreen/ideal/testmode?transaction_id=20a5a25c2bce925b4fabefd0410927ca&bank_trxid=0148703115482464",
        "redirectUrl":"https://example.com/return"
      }
    }
  JSON
end
