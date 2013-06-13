require 'test_helper'

class PaydollarNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @notification = Paydollar::Notification.new(http_raw_data)
  end

  def test_accessors
    assert_equal "0", @notification.status
    assert_equal "Order_PD_1000", @notification.item_id
    assert_equal "100.94", @notification.gross
    assert_equal "0", @notification.primary_bank_host_status_code
    assert_equal "0", @notification.secondary_bank_host_status_code
    assert_equal "12345678", @notification.bank_reference_orderid
    assert_equal "1151801", @notification.paydollar_ref
    assert_equal "testing card", @notification.holder_name
    assert_equal "344", @notification.currency
    assert_equal "151801", @notification.approval_code
    assert_equal "R14", @notification.alert_code
    assert_equal "07", @notification.eci
    assert_equal "", @notification.remark
    assert_equal "U", @notification.payer_auth_status
    assert_equal "IN", @notification.ip_country
    assert_equal "192.168.1.100", @notification.payer_ip
    assert_equal "Master", @notification.payment_method
    assert_equal "2013-06-05 20:25:38.0", @notification.transaction_time
    assert_equal "5422", @notification.pan_first4
    assert_equal "0007", @notification.pan_last4
    assert_equal "HK", @notification.card_issuing_country
    assert_equal "SPC", @notification.channel_type
    assert_equal "1234", @notification.merchant_id
    assert_equal "2345", @notification.account_hash
    assert_equal "SHA-1", @notification.account_hash_algo
    assert_equal "700", @notification.mps_amount
    assert_equal "INR", @notification.mps_currency
    assert_equal "89", @notification.mps_foreign_amount
    assert_equal "USD", @notification.mps_foreign_currency
    assert_equal "56", @notification.mps_exchange_rate
    assert_equal "11", @notification.master_schedule_payment_id
    assert_equal "12", @notification.detail_schedule_payment_id
    assert_equal "36", @notification.installment_period_in_mnths
    assert_equal "2000", @notification.installment_first_pay_amt
    assert_equal "1500", @notification.installment_each_pay_amt
    assert_equal "500", @notification.installment_last_pay_amt
  end

  # Replace with real secret key code
  def test_approved_with_secret_hash
    assert @notification.approved?("put the actual hash")
  end

  def test_approved_without_secret_hash
    assert @notification.approved?(nil)
  end

  private
  def http_raw_data
    "mpsAmt=700&mpsCur=INR&mpsForeignAmt=89&mpsForeignCur=USD&mpsRate=56&mSchPayId=11&dSchPayId=12&installment_period=36&installment_firstPayAmt=2000&installment_eachPayAmt=1500&installment_lastPayAmt=500&accountHash=2345&accountHashAlgo=SHA-1&prc=0&src=0&Ord=12345678&Ref=Order_PD_1000&PayRef=1151801&successcode=0&Amt=100.94&Cur=344&Holder=testing card&AuthId=151801&AlertCode=R14&remark=&eci=07&payerAuth=U&sourceIp=192.168.1.100&ipCountry=IN&payMethod=Master&TxTime=2013-06-05 20:25:38.0&panFirst4=5422&panLast4=0007&cardIssuingCountry=HK&channelType=SPC&MerchantId=1234&secureHash=13093E844878D1C40107681B02A0BEE9BD99146D"
  end
end
