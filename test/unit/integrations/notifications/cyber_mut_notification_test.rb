require 'test_helper'

class CyberMutNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @cyber_mut = CyberMut::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @cyber_mut.complete?
    assert_equal "payetest", @cyber_mut.status
    assert_equal "ABERTYP00145", @cyber_mut.transaction_id
    assert_equal "LeTexteLibre", @cyber_mut.item_id
    assert_equal "62.75", @cyber_mut.gross
    assert_equal "EUR", @cyber_mut.currency
    assert_equal Time.parse('05/12/2006 11:55:23'), @cyber_mut.received_at
    assert @cyber_mut.test?
  end

  def test_compositions
    assert_equal Money.new(6275, 'EUR'), @cyber_mut.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @cyber_mut.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "TPE=1234567&date=05%2f12%2f2006%5fa%5f11%3a55%3a23&montant=62%2e75EUR&reference=ABERTYP00145&MAC=e4359a2c18d86cf2e4b0e646016c202e89947b04&texte-libre=LeTexteLibre&code-retour=payetest&cvx=oui&vld=1208&brand=VI&status3ds=1&numauto=010101&originecb=FRA&bincb=010101&hpancb=74E94B03C22D786E0F2C2CADBFC1C00B004B7C45&ipclient=127%2e0%2e0%2e1&originetr=FRA&veres=Y&pares=Y"
  end
end
