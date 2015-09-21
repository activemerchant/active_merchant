require 'test_helper'

class RemoteVelocityTest < Test::Unit::TestCase
  def setup
    @gateway = ActiveMerchant::Billing::VelocityGateway.new("PHNhbWw6QXNzZXJ0aW9uIE1ham9yVmVyc2lvbj0iMSIgTWlub3JWZXJzaW9uPSIxIiBBc3NlcnRpb25JRD0iXzdlMDhiNzdjLTUzZWEtNDEwZC1hNmJiLTAyYjJmMTAzMzEwYyIgSXNzdWVyPSJJcGNBdXRoZW50aWNhdGlvbiIgSXNzdWVJbnN0YW50PSIyMDE0LTEwLTEwVDIwOjM2OjE4LjM3OVoiIHhtbG5zOnNhbWw9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjEuMDphc3NlcnRpb24iPjxzYW1sOkNvbmRpdGlvbnMgTm90QmVmb3JlPSIyMDE0LTEwLTEwVDIwOjM2OjE4LjM3OVoiIE5vdE9uT3JBZnRlcj0iMjA0NC0xMC0xMFQyMDozNjoxOC4zNzlaIj48L3NhbWw6Q29uZGl0aW9ucz48c2FtbDpBZHZpY2U+PC9zYW1sOkFkdmljZT48c2FtbDpBdHRyaWJ1dGVTdGF0ZW1lbnQ+PHNhbWw6U3ViamVjdD48c2FtbDpOYW1lSWRlbnRpZmllcj5GRjNCQjZEQzU4MzAwMDAxPC9zYW1sOk5hbWVJZGVudGlmaWVyPjwvc2FtbDpTdWJqZWN0PjxzYW1sOkF0dHJpYnV0ZSBBdHRyaWJ1dGVOYW1lPSJTQUsiIEF0dHJpYnV0ZU5hbWVzcGFjZT0iaHR0cDovL3NjaGVtYXMuaXBjb21tZXJjZS5jb20vSWRlbnRpdHkiPjxzYW1sOkF0dHJpYnV0ZVZhbHVlPkZGM0JCNkRDNTgzMDAwMDE8L3NhbWw6QXR0cmlidXRlVmFsdWU+PC9zYW1sOkF0dHJpYnV0ZT48c2FtbDpBdHRyaWJ1dGUgQXR0cmlidXRlTmFtZT0iU2VyaWFsIiBBdHRyaWJ1dGVOYW1lc3BhY2U9Imh0dHA6Ly9zY2hlbWFzLmlwY29tbWVyY2UuY29tL0lkZW50aXR5Ij48c2FtbDpBdHRyaWJ1dGVWYWx1ZT5iMTVlMTA4MS00ZGY2LTQwMTYtODM3Mi02NzhkYzdmZDQzNTc8L3NhbWw6QXR0cmlidXRlVmFsdWU+PC9zYW1sOkF0dHJpYnV0ZT48c2FtbDpBdHRyaWJ1dGUgQXR0cmlidXRlTmFtZT0ibmFtZSIgQXR0cmlidXRlTmFtZXNwYWNlPSJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcyI+PHNhbWw6QXR0cmlidXRlVmFsdWU+RkYzQkI2REM1ODMwMDAwMTwvc2FtbDpBdHRyaWJ1dGVWYWx1ZT48L3NhbWw6QXR0cmlidXRlPjwvc2FtbDpBdHRyaWJ1dGVTdGF0ZW1lbnQ+PFNpZ25hdHVyZSB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnIyI+PFNpZ25lZEluZm8+PENhbm9uaWNhbGl6YXRpb25NZXRob2QgQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiPjwvQ2Fub25pY2FsaXphdGlvbk1ldGhvZD48U2lnbmF0dXJlTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnI3JzYS1zaGExIj48L1NpZ25hdHVyZU1ldGhvZD48UmVmZXJlbmNlIFVSST0iI183ZTA4Yjc3Yy01M2VhLTQxMGQtYTZiYi0wMmIyZjEwMzMxMGMiPjxUcmFuc2Zvcm1zPjxUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjZW52ZWxvcGVkLXNpZ25hdHVyZSI+PC9UcmFuc2Zvcm0+PFRyYW5zZm9ybSBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMTAveG1sLWV4Yy1jMTRuIyI+PC9UcmFuc2Zvcm0+PC9UcmFuc2Zvcm1zPjxEaWdlc3RNZXRob2QgQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjc2hhMSI+PC9EaWdlc3RNZXRob2Q+PERpZ2VzdFZhbHVlPnl3NVZxWHlUTUh5NUNjdmRXN01TV2RhMDZMTT08L0RpZ2VzdFZhbHVlPjwvUmVmZXJlbmNlPjwvU2lnbmVkSW5mbz48U2lnbmF0dXJlVmFsdWU+WG9ZcURQaUorYy9IMlRFRjNQMWpQdVBUZ0VDVHp1cFVlRXpESERwMlE2ZW92T2lhN0pkVjI1bzZjTk1vczBTTzRISStSUGRUR3hJUW9xa0paeEtoTzZHcWZ2WHFDa2NNb2JCemxYbW83NUFSWU5jMHdlZ1hiQUVVQVFCcVNmeGwxc3huSlc1ZHZjclpuUytkSThoc2lZZW4vT0VTOUdtZUpsZVd1WUR4U0xmQjZJZnd6dk5LQ0xlS0FXenBkTk9NYmpQTjJyNUJWQUhQZEJ6WmtiSGZwdUlablp1Q2l5OENvaEo1bHU3WGZDbXpHdW96VDVqVE0wU3F6bHlzeUpWWVNSbVFUQW5WMVVGMGovbEx6SU14MVJmdWltWHNXaVk4c2RvQ2IrZXpBcVJnbk5EVSs3NlVYOEZFSEN3Q2c5a0tLSzQwMXdYNXpLd2FPRGJJUFpEYitBPT08L1NpZ25hdHVyZVZhbHVlPjxLZXlJbmZvPjxvOlNlY3VyaXR5VG9rZW5SZWZlcmVuY2UgeG1sbnM6bz0iaHR0cDovL2RvY3Mub2FzaXMtb3Blbi5vcmcvd3NzLzIwMDQvMDEvb2FzaXMtMjAwNDAxLXdzcy13c3NlY3VyaXR5LXNlY2V4dC0xLjAueHNkIj48bzpLZXlJZGVudGlmaWVyIFZhbHVlVHlwZT0iaHR0cDovL2RvY3Mub2FzaXMtb3Blbi5vcmcvd3NzL29hc2lzLXdzcy1zb2FwLW1lc3NhZ2Utc2VjdXJpdHktMS4xI1RodW1icHJpbnRTSEExIj5ZREJlRFNGM0Z4R2dmd3pSLzBwck11OTZoQ2M9PC9vOktleUlkZW50aWZpZXI+PC9vOlNlY3VyaXR5VG9rZW5SZWZlcmVuY2U+PC9LZXlJbmZvPjwvU2lnbmF0dXJlPjwvc2FtbDpBc3NlcnRpb24+", "2317000001", "14560" , "PrestaShop Global HC")
    @creditcard =  ActiveMerchant::Billing::CreditCard.new(brand: 'visa', verification_value: "123", month:"06", year: '2020', number:'4012888812348882', name: 'John Doe')
    @creditcard_without_pan =  ActiveMerchant::Billing::CreditCard.new(brand: 'visa', verification_value: "123", month:"06", year: '2020', number:'', name: 'John Doe')

  end

  def test_successful_verify
    assert response = @gateway.verify(10.00, @creditcard, {:address => {Street: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'},Track2Data: '4012000033330026=09041011000012345678',EntryMode: 'TrackDataFromMSR', :IndustryType=>"Ecommerce"})
    assert_equal 'The Transaction was Successful', response.message 
    assert_equal Response, response.class
    assert_success response
  end

  def test_successful_authorize
    assert response = @gateway.authorize(10.00, @creditcard, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802'})
    assert_equal 'The Transaction was Successful', response.message
    assert_equal Response, response.class
    assert_success response
  end

  def test_failed_authorize_with_pan
    assert response = @gateway.authorize(10.00, @creditcard_without_pan, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802'})
    assert_equal 'Validation Errors Occurred'.to_s, response.message.to_s
    assert_equal Response, response.class
    assert_failure response
  end

  def test_successful_purchase
    assert response = @gateway.purchase(10.00, @creditcard, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802',Phone: '9540123123',Email: 'najeers@chetu.com'})
    assert_equal 'The Transaction was Successful', response.message
    assert_equal Response, response.class
    assert_success response
  end

  def test_failed_purchase_with_pan
    assert response = @gateway.purchase(10.00, @creditcard_without_pan, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802',Phone: '9540123123',Email: 'najeers@chetu.com'})
    assert_equal 'Validation Errors Occurred'.to_s, response.message.to_s
    assert_equal Response, response.class
    assert_failure response
  end


  def test_successful_capture
    assert response_auth = @gateway.authorize(10.00, @creditcard, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802'})
    assert response_capture = @gateway.capture(10.00,response_auth.params["transction_id"])
    assert_equal 'The Transaction was Successful', response_capture.message
    assert_equal Response, response_capture.class
    assert_success response_capture
  end

  def test_failed_capture
    assert response = @gateway.capture(10.00,'A34E09B69D6D4B039F59CA7701F818D4')
    assert_equal 'Transaction no longer active due to Capture'.to_s, response.message.to_s
    assert_equal Response, response.class
    assert_failure response
  end

  def test_successful_refund
    assert response_purchase = @gateway.purchase(10.00, @creditcard, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802',Phone: '9540123123',Email: 'najeers@chetu.com'})
    assert response_refund = @gateway.refund(10.00,response_purchase.params["transction_id"])
    assert_equal 'The Transaction was Successful', response_refund.message
    assert_equal Response, response_refund.class
    assert_success response_refund
  end

  def test_failed_refund
    assert response = @gateway.refund(10.00,'882D997379344C01B19A26584A60B930')
    assert_equal 'Attempt to return more than original authorization.', response.message.to_s
    assert_equal Response, response.class
    assert_failure response
  end

  def test_failed_refund_due_to_capture
    assert response = @gateway.refund(10.00,'81C3BB4C265749099D6B930ACB65116F')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction cannot be Returned as it has not been Captured.  Use Undo instead.', response.message.to_s
  end

  def test_failed_refund_due_to_undo
    assert response = @gateway.refund(10.00,'3E45D9DFD0C24E1C9224AE0E23B0DAED')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction no longer active due to Undo', response.message.to_s
  end

  def test_successful_void
    assert response_auth = @gateway.authorize(10.00, @creditcard, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802'})
    assert response_void = @gateway.void(response_auth.params["transction_id"])
    assert_equal 'The Transaction was Successful', response_void.message
    assert_equal Response, response_void.class
    assert_success response_void
  end

  def test_failed_undo_due_to_capture
    assert response = @gateway.void('C37A4ACDCA1340E2B458FBA7CDA76785')
    assert_equal 'Transaction no longer active due to Capture.  Use Return instead.'.to_s, response.message.to_s
    assert_equal Response, response.class
    assert_failure response
  end

  def test_failed_undo_due_to_undone
    assert response = @gateway.void('3E45D9DFD0C24E1C9224AE0E23B0DAED')
    assert_equal 'Transaction has already been Undone.'.to_s, response.message.to_s
    assert_equal Response, response.class
    assert_failure response
  end   

end