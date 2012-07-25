require 'test_helper'

class PaxumNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paxum = Paxum::Notification.new(http_raw_data, :secret => 'secret')
  end

  def test_acknowledgement
    assert @paxum.acknowledge
  end

  def test_respond_to_acknowledge
    assert @paxum.respond_to?(:acknowledge)
  end

  def test_wrong_signature
    @paxum = Robokassa::Notification.new(http_raw_data_with_wrong_signature, :secret => 'secret')
    assert !@paxum.acknowledge
  end

  private

  def http_raw_data
    "buyer_username=user@paxum.com&test=0&buyer_name=Alexander Smirnov&buyer_contact_phone=7123123123&buyer_email=user@paxum.com&buyer_id=23315&buyer_status=verified&resend=false&transaction_id=6599376&transaction_description=Received money from user@paxum.com&transaction_item_id=123&transaction_item_name=Request to paxum #123&transaction_amount=1&transaction_status=done&transaction_exchange_rate=1.00&transaction_currency=USD&transaction_date=2012-07-19&transaction_type=14&transaction_quantity=1&key=7933f7bf5a6a5deeebbc3dcca7b70fe4"
  end

  def http_raw_data_with_wrong_signature
    "buyer_username=user@paxum.com&test=0&buyer_name=Alexander Smirnov&buyer_contact_phone=7123123123&buyer_email=user@paxum.com&buyer_id=23315&buyer_status=verified&resend=false&transaction_id=6599376&transaction_description=Received money from user@paxum.com&transaction_item_id=123&transaction_item_name=Request to paxum #123&transaction_amount=1&transaction_status=done&transaction_exchange_rate=1.00&transaction_currency=USD&transaction_date=2012-07-19&transaction_type=14&key=7933f7bf5a6a5deeebbc3dcca7b70fe4"
  end
end
