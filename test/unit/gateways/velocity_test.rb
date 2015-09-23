require 'test_helper'

class VelocityTest < Test::Unit::TestCase

  def setup
   @gateway = VelocityGateway.new("PHNhbWw6QXNzZXJ0aW9uIE1ham9yVmVyc2lvbj0iMSIgTWlub3JWZXJzaW9uPSIxIiBBc3NlcnRpb25JRD0iXzdlMDhiNzdjLTUzZWEtNDEwZC1hNmJiLTAyYjJmMTAzMzEwYyIgSXNzdWVyPSJJcGNBdXRoZW50aWNhdGlvbiIgSXNzdWVJbnN0YW50PSIyMDE0LTEwLTEwVDIwOjM2OjE4LjM3OVoiIHhtbG5zOnNhbWw9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjEuMDphc3NlcnRpb24iPjxzYW1sOkNvbmRpdGlvbnMgTm90QmVmb3JlPSIyMDE0LTEwLTEwVDIwOjM2OjE4LjM3OVoiIE5vdE9uT3JBZnRlcj0iMjA0NC0xMC0xMFQyMDozNjoxOC4zNzlaIj48L3NhbWw6Q29uZGl0aW9ucz48c2FtbDpBZHZpY2U+PC9zYW1sOkFkdmljZT48c2FtbDpBdHRyaWJ1dGVTdGF0ZW1lbnQ+PHNhbWw6U3ViamVjdD48c2FtbDpOYW1lSWRlbnRpZmllcj5GRjNCQjZEQzU4MzAwMDAxPC9zYW1sOk5hbWVJZGVudGlmaWVyPjwvc2FtbDpTdWJqZWN0PjxzYW1sOkF0dHJpYnV0ZSBBdHRyaWJ1dGVOYW1lPSJTQUsiIEF0dHJpYnV0ZU5hbWVzcGFjZT0iaHR0cDovL3NjaGVtYXMuaXBjb21tZXJjZS5jb20vSWRlbnRpdHkiPjxzYW1sOkF0dHJpYnV0ZVZhbHVlPkZGM0JCNkRDNTgzMDAwMDE8L3NhbWw6QXR0cmlidXRlVmFsdWU+PC9zYW1sOkF0dHJpYnV0ZT48c2FtbDpBdHRyaWJ1dGUgQXR0cmlidXRlTmFtZT0iU2VyaWFsIiBBdHRyaWJ1dGVOYW1lc3BhY2U9Imh0dHA6Ly9zY2hlbWFzLmlwY29tbWVyY2UuY29tL0lkZW50aXR5Ij48c2FtbDpBdHRyaWJ1dGVWYWx1ZT5iMTVlMTA4MS00ZGY2LTQwMTYtODM3Mi02NzhkYzdmZDQzNTc8L3NhbWw6QXR0cmlidXRlVmFsdWU+PC9zYW1sOkF0dHJpYnV0ZT48c2FtbDpBdHRyaWJ1dGUgQXR0cmlidXRlTmFtZT0ibmFtZSIgQXR0cmlidXRlTmFtZXNwYWNlPSJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcyI+PHNhbWw6QXR0cmlidXRlVmFsdWU+RkYzQkI2REM1ODMwMDAwMTwvc2FtbDpBdHRyaWJ1dGVWYWx1ZT48L3NhbWw6QXR0cmlidXRlPjwvc2FtbDpBdHRyaWJ1dGVTdGF0ZW1lbnQ+PFNpZ25hdHVyZSB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnIyI+PFNpZ25lZEluZm8+PENhbm9uaWNhbGl6YXRpb25NZXRob2QgQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiPjwvQ2Fub25pY2FsaXphdGlvbk1ldGhvZD48U2lnbmF0dXJlTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnI3JzYS1zaGExIj48L1NpZ25hdHVyZU1ldGhvZD48UmVmZXJlbmNlIFVSST0iI183ZTA4Yjc3Yy01M2VhLTQxMGQtYTZiYi0wMmIyZjEwMzMxMGMiPjxUcmFuc2Zvcm1zPjxUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjZW52ZWxvcGVkLXNpZ25hdHVyZSI+PC9UcmFuc2Zvcm0+PFRyYW5zZm9ybSBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMTAveG1sLWV4Yy1jMTRuIyI+PC9UcmFuc2Zvcm0+PC9UcmFuc2Zvcm1zPjxEaWdlc3RNZXRob2QgQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjc2hhMSI+PC9EaWdlc3RNZXRob2Q+PERpZ2VzdFZhbHVlPnl3NVZxWHlUTUh5NUNjdmRXN01TV2RhMDZMTT08L0RpZ2VzdFZhbHVlPjwvUmVmZXJlbmNlPjwvU2lnbmVkSW5mbz48U2lnbmF0dXJlVmFsdWU+WG9ZcURQaUorYy9IMlRFRjNQMWpQdVBUZ0VDVHp1cFVlRXpESERwMlE2ZW92T2lhN0pkVjI1bzZjTk1vczBTTzRISStSUGRUR3hJUW9xa0paeEtoTzZHcWZ2WHFDa2NNb2JCemxYbW83NUFSWU5jMHdlZ1hiQUVVQVFCcVNmeGwxc3huSlc1ZHZjclpuUytkSThoc2lZZW4vT0VTOUdtZUpsZVd1WUR4U0xmQjZJZnd6dk5LQ0xlS0FXenBkTk9NYmpQTjJyNUJWQUhQZEJ6WmtiSGZwdUlablp1Q2l5OENvaEo1bHU3WGZDbXpHdW96VDVqVE0wU3F6bHlzeUpWWVNSbVFUQW5WMVVGMGovbEx6SU14MVJmdWltWHNXaVk4c2RvQ2IrZXpBcVJnbk5EVSs3NlVYOEZFSEN3Q2c5a0tLSzQwMXdYNXpLd2FPRGJJUFpEYitBPT08L1NpZ25hdHVyZVZhbHVlPjxLZXlJbmZvPjxvOlNlY3VyaXR5VG9rZW5SZWZlcmVuY2UgeG1sbnM6bz0iaHR0cDovL2RvY3Mub2FzaXMtb3Blbi5vcmcvd3NzLzIwMDQvMDEvb2FzaXMtMjAwNDAxLXdzcy13c3NlY3VyaXR5LXNlY2V4dC0xLjAueHNkIj48bzpLZXlJZGVudGlmaWVyIFZhbHVlVHlwZT0iaHR0cDovL2RvY3Mub2FzaXMtb3Blbi5vcmcvd3NzL29hc2lzLXdzcy1zb2FwLW1lc3NhZ2Utc2VjdXJpdHktMS4xI1RodW1icHJpbnRTSEExIj5ZREJlRFNGM0Z4R2dmd3pSLzBwck11OTZoQ2M9PC9vOktleUlkZW50aWZpZXI+PC9vOlNlY3VyaXR5VG9rZW5SZWZlcmVuY2U+PC9LZXlJbmZvPjwvU2lnbmF0dXJlPjwvc2FtbDpBc3NlcnRpb24+", "2317000001", "14560" , "PrestaShop Global HC")
   @creditcard =  ActiveMerchant::Billing::CreditCard.new(brand: 'visa', verification_value: "123", month:"06", year: '2020', number:'4012888812348882', name: 'John Doe')
   @creditcard_without_pan =  ActiveMerchant::Billing::CreditCard.new(brand: 'visa', verification_value: "123", month:"06", year: '2020', number:'', name: 'John Doe')
  end

  def test_successful_verify
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(successful_verify_response)
    assert response = @gateway.verify(10.00, @creditcard, {:address => {Street: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'},Track2Data: '4012000033330026=09041011000012345678',EntryMode: 'TrackDataFromMSR', :IndustryType=>"Ecommerce"})
    assert_instance_of Response, response
    assert_success response
    assert_equal 'The Transaction was Successful', response.message
  end

  def test_successful_authorize
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(successful_authorize_response)
    assert response = @gateway.authorize(10.00, @creditcard, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802'})
    assert_instance_of Response, response
    assert_success response
    assert_equal 'The Transaction was Successful', response.message
  end

  def test_failed_authorize_with_pan
    @gateway.expects(:sign_on).returns(token)    
    @gateway.expects(:raw_ssl_request).returns(failed_authorize_response_with_pan)
    assert response = @gateway.authorize(10.00, @creditcard_without_pan, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802'})
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Validation Errors Occurred', response.message.to_s
  end

  def test_successful_purchase
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)
    assert response = @gateway.purchase(10.00, @creditcard, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802',Phone: '9540123123',Email: 'najeers@chetu.com'})
    assert_instance_of Response, response
    assert_success response
    assert_equal 'The Transaction was Successful', response.message
  end

  def test_failed_purchase_with_pan
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(failed_purchase_response_with_pan)
    assert response = @gateway.purchase(10.00, @creditcard_without_pan, {:address => {Street1: '4 corporate sq',City: 'dever',CountryCode: 'USA',PostalCode: '30329'}, :OrderNumber=>"629203", :EntryMode=>"Keyed", :IndustryType=>"Ecommerce",InvoiceNumber: '802',Phone: '9540123123',Email: 'najeers@chetu.com'})
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Validation Errors Occurred', response.message.to_s
  end

  def test_successful_capture
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(successful_capture_response)
    assert response = @gateway.capture(10.00,'A34E09B69D6D4B039F59CA7701F818D4')
    assert_instance_of Response, response
    assert_success response
    assert_equal 'The Transaction was Successful', response.message
  end

  def test_failed_capture
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(failed_capture_response)
    assert response = @gateway.capture(10.00,'A34E09B69D6D4B039F59CA7701F818D4')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction no longer active due to Capture', response.message.to_s
  end

  def test_successful_refund
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(successful_refund_response)
    assert response = @gateway.refund(10.00,'882D997379344C01B19A26584A60B930')
    assert_instance_of Response, response
    assert_success response
    assert_equal 'The Transaction was Successful', response.message
  end

  def test_failed_refund
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(failed_refund_response)
    assert response = @gateway.refund(10.00,'882D997379344C01B19A26584A60B930')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Attempt to return more than original authorization.', response.message.to_s
  end

  def test_failed_refund_due_to_void
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(failed_refund_due_to_void_response)
    assert response = @gateway.refund(10.00,'882D997379344C01B19A26584A60B930')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction no longer active due to Undo', response.message.to_s
  end

  def test_failed_refund_due_to_autorize_no_capture
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(failed_refund_due_to_autorize_no_capture_response)
    assert response = @gateway.refund(10.00,'882D997379344C01B19A26584A60B930')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction cannot be Returned as it has not been Captured.  Use Undo instead.', response.message.to_s
  end

  def test_failed_refund_due_to_using_same_auth_id_after_capture
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(failed_refund_due_to_using_same_auth_id_after_capture)
    assert response = @gateway.refund(10.00,'E8A1C4B22F9448CCA0E6C85FDFA4DA09')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction cannot be Returned as it has been Captured.  Return the Captured transaction instead.', response.message.to_s
  end

  def test_successful_void
    @gateway.expects(:sign_on).returns(token)    
    @gateway.expects(:raw_ssl_request).returns(successful_void_response)
    assert response = @gateway.void('C37A4ACDCA1340E2B458FBA7CDA76785')
    assert_instance_of Response, response
    assert_success response
    assert_equal 'The Transaction was Successful', response.message
  end

  def test_failed_void
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(failed_void_response)
    assert response = @gateway.void('C37A4ACDCA1340E2B458FBA7CDA76785')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction no longer active due to Capture.  Use Return instead.', response.message.to_s
  end
  
  def test_failed_void_already_undone
    @gateway.expects(:sign_on).returns(token)
    @gateway.expects(:raw_ssl_request).returns(failed_void_already_undone_response)
    assert response = @gateway.void('3E45D9DFD0C24E1C9224AE0E23B0DAED')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction has already been Undone.', response.message.to_s
  end


  private

  def token
     "Basic UEhOaGJXdzZRWE56WlhKMGFXOXVJRTFoYW05eVZtVnljMmx2YmowaU1TSWdUV2x1YjNKV1pYSnphVzl1UFNJeElpQkJjM05sY25ScGIyNUpSRDBpWHpNd1lXRTROMk5tTFRFek56Y3ROREZsWVMxaFpHVmpMVFE1TXpKbVlqQmhPV1JtTkNJZ1NYTnpkV1Z5UFNKSlVFTmZVMFZEVlZKSlZGbGZVMVJUSWlCSmMzTjFaVWx1YzNSaGJuUTlJakl3TVRVdE1Ea3RNVEZVTVRZNk16TTZNVFV1T0RrNFdpSWdlRzFzYm5NNmMyRnRiRDBpZFhKdU9tOWhjMmx6T201aGJXVnpPblJqT2xOQlRVdzZNUzR3T21GemMyVnlkR2x2YmlJK1BITmhiV3c2UTI5dVpHbDBhVzl1Y3lCT2IzUkNaV1p2Y21VOUlqSXdNVFV0TURrdE1URlVNVFk2TVRZNk16VXVPRGs0V2lJZ1RtOTBUMjVQY2tGbWRHVnlQU0l5TURFMUxUQTVMVEV4VkRFM09qQXpPakUxTGpnNU9Gb2lQand2YzJGdGJEcERiMjVrYVhScGIyNXpQanh6WVcxc09rRmtkbWxqWlQ0OEwzTmhiV3c2UVdSMmFXTmxQanh6WVcxc09rRjBkSEpwWW5WMFpWTjBZWFJsYldWdWRENDhjMkZ0YkRwVGRXSnFaV04wUGp4ellXMXNPazVoYldWSlpHVnVkR2xtYVdWeVBrWkdNMEpDTmtSRE5UZ3pNREF3TURFOEwzTmhiV3c2VG1GdFpVbGtaVzUwYVdacFpYSStQSE5oYld3NlUzVmlhbVZqZEVOdmJtWnBjbTFoZEdsdmJqNDhjMkZ0YkRwRGIyNW1hWEp0WVhScGIyNU5aWFJvYjJRK2RYSnVPbTloYzJsek9tNWhiV1Z6T25Sak9sTkJUVXc2TVM0d09tTnRPbWh2YkdSbGNpMXZaaTFyWlhrOEwzTmhiV3c2UTI5dVptbHliV0YwYVc5dVRXVjBhRzlrUGp4TFpYbEpibVp2SUhodGJHNXpQU0pvZEhSd09pOHZkM2QzTG5jekxtOXlaeTh5TURBd0x6QTVMM2h0YkdSemFXY2pJajQ4WlRwRmJtTnllWEIwWldSTFpYa2dlRzFzYm5NNlpUMGlhSFIwY0RvdkwzZDNkeTUzTXk1dmNtY3ZNakF3TVM4d05DOTRiV3hsYm1NaklqNDhaVHBGYm1OeWVYQjBhVzl1VFdWMGFHOWtJRUZzWjI5eWFYUm9iVDBpYUhSMGNEb3ZMM2QzZHk1M015NXZjbWN2TWpBd01TOHdOQzk0Yld4bGJtTWpjbk5oTFc5aFpYQXRiV2RtTVhBaVBqeEVhV2RsYzNSTlpYUm9iMlFnUVd4bmIzSnBkR2h0UFNKb2RIUndPaTh2ZDNkM0xuY3pMbTl5Wnk4eU1EQXdMekE1TDNodGJHUnphV2NqYzJoaE1TSStQQzlFYVdkbGMzUk5aWFJvYjJRK1BDOWxPa1Z1WTNKNWNIUnBiMjVOWlhSb2IyUStQRXRsZVVsdVptOCtQRzg2VTJWamRYSnBkSGxVYjJ0bGJsSmxabVZ5Wlc1alpTQjRiV3h1Y3pwdlBTSm9kSFJ3T2k4dlpHOWpjeTV2WVhOcGN5MXZjR1Z1TG05eVp5OTNjM012TWpBd05DOHdNUzl2WVhOcGN5MHlNREEwTURFdGQzTnpMWGR6YzJWamRYSnBkSGt0YzJWalpYaDBMVEV1TUM1NGMyUWlQanh2T2t0bGVVbGtaVzUwYVdacFpYSWdWbUZzZFdWVWVYQmxQU0pvZEhSd09pOHZaRzlqY3k1dllYTnBjeTF2Y0dWdUxtOXlaeTkzYzNNdmIyRnphWE10ZDNOekxYTnZZWEF0YldWemMyRm5aUzF6WldOMWNtbDBlUzB4TGpFalZHaDFiV0p3Y21sdWRGTklRVEVpUGpGQk9WUnZaSFJ3TkhwdVp5dFJaVkkwU205blNtVmpZamhXYXowOEwyODZTMlY1U1dSbGJuUnBabWxsY2o0OEwyODZVMlZqZFhKcGRIbFViMnRsYmxKbFptVnlaVzVqWlQ0OEwwdGxlVWx1Wm04K1BHVTZRMmx3YUdWeVJHRjBZVDQ4WlRwRGFYQm9aWEpXWVd4MVpUNXNSRlJ3WjJwVk1FaFdXalkwVVd4TFdGQjBkbmhoUjBseU9UUjNNblZqWVZKalNpOVpSR2xXVG5OM1YySnNNRnBKUWtOSGNtMVBXVFJ1YkhKM04zRlRjMEpuVGtwUGVHOUJNM1l6Tkdob1pqUk9RMGxrVEZFMFdqUlJjbnA2T0UwelV6UnpXazVDUW1vNVFVWmtURVF5YUdOMmRUQndjVTVTUzI5RGNrRlVPVVZVZDNrMWREUllRMWw0U0dWU1NEZHBOV1p5WVc5M1NraHBSamhhTm1STWRUUkRkWGgwTWxwM1pXcEdhRFJ6VTJsTU5tRnRWV1YxTVdocGFVczVXRWMzZUhwaEt5OUlSVlpvVFdaclZrRXJOM28wY1daNU1VODFibTFKUWxwek1rMVlVMmx4WjNkVFpXdHNkMk5DVlhZM1V6QXhRV0pqU1ZaSWRIQlJRMEo0VUVsV05rRXZWekZ0U0ZKYU9FWTFUVWQ1YUZkR1ZUWlhhMVI1ZDNReGVsQnhVV2hNTDJsM1IzQkJRblI2Y2s1VWQyTlRXSFozYVVOQ1FrTjBUMFU0U0ZkWFlUWllXVVJKVVdVM2Vrb3JjQ3Q0YkdWTVMwRTlQVHd2WlRwRGFYQm9aWEpXWVd4MVpUNDhMMlU2UTJsd2FHVnlSR0YwWVQ0OEwyVTZSVzVqY25sd2RHVmtTMlY1UGp3dlMyVjVTVzVtYno0OEwzTmhiV3c2VTNWaWFtVmpkRU52Ym1acGNtMWhkR2x2Ymo0OEwzTmhiV3c2VTNWaWFtVmpkRDQ4YzJGdGJEcEJkSFJ5YVdKMWRHVWdRWFIwY21saWRYUmxUbUZ0WlQwaVUwRkxJaUJCZEhSeWFXSjFkR1ZPWVcxbGMzQmhZMlU5SW1oMGRIQTZMeTl6WTJobGJXRnpMbWx3WTI5dGJXVnlZMlV1WTI5dEwwbGtaVzUwYVhSNUlqNDhjMkZ0YkRwQmRIUnlhV0oxZEdWV1lXeDFaVDVHUmpOQ1FqWkVRelU0TXpBd01EQXhQQzl6WVcxc09rRjBkSEpwWW5WMFpWWmhiSFZsUGp3dmMyRnRiRHBCZEhSeWFXSjFkR1UrUEhOaGJXdzZRWFIwY21saWRYUmxJRUYwZEhKcFluVjBaVTVoYldVOUltNWhiV1VpSUVGMGRISnBZblYwWlU1aGJXVnpjR0ZqWlQwaWFIUjBjRG92TDNOamFHVnRZWE11ZUcxc2MyOWhjQzV2Y21jdmQzTXZNakF3TlM4d05TOXBaR1Z1ZEdsMGVTOWpiR0ZwYlhNaVBqeHpZVzFzT2tGMGRISnBZblYwWlZaaGJIVmxQa1pHTTBKQ05rUkROVGd6TURBd01ERThMM05oYld3NlFYUjBjbWxpZFhSbFZtRnNkV1UrUEM5ellXMXNPa0YwZEhKcFluVjBaVDQ4YzJGdGJEcEJkSFJ5YVdKMWRHVWdRWFIwY21saWRYUmxUbUZ0WlQwaVFYVjBhR1Z1ZEdsallYUnBiMjVTYjI5MElpQkJkSFJ5YVdKMWRHVk9ZVzFsYzNCaFkyVTlJbWgwZEhBNkx5OXpZMmhsYldGekxtbHdZMjl0YldWeVkyVXVZMjl0TDBsa1pXNTBhWFI1SWo0OGMyRnRiRHBCZEhSeWFXSjFkR1ZXWVd4MVpUNWlNVFZsTVRBNE1TMDBaR1kyTFRRd01UWXRPRE0zTWkwMk56aGtZemRtWkRRek5UYzhMM05oYld3NlFYUjBjbWxpZFhSbFZtRnNkV1UrUEM5ellXMXNPa0YwZEhKcFluVjBaVDQ4YzJGdGJEcEJkSFJ5YVdKMWRHVWdRWFIwY21saWRYUmxUbUZ0WlQwaVFYVjBhR1Z1ZEdsallYUnBiMjVTYjI5MFRXVjBhRzlrSWlCQmRIUnlhV0oxZEdWT1lXMWxjM0JoWTJVOUltaDBkSEE2THk5elkyaGxiV0Z6TG1sd1kyOXRiV1Z5WTJVdVkyOXRMMGxrWlc1MGFYUjVJajQ4YzJGdGJEcEJkSFJ5YVdKMWRHVldZV3gxWlQ1VFFVMU1NVEE4TDNOaGJXdzZRWFIwY21saWRYUmxWbUZzZFdVK1BDOXpZVzFzT2tGMGRISnBZblYwWlQ0OEwzTmhiV3c2UVhSMGNtbGlkWFJsVTNSaGRHVnRaVzUwUGp4VGFXZHVZWFIxY21VZ2VHMXNibk05SW1oMGRIQTZMeTkzZDNjdWR6TXViM0puTHpJd01EQXZNRGt2ZUcxc1pITnBaeU1pUGp4VGFXZHVaV1JKYm1adlBqeERZVzV2Ym1sallXeHBlbUYwYVc5dVRXVjBhRzlrSUVGc1oyOXlhWFJvYlQwaWFIUjBjRG92TDNkM2R5NTNNeTV2Y21jdk1qQXdNUzh4TUM5NGJXd3RaWGhqTFdNeE5HNGpJajQ4TDBOaGJtOXVhV05oYkdsNllYUnBiMjVOWlhSb2IyUStQRk5wWjI1aGRIVnlaVTFsZEdodlpDQkJiR2R2Y21sMGFHMDlJbWgwZEhBNkx5OTNkM2N1ZHpNdWIzSm5Mekl3TURBdk1Ea3ZlRzFzWkhOcFp5TnljMkV0YzJoaE1TSStQQzlUYVdkdVlYUjFjbVZOWlhSb2IyUStQRkpsWm1WeVpXNWpaU0JWVWtrOUlpTmZNekJoWVRnM1kyWXRNVE0zTnkwME1XVmhMV0ZrWldNdE5Ea3pNbVppTUdFNVpHWTBJajQ4VkhKaGJuTm1iM0p0Y3o0OFZISmhibk5tYjNKdElFRnNaMjl5YVhSb2JUMGlhSFIwY0RvdkwzZDNkeTUzTXk1dmNtY3ZNakF3TUM4d09TOTRiV3hrYzJsbkkyVnVkbVZzYjNCbFpDMXphV2R1WVhSMWNtVWlQand2VkhKaGJuTm1iM0p0UGp4VWNtRnVjMlp2Y20wZ1FXeG5iM0pwZEdodFBTSm9kSFJ3T2k4dmQzZDNMbmN6TG05eVp5OHlNREF4THpFd0wzaHRiQzFsZUdNdFl6RTBiaU1pUGp3dlZISmhibk5tYjNKdFBqd3ZWSEpoYm5ObWIzSnRjejQ4UkdsblpYTjBUV1YwYUc5a0lFRnNaMjl5YVhSb2JUMGlhSFIwY0RvdkwzZDNkeTUzTXk1dmNtY3ZNakF3TUM4d09TOTRiV3hrYzJsbkkzTm9ZVEVpUGp3dlJHbG5aWE4wVFdWMGFHOWtQanhFYVdkbGMzUldZV3gxWlQ0MVIyeDZPV05NWTJ0SldYY3liRkp1Y1hGdFVUQnFSbmxrVGpBOVBDOUVhV2RsYzNSV1lXeDFaVDQ4TDFKbFptVnlaVzVqWlQ0OEwxTnBaMjVsWkVsdVptOCtQRk5wWjI1aGRIVnlaVlpoYkhWbFBtZ3JZa0p4ZUVreWFXUndaazV1U3psS1dURkdkSEI0YkRkUFUwZEJOR0ZXUVV0bE1IUXdkelk1TlhwcVNuSlNWRko1TUVoUGFqaHdOWGgxUlhoRmRtVk1TM1JRT0dveFF6aHdNbUpuTDFkUmNXVm1ZekZyWVdWRU5UWkxhMHBRVnpOSU9GRjZaRXRXT1M5ak5XTm1aREZsUzNCb1QyMDNUREpuUlZjck5razVka1oyTW5Sb2QwUjJZbGxGVGtoTWNUbHBRblptY0hab01GSjRhRVZwWWpKUVpXaEdRVVJXVFVGbFl5OWlaRVJvYzBaQ1drOVJibFU0TVVSSlVtTkpNaXREY1VSTFJrOVdOak5LVldOelozaFhRa1pNZWt4V1pFdHpNSEZPTkhKVmRsWnBja1ZEV1hOSWJtb3lUbmt3WkVsMVJGaFNOM0IzWnl0RVVDOXFWRGg2TVdobFVXODFabVZtTlZOV1ZtdDNWSFZISzBaamRXNXhTREowTmxwS2JqUk5aRmxSYzNNelZFOUNTM00xWlRRMVVYaHRlVWxpTld4YVIxSTRhbWhDVkdkdlQwUmtNM2MwVVc1cWVrSlZTVUphY3psdVFUMDlQQzlUYVdkdVlYUjFjbVZXWVd4MVpUNDhTMlY1U1c1bWJ6NDhienBUWldOMWNtbDBlVlJ2YTJWdVVtVm1aWEpsYm1ObElIaHRiRzV6T204OUltaDBkSEE2THk5a2IyTnpMbTloYzJsekxXOXdaVzR1YjNKbkwzZHpjeTh5TURBMEx6QXhMMjloYzJsekxUSXdNRFF3TVMxM2MzTXRkM056WldOMWNtbDBlUzF6WldObGVIUXRNUzR3TG5oelpDSStQRzg2UzJWNVNXUmxiblJwWm1sbGNpQldZV3gxWlZSNWNHVTlJbWgwZEhBNkx5OWtiMk56TG05aGMybHpMVzl3Wlc0dWIzSm5MM2R6Y3k5dllYTnBjeTEzYzNNdGMyOWhjQzF0WlhOellXZGxMWE5sWTNWeWFYUjVMVEV1TVNOVWFIVnRZbkJ5YVc1MFUwaEJNU0krTldkTE1FRktUM2h2Tm1SS1ZUVlFaV3hPYW01cVNGcEVUVUpCUFR3dmJ6cExaWGxKWkdWdWRHbG1hV1Z5UGp3dmJ6cFRaV04xY21sMGVWUnZhMlZ1VW1WbVpYSmxibU5sUGp3dlMyVjVTVzVtYno0OEwxTnBaMjVoZEhWeVpUNDhMM05oYld3NlFYTnpaWEowYVc5dVBnPT06"
  end

  def successful_verify_response
    MockResponse.succeeded("<BankcardTransactionResponsePro xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard/Pro\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><Status xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Successful</Status><StatusCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>000</StatusCode><StatusMessage xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>AP</StatusMessage><TransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>DA9471530C1F4B4083BA25F73CB3F9A3</TransactionId><OriginatorTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>41494</OriginatorTransactionId><ServiceTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>015253100009715</ServiceTransactionId><ServiceTransactionDateTime xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'><Date>2014-04-03</Date><Time>13:50:16.000</Time><TimeZone>-06:00</TimeZone></ServiceTransactionDateTime><Addendum i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><CaptureState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>CannotCapture</CaptureState><TransactionState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Verified</TransactionState><IsAcknowledged xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>false</IsAcknowledged><Reference xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><Amount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</Amount><CardType xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Visa</CardType><FeeAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FeeAmount><ApprovalCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><AVSResult xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'><ActualResult>Y</ActualResult><AddressResult>Match</AddressResult><CountryResult>NotSet</CountryResult><StateResult>NotSet</StateResult><PostalCodeResult>Match</PostalCodeResult><PhoneResult>NotSet</PhoneResult><CardholderNameResult>NotSet</CardholderNameResult><CityResult>NotSet</CityResult></AVSResult><BatchId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><CVResult xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Match</CVResult><CardLevel xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><DowngradeCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><MaskedPAN xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>401200XXXXXX0026</MaskedPAN><PaymentAccountDataToken xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>da947153-0c1f-4b40-83ba-25f73cb3f9a3522769a4-d0d7-4e22-9149-1fa72feafc5c</PaymentAccountDataToken><RetrievalReferenceNumber xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><Resubmit xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Unspecified</Resubmit><SettlementDate xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0001-01-01T00:00:00</SettlementDate><FinalBalance xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FinalBalance><OrderId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>35926</OrderId><CashBackAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0.00</CashBackAmount><PrepaidCard xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</PrepaidCard><AdviceResponse>NotSet</AdviceResponse><CommercialCardResponse>NotSet</CommercialCardResponse><ReturnedACI>E</ReturnedACI></BankcardTransactionResponsePro>", "application/xml")
  end

  def successful_authorize_response
    MockResponse.succeeded("<BankcardTransactionResponsePro xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard/Pro\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><Status xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Successful</Status><StatusCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>000</StatusCode><StatusMessage xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>AP</StatusMessage><TransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>70608984FEC4473188A844C2D6DAB96E</TransactionId><OriginatorTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>41611</OriginatorTransactionId><ServiceTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>015254170001226</ServiceTransactionId><ServiceTransactionDateTime xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'><Date>2013-04-03</Date><Time>13:50:16.000</Time><TimeZone>-06:00</TimeZone></ServiceTransactionDateTime><Addendum i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><CaptureState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>ReadyForCapture</CaptureState><TransactionState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Authorized</TransactionState><IsAcknowledged xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>false</IsAcknowledged><Reference xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>xyt</Reference><Amount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>10.00</Amount><CardType xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Visa</CardType><FeeAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FeeAmount><ApprovalCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>VI1000</ApprovalCode><AVSResult i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><BatchId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><CVResult xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</CVResult><CardLevel xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><DowngradeCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>00</DowngradeCode><MaskedPAN xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>401288XXXXXX8882</MaskedPAN><PaymentAccountDataToken xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>70608984-fec4-4731-88a8-44c2d6dab96e13d40fe9-2081-4470-abf2-deab020920b9</PaymentAccountDataToken><RetrievalReferenceNumber xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><Resubmit xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Unspecified</Resubmit><SettlementDate xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0001-01-01T00:00:00</SettlementDate><FinalBalance xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FinalBalance><OrderId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>36011</OrderId><CashBackAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0.00</CashBackAmount><PrepaidCard xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</PrepaidCard><AdviceResponse>NotSet</AdviceResponse><CommercialCardResponse>NotSet</CommercialCardResponse><ReturnedACI>N</ReturnedACI></BankcardTransactionResponsePro>", "application/xml")
  end

  def failed_authorize_response_with_pan
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>0</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string i:nil=\'true\'/></Messages><Operation>Authorize</Operation><Reason>Validation Errors Occurred</Reason><ValidationErrors><ValidationError><RuleKey>TenderData.CardData.PAN</RuleKey><RuleLocationKey>ppreq:CREDIT/ppreq:AUTHONLY/TenderData/CardData/PAN</RuleLocationKey><RuleMessage>Property \'PAN\' is required.</RuleMessage><TransactionId>BD4E88F1913048909CE93A2A7E4A93F3</TransactionId></ValidationError></ValidationErrors></ErrorResponse>","application/xml")
  end

  def successful_purchase_response
    MockResponse.succeeded("<BankcardTransactionResponsePro xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard/Pro\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><Status xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Successful</Status><StatusCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>000</StatusCode><StatusMessage xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>AP</StatusMessage><TransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>CCED01ACF1F44E5A8DAE8E956EFD1DE5</TransactionId><OriginatorTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>41617</OriginatorTransactionId><ServiceTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>015254170005055</ServiceTransactionId><ServiceTransactionDateTime xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'><Date>2013-04-03</Date><Time>13:50:16.000</Time><TimeZone>-06:00</TimeZone></ServiceTransactionDateTime><Addendum i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><CaptureState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Captured</CaptureState><TransactionState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Captured</TransactionState><IsAcknowledged xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>false</IsAcknowledged><Reference xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>xyt</Reference><Amount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>10.00</Amount><CardType xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Visa</CardType><FeeAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FeeAmount><ApprovalCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>VI1000</ApprovalCode><AVSResult i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><BatchId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0801</BatchId><CVResult xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</CVResult><CardLevel xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><DowngradeCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>00</DowngradeCode><MaskedPAN xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>401288XXXXXX8882</MaskedPAN><PaymentAccountDataToken xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>cced01ac-f1f4-4e5a-8dae-8e956efd1de559486bc5-88e7-4f08-a9b1-a80d2f728014</PaymentAccountDataToken><RetrievalReferenceNumber xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><Resubmit xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Unspecified</Resubmit><SettlementDate xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0001-01-01T00:00:00</SettlementDate><FinalBalance xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FinalBalance><OrderId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>36017</OrderId><CashBackAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0.00</CashBackAmount><PrepaidCard xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</PrepaidCard><AdviceResponse>NotSet</AdviceResponse><CommercialCardResponse>NotSet</CommercialCardResponse><ReturnedACI>N</ReturnedACI></BankcardTransactionResponsePro>", "application/xml")
  end

  def failed_purchase_response_with_pan
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>0</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string i:nil=\'true\'/></Messages><Operation>AuthorizeAndCapture</Operation><Reason>Validation Errors Occurred</Reason><ValidationErrors><ValidationError><RuleKey>TenderData.CardData.PAN</RuleKey><RuleLocationKey>ppreq:CREDIT/ppreq:AUTH/TenderData/CardData/PAN</RuleLocationKey><RuleMessage>Property \'PAN\' is required.</RuleMessage><TransactionId>EBC8B4BC01DE4FD9BDB8DD3A6C69ECCD</TransactionId></ValidationError></ValidationErrors></ErrorResponse>", "application/xml")
  end

  def successful_capture_response
    MockResponse.succeeded("<BankcardCaptureResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><Status xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Successful</Status><StatusCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>000</StatusCode><StatusMessage xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>AP</StatusMessage><TransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>C4B814FDFCB44176B5404655DA8DA0E6</TransactionId><OriginatorTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>41625</OriginatorTransactionId><ServiceTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>015254170005961</ServiceTransactionId><ServiceTransactionDateTime xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'><Date>2013-04-03</Date><Time>13:50:16.000</Time><TimeZone>-06:00</TimeZone></ServiceTransactionDateTime><Addendum i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><CaptureState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Captured</CaptureState><TransactionState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Captured</TransactionState><IsAcknowledged xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>false</IsAcknowledged><Reference i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><BatchId>0801</BatchId><IndustryType>NotSet</IndustryType><TransactionSummaryData><CashBackTotals i:nil=\'true\'/><NetTotals><NetAmount>10.00</NetAmount><Count>1</Count></NetTotals><ReturnTotals i:nil=\'true\'/><SaleTotals><NetAmount>10.00</NetAmount><Count>1</Count></SaleTotals><VoidTotals i:nil=\'true\'/><PINDebitReturnTotals i:nil=\'true\'/><PINDebitSaleTotals i:nil=\'true\'/></TransactionSummaryData><PrepaidCard>NotSet</PrepaidCard></BankcardCaptureResponse>", "application/xml")
  end

  def failed_capture_response
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>326</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string>Transaction no longer active due to Capture</a:string></Messages><Operation>Capture</Operation><Reason>Transaction no longer active due to Capture</Reason><ValidationErrors/></ErrorResponse>", "application/xml")
  end

  def successful_refund_response
    MockResponse.succeeded("<BankcardTransactionResponsePro xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard/Pro\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><Status xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Successful</Status><StatusCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>000</StatusCode><StatusMessage xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>AP</StatusMessage><TransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>E78EC05C343D4377B2422691B07783A3</TransactionId><OriginatorTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>41639</OriginatorTransactionId><ServiceTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><ServiceTransactionDateTime xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'><Date>2015-09-11</Date><Time>07:56:53</Time><TimeZone i:nil=\'true\'/></ServiceTransactionDateTime><Addendum i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><CaptureState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Captured</CaptureState><TransactionState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Returned</TransactionState><IsAcknowledged xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>false</IsAcknowledged><Reference xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>xyt</Reference><Amount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>10.00</Amount><CardType xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Visa</CardType><FeeAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FeeAmount><ApprovalCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>C73494</ApprovalCode><AVSResult i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><BatchId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0801</BatchId><CVResult xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</CVResult><CardLevel xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><DowngradeCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><MaskedPAN xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>401288XXXXXX8882</MaskedPAN><PaymentAccountDataToken xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>5dd122cd-c033-4d26-9af0-dd7a29a564c20e79cd0f-baaa-48ed-8ab0-9249bb26f343</PaymentAccountDataToken><RetrievalReferenceNumber xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><Resubmit xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Unspecified</Resubmit><SettlementDate xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0001-01-01T00:00:00</SettlementDate><FinalBalance xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FinalBalance><OrderId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>36033</OrderId><CashBackAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0.00</CashBackAmount><PrepaidCard xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</PrepaidCard><AdviceResponse>NotSet</AdviceResponse><CommercialCardResponse>NotSet</CommercialCardResponse><ReturnedACI>NotSet</ReturnedACI></BankcardTransactionResponsePro>", "application/xml")
  end

  def failed_refund_response
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>326</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string>Attempt to return more than original authorization.</a:string></Messages><Operation>ReturnById</Operation><Reason>Attempt to return more than original authorization.</Reason><ValidationErrors/></ErrorResponse>", "application/xml")
  end

  def failed_refund_due_to_void_response
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>326</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string>Transaction no longer active due to Undo</a:string></Messages><Operation>ReturnById</Operation><Reason>Transaction no longer active due to Undo</Reason><ValidationErrors/></ErrorResponse>", "application/xml")
  end

  def failed_refund_due_to_autorize_no_capture_response
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>326</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string>Transaction cannot be Returned as it has not been Captured.  Use Undo instead.</a:string></Messages><Operation>ReturnById</Operation><Reason>Transaction cannot be Returned as it has not been Captured.  Use Undo instead.</Reason><ValidationErrors/></ErrorResponse>", "application/xml")
  end

  def failed_refund_due_to_using_same_auth_id_after_capture
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>326</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string>Transaction cannot be Returned as it has been Captured.  Return the Captured transaction instead.</a:string></Messages><Operation>ReturnById</Operation><Reason>Transaction cannot be Returned as it has been Captured.  Return the Captured transaction instead.</Reason><ValidationErrors/></ErrorResponse>", "application/xml")
  end

  def successful_void_response
    MockResponse.succeeded("<BankcardTransactionResponsePro xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard/Pro\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><Status xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Successful</Status><StatusCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>006</StatusCode><StatusMessage xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>REVERSED</StatusMessage><TransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>7E9AD36BC5A2445AAAA2034B2609C7F0</TransactionId><OriginatorTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>41641</OriginatorTransactionId><ServiceTransactionId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><ServiceTransactionDateTime xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'><Date>2013-04-03</Date><Time>13:50:16.000</Time><TimeZone>-06:00</TimeZone></ServiceTransactionDateTime><Addendum i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'/><CaptureState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>CannotCapture</CaptureState><TransactionState xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>Undone</TransactionState><IsAcknowledged xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>false</IsAcknowledged><Reference xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions\'>xyt</Reference><Amount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>10.00</Amount><CardType xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Visa</CardType><FeeAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FeeAmount><ApprovalCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><AVSResult i:nil=\'true\' xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><BatchId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><CVResult xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</CVResult><CardLevel xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><DowngradeCode xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>00</DowngradeCode><MaskedPAN xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>401288XXXXXX8882</MaskedPAN><PaymentAccountDataToken xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>d319259d-8b5e-4702-9d18-060240d1fed964fe60e2-2529-4ca3-88db-adcc55f811f5</PaymentAccountDataToken><RetrievalReferenceNumber xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'/><Resubmit xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>Unspecified</Resubmit><SettlementDate xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0001-01-01T00:00:00</SettlementDate><FinalBalance xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0</FinalBalance><OrderId xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>36036</OrderId><CashBackAmount xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>0.00</CashBackAmount><PrepaidCard xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard\'>NotSet</PrepaidCard><AdviceResponse>NotSet</AdviceResponse><CommercialCardResponse>NotSet</CommercialCardResponse><ReturnedACI>N</ReturnedACI></BankcardTransactionResponsePro>", "application/xml")
  end

  def failed_void_response
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>326</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string>Transaction no longer active due to Capture.  Use Return instead.</a:string></Messages><Operation>Undo</Operation><Reason>Transaction no longer active due to Capture.  Use Return instead.</Reason><ValidationErrors/></ErrorResponse>", "application/xml")
  end

  def failed_void_already_undone_response
    MockResponse.failed("<ErrorResponse xmlns=\'http://schemas.ipcommerce.com/CWS/v2.0/Rest\' xmlns:i=\'http://www.w3.org/2001/XMLSchema-instance\'><ErrorId>326</ErrorId><HelpUrl>http://docs.nabvelocity.com/hc/en-us/articles/203497757-REST-Information</HelpUrl><Messages xmlns:a=\'http://schemas.microsoft.com/2003/10/Serialization/Arrays\'><a:string>Transaction has already been Undone.</a:string></Messages><Operation>Undo</Operation><Reason>Transaction has already been Undone.</Reason><ValidationErrors/></ErrorResponse>", "application/xml")
  end
  
  class MockResponse
    attr_reader :code, :body, :content_type
    def self.succeeded(xml, content_type)
      MockResponse.new(("200" || "201"), xml, content_type)
    end

    def self.failed(xml, content_type)
      MockResponse.new(("400" || "500" || "5000"), xml, content_type)
    end

    def initialize(code, body, content_type)
      @code, @body, @content_type = code, body, content_type
    end
  end

end
