require 'test_helper'

class CardknoxTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CardknoxGateway.new(api_key: 'api_key')
    @credit_card = credit_card('4242424242424242')
    @options = {
      billing_address: address,
      shipping_address: address
    }
    @amount = 100
  end

  def test_successful_purchase_passing_extra_info
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(order_id: "1337", description: "socool"))
    end.check_request do |endpoint, data, headers|
      assert_match(/xOrderID=1337/, data)
      assert_match(/xDescription=socool/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'YYY', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_add_track_data_with_creditcard
    @credit_card.track_data = "data"

    @gateway.expects(:ssl_post).with do |_, body|
      body.include?("xMagstripe=data")
    end.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_add_track_data_with_empty_data
    ["", nil].each do |data|
      @credit_card.track_data = data

      @gateway.expects(:ssl_post).with do |_, body|
        refute body.include? "xMagstripe="
        body
      end.returns(successful_purchase_response)

      assert response = @gateway.purchase(@amount, @credit_card, @options)
      assert_success response
    end
  end

  def test_manual_entry_is_properly_indicated_on_purchase
    @credit_card.manual_entry = true
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|

      assert_match %r{xCardNum=4242424242424242}, data
      assert_match %r{xCardPresent=true}, data

    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_ip_is_being_sent # failed
    @gateway.expects(:ssl_post).with do |url, data|
      data =~ /xIP=123.123.123.123/
    end.returns(successful_purchase_response)

    @options[:ip] = "123.123.123.123"
    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_credit_card_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '16268727;f0b84a5b181749b4b0d77f6291a753ab;credit_card', response.authorization
  end

  def test_failed_credit_card_purchase
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
    assert_equal '15312316;62d4fd9aebd240659d68ffaa156d1788;credit_card', auth.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid CVV', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response).then.returns(successful_capture_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
    assert_equal '15312316;f9097326fb1c4976a6da75ccb872f28a;credit_card', capture.authorization
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert capture = @gateway.capture(@amount-1, '')
    assert_failure capture
    assert_equal 'Original transaction not specified', capture.message
  end

  def test_successful_check_refund_void
    @gateway.expects(:ssl_post).returns(successful_check_refund_void)
    assert void = @gateway.void('16274604;;check', @options)
    assert_success void
    assert_equal 'Success', void.message
    assert_equal '16276884;;check', void.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_credit_card_refund_response)

    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'UNSUPPORTED CARD TYPE', response.message
    assert_equal '15308026;;credit_card', response.authorization
  end

  def test_successful_credit_card_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void('15308171;;credit_card')
    assert_success void
    assert_equal 'Success', void.message
    assert_equal '15308171;;credit_card', void.authorization
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

  def purchase_request
   "xKey=api_key&xVersion=4.5.4&xSoftwareName=Active+Merchant&xSoftwareVersion=1.52.0&xCommand=cc%3Asale&xAmount=1.00&xCardNum=4242424242424242&xCVV=123&xExp=0916&xName=Longbob+Longsen&xBillFirstName=Longbob&xBillLastName=Longsen&xBillCompany=Widgets+Inc&xBillStreet=456+My+Street&xBillStreet2=Apt+1&xBillCity=Ottawa&xBillState=ON&xBillZip=K1C2N6&xBillCountry=CA&xBillPhone=%28555%29555-5555&xShipFirstName=Longbob&xShipLastName=Longsen&xShipCompany=Widgets+Inc&xShipStreet=456+My+Street&xShipStreet2=Apt+1&xShipCity=Ottawa&xShipState=ON&xShipZip=K1C2N6&xShipCountry=CA&xShipPhone=%28555%29555-5555&xStreet=456+My+Street&xZip=K1C2N6"
  end

  def successful_purchase_response # passed avs and cvv
    "xResult=A&xStatus=Approved&xError=&xRefNum=16268727&xAuthCode=230809&xBatch=347&xAvsResultCode=YYY&xAvsResult=Address%3a+Match+%26+5+Digit+Zip%3a+Match&xCvvResultCode=M&xCvvResult=Match&xAuthAmount=4.38&xToken=f0b84a5b181749b4b0d77f6291a753ab&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"
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

  def successful_credit_card_refund_response
  end

  def failed_credit_card_refund_response
    "xResult=D&xStatus=Declined&xError=UNSUPPORTED+CARD+TYPE&xRefNum=15308026&xAuthCode=&xBatch=&xAvsResultCode=&xAvsResult=Unmapped+AVS+response&xCvvResultCode=&xCvvResult=No+CVV+data+available"
  end

  def successful_check_refund_response
    "xResult=A&xStatus=Approved&xError=&xRefNum=16274604"
  end

  def failed_check_refund_response
    "xResult=D&xStatus=Declined&xError=&xRefNum=16274604"
  end

  def successful_void_response
    "xResult=A&xStatus=Approved&xError=&xRefNum=15308171&xRefNumCurrent=15308172&xAuthCode=912013&xBatch=&xAvsResultCode=&xAvsResult=Unmapped+AVS+response&xCvvResultCode=&xCvvResult=No+CVV+data+available&xAuthAmount=2.33&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"
  end

  def failed_void_response
    "xResult=E&xStatus=Error&xAuthCode=000000&xError=Original+transaction+not+specified&xRefNum=15308297&xErrorCode=00000"
  end

  def successful_check_refund_void
    'xResult=A&xStatus=Approved&xError=&xRefNum=16276884'
  end

  def successful_verify_response
   "xResult=A&xStatus=Approved&xError=&xRefNum=15314566&xAuthCode=608755&xBatch=&xAvsResultCode=NNN&xAvsResult=Address%3a+No+Match+%26+5+Digit+Zip%3a+No+Match&xCvvResultCode=N&xCvvResult=No+Match&xAuthAmount=1.00&xToken=09dc51aceb98440fbf0847cad2941d45&xMaskedCardNumber=4xxxxxxxxxxx2224&xName=Longbob+Longsen"
  end

  def failed_verify_response
    "xResult=D&xStatus=Declined&xError=Invalid+CVV&xRefNum=15310681&xAuthCode=&xBatch=&xAvsResultCode=NNN&xAvsResult=Address%3a+No+Match+%26+5+Digit+Zip%3a+No+Match&xCvvResultCode=N&xCvvResult=No+Match&xToken=748df69e22f142d4aab296328d4f2653"
  end

  def pre_scrubbed
   "xKey=api_key&xVersion=4.5.4&xSoftwareName=Active+Merchant&xSoftwareVersion=1.52.0&xCommand=cc%3Asale&xAmount=1.00&xCardNum=4242424242424242&xCVV=123&xExp=0916&xName=Longbob+Longsen&xBillFirstName=Longbob&xBillLastName=Longsen&xBillCompany=Widgets+Inc&xBillStreet=456+My+Street&xBillStreet2=Apt+1&xBillCity=Ottawa&xBillState=ON&xBillZip=K1C2N6&xBillCountry=CA&xBillPhone=%28555%29555-5555&xShipFirstName=Longbob&xShipLastName=Longsen&xShipCompany=Widgets+Inc&xShipStreet=456+My+Street&xShipStreet2=Apt+1&xShipCity=Ottawa&xShipState=ON&xShipZip=K1C2N6&xShipCountry=CA&xShipPhone=%28555%29555-5555&xStreet=456+My+Street&xZip=K1C2N6"
  end

  def post_scrubbed
   "xKey=[FILTERED]&xVersion=4.5.4&xSoftwareName=Active+Merchant&xSoftwareVersion=1.52.0&xCommand=cc%3Asale&xAmount=1.00&xCardNum=[FILTERED]&xCVV=[FILTERED]&xExp=0916&xName=Longbob+Longsen&xBillFirstName=Longbob&xBillLastName=Longsen&xBillCompany=Widgets+Inc&xBillStreet=456+My+Street&xBillStreet2=Apt+1&xBillCity=Ottawa&xBillState=ON&xBillZip=K1C2N6&xBillCountry=CA&xBillPhone=%28555%29555-5555&xShipFirstName=Longbob&xShipLastName=Longsen&xShipCompany=Widgets+Inc&xShipStreet=456+My+Street&xShipStreet2=Apt+1&xShipCity=Ottawa&xShipState=ON&xShipZip=K1C2N6&xShipCountry=CA&xShipPhone=%28555%29555-5555&xStreet=456+My+Street&xZip=K1C2N6"
  end
end
