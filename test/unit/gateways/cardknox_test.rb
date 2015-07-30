require 'test_helper'

class CardknoxTest < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = CardknoxGateway.new(:api_key => 'Key')
    @credit_card = credit_card('4242424242424242')
    @options = {
      :billing_address  => address,
      :shipping_address => address
    }
    @amount = 100
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '15302179', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid CVV', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid CVV', response.message 
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert capture = @gateway.capture(@amount, 15312316)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert capture = @gateway.capture(@amount-1, 15312316)
    assert_failure capture
    assert_equal 'Original transaction not specified', capture.message 
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'UNSUPPORTED CARD TYPE', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void(15308171)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
    assert_equal 'Original transaction not specified', response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).twice.returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Success}, response.message;
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response).then.returns(failed_void_response)
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Success}, response.message;
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_match %r{Invalid CVV}, response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
   "xAmount=0.41&xInvoice=&xDescription=Store+Purchase&xCardNum=4000100011112224&xCVV=123&xExp=0916&xName=Longbob+Longsen&xBillFirstName=Longbob&xBillLastName=Longsen&xBillCompany=Widgets+Inc&xBillStreet=456+My+Street&xBillStreet2=Apt+1&xBillCity=Ottawa&xBillState=ON&xBillZip=K1C2N6&xBillCountry=CA&xBillPhone=%28555%29555-5555&xStreet=456+My+Street&xZip=K1C2N6&xKey=notvalid=4.5.4&xSoftwareName=Active+Merchant&xSoftwareVersion=1.5.1&xCommand=cc%3Asale"
  end

  def post_scrubbed
    "xAmount=0.41&xInvoice=&xDescription=Store+Purchase&xCardNum=[FILTERED]&xCVV=[FILTERED]&xExp=0916&xName=Longbob+Longsen&xBillFirstName=Longbob&xBillLastName=Longsen&xBillCompany=Widgets+Inc&xBillStreet=456+My+Street&xBillStreet2=Apt+1&xBillCity=Ottawa&xBillState=ON&xBillZip=K1C2N6&xBillCountry=CA&xBillPhone=%28555%29555-5555&xStreet=456+My+Street&xZip=K1C2N6&xKey=[FILTERED]&xVersion=4.5.4&xSoftwareName=Active+Merchant&xSoftwareVersion=1.5.1&xCommand=cc%3Asale"
  end
  

  def successful_purchase_response
    "xResult=A&xStatus=Approved&xError=&xRefNum=15302179&xAuthCode=404160&xBatch=321&xAvsResultCode=NNN&xAvsResult=Address%3a+No+Match+%26+5+Digit+Zip%3a+No+Match&xCvvResultCode=N&xCvvResult=No+Match&xAuthAmount=2.10&xToken=95651941c1144d32baa9fb6d423edfed&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"  
    
  end

  def failed_purchase_response
    "xResult=D&xStatus=Declined&xError=Invalid+CVV&xRefNum=15307128&xAuthCode=&xBatch=&xAvsResultCode=NNN&xAvsResult=Address%3a+No+Match+%26+5+Digit+Zip%3a+No+Match&xCvvResultCode=N&xCvvResult=No+Match&xToken=8138747e41894071a353318541d2ee8c"
  end

  def successful_authorize_response
    "xResult=A&xStatus=Approved&xError=&xRefNum=15312316&xAuthCode=630421&xBatch=&xAvsResultCode=NNN&xAvsResult=Address%3a+No+Match+%26+5+Digit+Zip%3a+No+Match&xCvvResultCode=N&xCvvResult=No+Match&xAuthAmount=2.06&xToken=62d4fd9aebd240659d68ffaa156d1788&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"
  end

  def failed_authorize_response
    "xResult=D&xStatus=Declined&xError=Invalid+CVV&xRefNum=15307290&xAuthCode=&xBatch=&xAvsResultCode=NNN&xAvsResult=Address%3a+No+Match+%26+5+Digit+Zip%3a+No+Match&xCvvResultCode=N&xCvvResult=No+Match&xToken=065751a8a28e468a8d79cb98c04cf350"
  end

  def successful_capture_response
    "xResult=A&xStatus=Approved&xError=&xRefNum=15312316&xRefNumCurrent=15312319&xAuthCode=&xBatch=321&xAvsResultCode=&xAvsResult=Unmapped+AVS+response&xCvvResultCode=&xCvvResult=No+CVV+data+available&xAuthAmount=2.06&xToken=f9097326fb1c4976a6da75ccb872f28a&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"
  end

  def failed_capture_response
    "xResult=E&xStatus=Error&xAuthCode=000000&xError=Original+transaction+not+specified&xRefNum=15307619&xErrorCode=00000"
  end

  def successful_refund_response

  end

  def failed_refund_response
    "xResult=D&xStatus=Declined&xError=UNSUPPORTED+CARD+TYPE&xRefNum=15308026&xAuthCode=&xBatch=&xAvsResultCode=&xAvsResult=Unmapped+AVS+response&xCvvResultCode=&xCvvResult=No+CVV+data+available"
  end

  def successful_void_response
    "xResult=A&xStatus=Approved&xError=&xRefNum=15308171&xRefNumCurrent=15308172&xAuthCode=912013&xBatch=&xAvsResultCode=&xAvsResult=Unmapped+AVS+response&xCvvResultCode=&xCvvResult=No+CVV+data+available&xAuthAmount=2.33&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"
  end

  def failed_void_response
    "xResult=E&xStatus=Error&xAuthCode=000000&xError=Original+transaction+not+specified&xRefNum=15308297&xErrorCode=00000"
  end

  def successful_verify_response
   "xResult=A&xStatus=Approved&xError=&xRefNum=15314566&xAuthCode=608755&xBatch=&xAvsResultCode=NNN&xAvsResult=Address%3a+No+Match+%26+5+Digit+Zip%3a+No+Match&xCvvResultCode=N&xCvvResult=No+Match&xAuthAmount=1.00&xToken=09dc51aceb98440fbf0847cad2941d45&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"
  # "xResult=A&xStatus=Approved&xError=&xRefNum=15314566&xRefNumCurrent=15314567&xAuthCode=208038&xBatch=&xAvsResultCode=&xAvsResult=Unmapped+AVS+response&xCvvResultCode=&xCvvResult=No+CVV+data+available&xAuthAmount=1.00&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"
  end

  def failed_verify_response
    "xResult=D&xStatus=Declined&xError=Invalid+CVV&xRefNum=15310681&xAuthCode=&xBatch=&xAvsResultCode=NNN&xAvsResult=Address%3a+No+Match+%26+5+Digit+Zip%3a+No+Match&xCvvResultCode=N&xCvvResult=No+Match&xToken=748df69e22f142d4aab296328d4f2653"
  end
end