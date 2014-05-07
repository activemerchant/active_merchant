require 'test_helper'

class PxPayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
  end

  def test_successful_transaction_notification
    Pxpay::Notification.any_instance.expects(:ssl_post).returns(successful_xml_response)
    notification = Pxpay::Notification.new(http_post_data, :credential1 => 'user', :credential2 => 'key')

    assert notification.acknowledge
    assert_match "Completed", notification.status
    assert_match "157.00", notification.gross
    assert_match "00000008096f3c7a", notification.transaction_id
    assert_match "1", notification.item_id
  end

  def test_failed_transaction_notification
    Pxpay::Notification.any_instance.expects(:ssl_post).returns(failed_xml_response)
    notification = Pxpay::Notification.new(http_post_data, :credential1 => 'user', :credential2 => 'key')

    assert notification.acknowledge
    assert_match "Failed", notification.status
    assert_match "100", notification.item_id
  end

  def test_exception_without_credentials
    assert_raise ArgumentError do
      notification = Pxpay::Notification.new(http_post_data)
    end
  end

  def test_exception_without_http_params
    assert_raise ArgumentError do
      notification = Pxpay::Notification.new("", :credential1 => 'user', :credential2 => 'pass')
    end
  end

  private

  def http_post_data
    "result=v5OKdyEkGAkbwMhFgpYUH7ImWB0CAu1r_skOZkoZrcrgWbrb9RR-Vp1DVXygfuuHutktZ-I_KMWD2lyL9bX8-8CNEE_g2BRRRM1Ay4JQUhnsKd5WP8Y6QTxLo6njihiaMduzaWlEjxBzrzqSUF4GSMPIzdOtPFwaXlOutqsEBBOLFvvjE_YM88RJittIiS_QBpQDIMXLvrT0-qEMMtddnNUfq7u6nb9qoWCTbAygIY0YjzPL01f0M8tKc_x3hjVF19k2x7KD5yoSmy4PfN-RhWsqfMO69q83pyhu3whChC5mBbJHXC6Mhpjcyw__MD7V8meLkB5ulgRRtOTCznoRsruVOKeHP7m6Cd1KWrgas-ErIIE8mxLtdf5ZAz0J9asaGfm_GfJ8QHiCHqBNFivBp5z5qJgO4EGZvU7uWTRQM6kVFiBqm7ZBG1w9FxSqIkIYOrGepneA7aEALeF1kdwq0I2A==&userid=PxPayUser"
  end

  def successful_xml_response
    '<Response valid="1"><Success>1</Success><TxnType>Purchase</TxnType><CurrencyInput>USD</CurrencyInput><MerchantReference>1</MerchantReference><TxnData1></TxnData1><TxnData2></TxnData2><TxnData3></TxnData3><AuthCode>035411</AuthCode><CardName>Visa</CardName><CardHolderName>FIRSTNAME LASTNAME</CardHolderName><CardNumber>411111........11</CardNumber><DateExpiry>1220</DateExpiry><ClientInfo>67.210.173.114</ClientInfo><EmailAddress>g@g.com</EmailAddress><DpsTxnRef>00000008096f3c7a</DpsTxnRef><BillingId></BillingId><DpsBillingId></DpsBillingId><AmountSettlement>157.00</AmountSettlement><CurrencySettlement>USD</CurrencySettlement><DateSettlement>20120731</DateSettlement><TxnMac>2BC29AF2</TxnMac><ResponseText>APPROVED</ResponseText><CardNumber2></CardNumber2><IssuerCountryId>0</IssuerCountryId></Response>'
  end

  def failed_xml_response
    '<Response valid="1"><Success>0</Success><TxnType>Purchase</TxnType><CurrencyInput>USD</CurrencyInput><MerchantReference>100</MerchantReference><TxnData1></TxnData1><TxnData2></TxnData2><TxnData3></TxnData3><AuthCode></AuthCode><CardName>Visa</CardName><CardHolderName>FIRSTNAME LASTNAME</CardHolderName><CardNumber>411111........12</CardNumber><DateExpiry>1210</DateExpiry><ClientInfo>67.210.173.114</ClientInfo><EmailAddress>g@g.com</EmailAddress><DpsTxnRef>00000008096fa1b2</DpsTxnRef><BillingId></BillingId><DpsBillingId></DpsBillingId><AmountSettlement>157.00</AmountSettlement><CurrencySettlement>USD</CurrencySettlement><DateSettlement>20120731</DateSettlement><TxnMac></TxnMac><ResponseText>DECLINED</ResponseText><CardNumber2></CardNumber2><IssuerCountryId>0</IssuerCountryId></Response>'
  end

  def invalid_xml_response
  end
end
