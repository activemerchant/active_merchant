require 'test_helper'

class PayflowLinkNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @payflow = ActiveMerchant::Billing::Integrations::PayflowLink.notification(http_raw_data)
  end

  def test_accessors
    assert @payflow.complete?
    assert_equal "Completed", @payflow.status
    assert_equal "V24A0C03E977", @payflow.transaction_id
    assert_equal "S", @payflow.type
    assert_equal "21.30", @payflow.gross
    assert_equal "20" , @payflow.item_id
    assert_equal "1111" , @payflow.account
    assert_equal "2011-08-03T10:05:41+00:00", @payflow.received_at.to_s
    assert @payflow.test?
  end

  def test_payment_successful_status
    notification = PayflowLink::Notification.new('RESULT=0')
    assert_equal 'Completed', notification.status
  end

  def test_missing_transittime
    notification = PayflowLink::Notification.new('')
    assert_nil notification.received_at
  end

  def test_invalid_transittime
    notification = PayflowLink::Notification.new('TRANSTIME=magic')
    assert_nil notification.received_at
  end
  
  def test_payment_failure_status
    notification = PayflowLink::Notification.new('RESULT=7')
    assert_equal 'Failed', notification.status
  end

  def test_respond_to_acknowledge
    assert @payflow.respond_to?(:acknowledge)
  end

  def test_item_id_mapping
    notification = PayflowLink::Notification.new('USER1=1')
    assert_equal '1', notification.item_id
  end

  def test_invoice_mapping
    notification = PayflowLink::Notification.new('INVNUM=1')
    assert_equal '1', notification.invoice
  end
  
  private

  def http_raw_data
    "AVSZIP=Y&STATE=ON&TYPE=S&USER4=&ZIPTOSHIP=&ACCT=1111&EMAIL=&EMAILTOSHIP=&ADDRESSTOSHIP=&METHOD=CC&TRANSTIME=2011-08-03+10%3A05%3A41&USER8=&USER5=&IAVS=N&STATETOSHIP=&USER3=&PHONETOSHIP=&USER7=&TAX=&CARDTYPE=1&AVSDATA=YYY&CITYTOSHIP=&USER6=&PROCAVS=Y&INVNUM=&CITY=Ottawa&USER1=20&DESCRIPTION=Shop+One+store+purchase.+Order+1008&HOSTCODE=A&RESULT=0&USER10=&USER2=true&FAX=&PONUM=&LASTNAME=Doe&PNREF=V24A0C03E977&PHONE=6132623672&AMT=21.30&NAMETOSHIP=&ZIP=K1p4l2&AUTHCODE=026PNI&EXPDATE=0522&RESPMSG=Approved&COUNTRY=&CUSTID=&ORIGMETHOD=&FIRSTNAME=John&USER9=&FAXTOSHIP=&AVSADDR=Y&NAME=John+Doe+&COUNTRYTOSHIP=&ADDRESS=43+Somewhere+Street+"
  end  
end
