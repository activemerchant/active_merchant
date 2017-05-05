require 'test_helper'

class WebmoneyNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @webmoney = Webmoney::Notification.new(http_raw_data, :secret => 'qert1234qee')
  end

  def test_accessors
    assert_equal "1.00", @webmoney.gross
    assert_equal "123",  @webmoney.item_id
    assert_equal BigDecimal.new("1"), @webmoney.amount
  end

  def test_acknowledgement
    assert @webmoney.acknowledge
  end

  def test_respond_to_acknowledge
    assert @webmoney.respond_to?(:acknowledge)
  end

  def test_wrong_signature
    @webmoney = Webmoney::Notification.new(http_raw_data_with_wrong_signature, :secret => 'qert1234qee')
    assert !@webmoney.acknowledge
  end

  private

  def http_raw_data
    "LMI_MODE=1&LMI_PAYMENT_AMOUNT=1.00&LMI_PAYEE_PURSE=Z133417776395&LMI_PAYMENT_NO=123&LMI_PAYER_WM=273350110703&LMI_PAYER_PURSE=Z133417776395&LMI_SYS_INVS_NO=8&LMI_SYS_TRANS_NO=708&LMI_SYS_TRANS_DATE=20120823+15%3A54%3A01&LMI_HASH=F5E7A18237B73D4A7E620CCFC065D8FC&LMI_PAYMENT_DESC=Request+to+webmoney+%23123&LMI_LANG=ru-RU&LMI_DBLCHK=SMS"
  end

  def http_raw_data_with_wrong_signature
    "LMI_MODE=1&LMI_PAYMENT_AMOUNT=1.00&LMI_PAYEE_PURSE=Z133417776395&LMI_PAYMENT_NO=123&LMI_PAYER_WM=273350110703&LMI_PAYER_PURSE=Z133417776395&LMI_SYS_INVS_NO=8&LMI_SYS_TRANS_NO=708&LMI_SYS_TRANS_DATE=20120823+15%3A54%3A01&LMI_HASH=QWEE123237B73D4A7E620CCFC065D8FC&LMI_PAYMENT_DESC=Request+to+webmoney+%23123&LMI_LANG=ru-RU&LMI_DBLCHK=SMS"
  end
end
