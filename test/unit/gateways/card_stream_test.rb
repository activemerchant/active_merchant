require 'test_helper'

class CardStreamTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CardStreamGateway.new(
      :login => 'login',
      :shared_secret => 'secret'
    )

    @visacreditcard = credit_card('4929421234600821',
      :month => '12',
      :year => '2014',
      :verification_value => '356',
      :brand => :visa
    )

    @visacredit_options = {
      :billing_address => {
        :address1 => "Flat 6, Primrose Rise",
        :address2 => "347 Lavender Road",
        :city => "",
        :state => "Northampton",
        :zip => 'NN17 8YG '
      },
      :order_id => generate_unique_id,
      :description => 'AM test purchase'
    }

    @visacredit_descriptor_options = {
      :billing_address => {
        :address1 => "Flat 6, Primrose Rise",
        :address2 => "347 Lavender Road",
        :city => "",
        :state => "Northampton",
        :zip => 'NN17 8YG '
      },
      :merchant_name => 'merchant',
      :dynamic_descriptor => 'product'
    }

    @declined_card = credit_card('4000300011112220',
      :month => '9',
      :year => '2014'
    )
  end

  def test_successful_visacreditcard_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert responseAuthorization = @gateway.authorize(142, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
  end

  def test_successful_avs_and_cvv_results
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(142, @visacreditcard, @visacredit_options)
    assert_success response
    assert response.avs_result
    assert_equal "M", response.avs_result['code']
    assert_equal "Street address and postal code match.", response.avs_result['message']
    assert_equal "Y", response.avs_result['street_match']
    assert_equal "Y", response.avs_result['postal_match']

    assert response.cvv_result
    assert_equal "M", response.cvv_result['code']
  end

  def test_successful_visacreditcard_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert responseCapture = @gateway.capture(142, 'authorization', @visacredit_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_visacreditcard_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert responseRefund = @gateway.refund(142, "authorization", @visacredit_options)
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_successful_visacreditcard_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert responseRefund = @gateway.void("authorization", @visacredit_options)
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_successful_visacreditcard_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert responseRefund = @gateway.purchase(142, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_successful_visacreditcard_purchase_with_descriptors
    stub_comms do
      @gateway.purchase(284, @visacreditcard, @visacredit_descriptor_options)
    end.check_request do |endpoint, data, headers|
      assert_match(/statementNarrative1=merchant/, data)
      assert_match(/statementNarrative2=product/, data)
    end.respond_with(successful_purchase_response_with_descriptors)
  end

  def test_successful_visacreditcard_purchase_via_reference
    @gateway.expects(:ssl_post).returns(successful_reference_purchase_response)

    assert responsePurchase = @gateway.purchase(142, 'authorization', @visacredit_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
  end

  def test_failed_visacreditcard_purchase_via_reference
    @gateway.expects(:ssl_post).returns(failed_reference_purchase_response)

    assert responsePurchase = @gateway.purchase(142, 'authorization', @visacredit_options)
    assert_equal 'DB ERROR', responsePurchase.message
    assert_failure responsePurchase
    assert responsePurchase.test?
  end

  def test_declined_mastercard_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_card_declined_response)

    assert response = @gateway.purchase(10000, @visacreditcard, @visacredit_options)
    assert_equal 'CARD DECLINED', response.message
    assert_failure response
    assert response.test?
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@visacreditcard, @visacredit_options)
    end.respond_with(successful_authorization_response, failed_void_response)
    assert_success response
    assert_equal "APPROVED", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@declined_card, @visacredit_options)
    end.respond_with(failed_authorization_response, successful_void_response)
    assert_failure response
    assert_equal "CARD DECLINED", response.message
  end

  def test_purchase_options

    # Default
    purchase = stub_comms do
      @gateway.purchase(142, @visacreditcard, @visacredit_options)
    end.check_request do |endpoint, data, headers|
      assert_match(/type=1/, data)
    end.respond_with(successful_purchase_response)

    assert_success purchase

    purchase = stub_comms do
      @gateway.purchase(142, @visacreditcard, @visacredit_options.merge(type: 2))
    end.check_request do |endpoint, data, headers|
      assert_match(/type=2/, data)
    end.respond_with(successful_purchase_response)

    assert_success purchase

    purchase = stub_comms do
      @gateway.purchase(142, @visacreditcard, @visacredit_options.merge(currency: "PEN"))
    end.check_request do |endpoint, data, headers|
      assert_match(/currencyCode=604/, data)
    end.respond_with(successful_purchase_response)

    assert_success purchase
  end

  def test_successful_purchase_without_street_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(142, @visacreditcard, billing_address: {state: "Northampton"})
    assert_equal 'APPROVED', response.message
  end

  def test_successful_purchase_without_any_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(142, @visacreditcard)
    assert_equal 'APPROVED', response.message
  end

  def test_hmac_signature_added_to_post
    post_params = "action=SALE&amount=10000&captureDelay=0&cardCVV=356&cardExpiryMonth=12&cardExpiryYear=14&cardNumber=4929421234600821&countryCode=GB&currencyCode=826&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerName=Longbob+Longsen&customerPostCode=NN17+8YG+&merchantID=login&orderRef=AM+test+purchase&threeDSRequired=N&transactionUnique=#{@visacredit_options[:order_id]}&type=1"
    expected_signature = Digest::SHA512.hexdigest("#{post_params}#{@gateway.options[:shared_secret]}")

    @gateway.expects(:ssl_post).with do |url, data|
      data.include?("signature=#{expected_signature}")
    end.returns(successful_authorization_response)

    @gateway.purchase(10000, @visacreditcard, @visacredit_options)
  end

  def test_3ds_response
    purchase = stub_comms do
      @gateway.purchase(142, @visacreditcard, @visacredit_options.merge(threeds_required: true))
    end.check_request do |endpoint, data, headers|
      assert_match(/threeDSRequired=Y/, data)
    end.respond_with(successful_purchase_response_with_3dsecure)

    assert_failure purchase # 3DS required means purchase not _yet_ successful
    assert_equal "UDNLRVk6eHJlZj0xNTA4MDYxNVJaMThSSjE1Uko2NFlWWg==", purchase.params["threeDSMD"]
    assert_equal "eJxVUttuwjAM/ZWKD2iaQrnJjVQGA7TBGFSTeMxSC8rohTRd2d8vKe0YD5F8jh37\r\n+CQQHiXidIeilMhghUXBD2jFkd/xPNHtCz747EaCdhhsgi1eGHyjLOIsZdR2bBdI\r\nC/VVKY48VQy4uEyWa+YN6LDbA9JASFAup2zk9Tx3pOkbhJQnyHa5FhGdf6wQC2UF\r\nQmRlqizdvc5CDeUPG7p9IC2AUp7ZUam8GBNSVZUtuIwKJZEntsgSAsQUALnr2pQm\r\nKnTDaxyx1TSoHs/BW5/2zlsofCCmAiKukLkO9Zyh07dob0yHYzoAUvPAE6OEzScb\r\ni7q2o9U2DORmUHAD1DWZ/wxoqyWmot2nRYDXPEtRV+gLfzFEWAgWrCxlrMmbFbQG\r\nQwO57/S0MM4LpU1dxM/hrJx9zU8f6/3WuZxGL6/vle+bt6gLzKhYe6h3u80yAIhp\r\nQZpnJs1X0NHDF/kFvj+6mg==", purchase.params["threeDSPaReq"]
    assert_equal "https://dropit.3dsecure.net:9443/PIT/ACS", purchase.params["threeDSACSURL"]
  end

  def test_deprecated_3ds_required
    assert_deprecation_warning(CardStreamGateway::THREEDSECURE_REQUIRED_DEPRECATION_MESSAGE) do
      @gateway = CardStreamGateway.new(
        :login => 'login',
        :shared_secret => 'secret',
        :threeDSRequired => true
      )
    end
    stub_comms do
      @gateway.purchase(142, @visacreditcard, @visacredit_options)
    end.check_request do |endpoint, data, headers|
      assert_match(/threeDSRequired=Y/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_default_3dsecure_required
    stub_comms do
      @gateway.purchase(142, @visacreditcard, @visacredit_options)
    end.check_request do |endpoint, data, headers|
      assert_match(/threeDSRequired=N/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_authorization_response
    "merchantID=0000000&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&amount=142&currencyCode=826&transactionUnique=fadc4985c51fc55ca349c45a79136ade&orderRef=AM+test+purchase&customerName=Longbob+Longsen&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG+&action=PREAUTH&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=0&responseMessage=AUTHCODE%3AD24577&xref=13021914RV01VR56LR16FNF&threeDSEnrolled=U&threeDSXID=00000000000004717472&transactionID=4717472&transactionPreviousID=0&timestamp=2013-02-19+14%3A02%3A19&amountReceived=142&avscv2ResponseCode=222100&avscv2ResponseMessage=ALL+MATCH&avscv2AuthEntity=merchant+host&cv2Check=matched&addressCheck=2&postcodeCheck=2&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0821&cardTypeCode=VC&cardType=Visa+Credit&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+14%3A01%3A56&currencyExponent=2&responseStatus=0&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end

  def successful_capture_response
    "merchantID=0000000&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&xref=13021914XW02YJ20MQ37RMT&amount=142&currencyCode=826&action=SALE&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=0&responseMessage=AUTHCODE%3A39657X&customerName=Longbob+Longsen&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG+&transactionUnique=fadc4985c51fc55ca349c45a79136ade&orderRef=AM+test+purchase&amountReceived=142&avscv2ResponseCode=422100&avscv2ResponseMessage=ALL+MATCH&avscv2AuthEntity=merchant+host&cv2Check=not+matched&addressCheck=matched&postcodeCheck=matched&threeDSXID=00000000000004717475&threeDSEnrolled=U&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+14%3A02%3A20&cardTypeCode=VC&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0821&transactionID=4717475&transactionPreviousID=4717472&timestamp=2013-02-19+14%3A02%3A44&cardType=Visa+Credit&currencyExponent=2&responseStatus=0&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end

  def successful_refund_response
    "merchantID=0000000&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&xref=13021914NT06BM21GJ15VJH&amount=142&currencyCode=826&action=REFUND&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=0&responseMessage=REFUNDACCEPTED&customerName=Longbob+Longsen&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG+&transactionUnique=c7981d78d217cf3cfda6559921e31c4a&orderRef=AM+test+purchase&amountReceived=142&avscv2ResponseCode=222100&avscv2ResponseMessage=ALL+MATCH&avscv2AuthEntity=merchant+host&cv2Check=matched&addressCheck=matched&postcodeCheck=matched&threeDSXID=00000000000004717488&threeDSEnrolled=U&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+14%3A05%3A58&cardTypeCode=VC&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0821&threeDSRequired=N&transactionID=4717490&transactionPreviousID=4717488&timestamp=2013-02-19+14%3A06%3A21&cardType=Visa+Credit&currencyExponent=2&responseStatus=0&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end

  def successful_void_response
    "merchantID=103191&threeDSEnabled=Y&avscv2CheckEnabled=N&eReceiptsEnabled=N&transactionID=11132605&xref=16050316NZ51LT53FP70BMZ&state=canceled&captureDelay=-1&remoteAddress=107.15.253.186&action=CANCEL%3ASALE&type=1&currencyCode=826&countryCode=826&amount=284&orderRef=AM+test+purchase&transactionUnique=2240526ccaa7d41af63a94aab843e683&cardTypeCode=VC&cardNumberMask=492942%2A%2A%2A%2A%2A%2A0821&cardExpiryDate=1214&cardExpiryMonth=12&cardExpiryYear=14&customerName=Longbob+Longsen&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostcode=NN17+8YG&eReceiptsStoreID=1&customerReceiptsRequired=N&cv2Check=matched&addressCheck=matched&postcodeCheck=matched&avscv2ResponseCode=222100&avscv2ResponseMessage=ALL+MATCH&avscv2AuthEntity=merchant+host&addressCheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&postcodeCheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&threeDSRequired=N&threeDSCheckPref=authenticated&authorisationCode=084609&amountReceived=0&responseCode=0&responseMessage=Transaction+cancelled.&cardCVVMandatory=N&responseStatus=0&timestamp=2016-05-03+16%3A51%3A54&cardType=Visa+Credit&cardScheme=Visa+&cardSchemeCode=VC&cardIssuer=BARCLAYS+BANK+PLC&cardIssuerCountry=United+Kingdom&cardIssuerCountryCode=GBR&signature=73cf5ec5470f6a1b3abce4e2a4b64adc2da0cb7103e8d362b40ab101d2ff339961a593869f289f7660a286e8c92c22fd5dec4330cf7e7e0ca8651cd8c0a8d966"
  end

  def successful_purchase_response
    "merchantID=0000000&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&amount=142&currencyCode=826&transactionUnique=27a594210e27846c8e9102647f210586&orderRef=AM+test+purchase&customerName=Longbob+Longsen&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG+&action=SALE&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=0&responseMessage=AUTHCODE%3A635959&xref=13021914LS06DW22NW22LVJ&threeDSEnrolled=U&threeDSXID=00000000000004717491&transactionID=4717491&transactionPreviousID=0&timestamp=2013-02-19+14%3A06%3A44&amountReceived=142&avscv2ResponseCode=222100&avscv2ResponseMessage=ALL+MATCH&avscv2AuthEntity=merchant+host&cv2Check=matched&addressCheck=matched&postcodeCheck=matched&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0821&cardTypeCode=VC&cardType=Visa+Credit&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+14%3A06%3A22&currencyExponent=2&responseStatus=0&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end

  def successful_purchase_response_with_3dsecure
    "responseCode=65802&responseMessage=3DS+AUTHENTICATION+REQUIRED&responseStatus=2&merchantID=103191&threeDSEnabled=Y&threeDSCheckPref=not+known%2Cnot+checked%2Cauthenticated%2Cnot+authenticated%2Cattempted+authentication&avscv2CheckEnabled=N&cv2CheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&addressCheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&postcodeCheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&cardCVVMandatory=Y&customerID=1749&eReceiptsEnabled=N&eReceiptsStoreID=1&amount=1202&currencyCode=826&transactionUnique=42e13d06ce4d5f5e3eb4868d29baa8bb&orderRef=AM+test+purchase&threeDSRequired=Y&customerName=Longbob+Longsen&customerAddress=25+The+Larches&customerPostCode=LE10+2RT&action=SALE&type=1&countryCode=826&customerPostcode=LE10+2RT&customerReceiptsRequired=N&state=finished&remoteAddress=45.37.180.92&requestMerchantID=103191&processMerchantID=103191&xref=15080615RZ18RJ15RJ64YVZ&cardExpiryDate=1220&threeDSXID=MDAwMDAwMDAwMDAwMDg5NjY0OTc%3D&threeDSEnrolled=Y&transactionID=8966497&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A1112&cardType=Visa+Credit&cardTypeCode=VC&cardScheme=Visa+&cardSchemeCode=VC&cardIssuer=Unknown&cardIssuerCountry=Unknown&cardIssuerCountryCode=XXX&threeDSPaReq=eJxVUttuwjAM%2FZWKD2iaQrnJjVQGA7TBGFSTeMxSC8rohTRd2d8vKe0YD5F8jh37%0D%0A%2BCQQHiXidIeilMhghUXBD2jFkd%2FxPNHtCz747EaCdhhsgi1eGHyjLOIsZdR2bBdI%0D%0AC%2FVVKY48VQy4uEyWa%2BYN6LDbA9JASFAup2zk9Tx3pOkbhJQnyHa5FhGdf6wQC2UF%0D%0AQmRlqizdvc5CDeUPG7p9IC2AUp7ZUam8GBNSVZUtuIwKJZEntsgSAsQUALnr2pQm%0D%0AKnTDaxyx1TSoHs%2FBW5%2F2zlsofCCmAiKukLkO9Zyh07dob0yHYzoAUvPAE6OEzScb%0D%0Ai7q2o9U2DORmUHAD1DWZ%2FwxoqyWmot2nRYDXPEtRV%2BgLfzFEWAgWrCxlrMmbFbQG%0D%0AQwO57%2FS0MM4LpU1dxM%2FhrJx9zU8f6%2F3WuZxGL6%2Fvle%2Bbt6gLzKhYe6h3u80yAIhp%0D%0AQZpnJs1X0NHDF%2FkFvj%2B6mg%3D%3D&threeDSACSURL=https%3A%2F%2Fdropit.3dsecure.net%3A9443%2FPIT%2FACS&threeDSVETimestamp=2015-08-06+15%3A18%3A15&threeDSCheck=not+checked&vcsResponseCode=0&vcsResponseMessage=Success+-+no+velocity+check+rules+applied&currencyExponent=2&threeDSMD=UDNLRVk6eHJlZj0xNTA4MDYxNVJaMThSSjE1Uko2NFlWWg%3D%3D&timestamp=2015-08-06+15%3A18%3A17&threeDSResponseCode=65802&threeDSResponseMessage=3DS+AUTHENTICATION+REQUIRED&signature=8551e3f1c77b6cfa78e154d99ffb05fdeabbae48a7ce723a3464047731ad98a1c4bfe0b7dfdf46de7ff3dab66b3e2e365025fc9ff3a74d86ae4378c8cc985d88"
  end

  def successful_purchase_response_with_descriptors
    "merchantID=103191&threeDSEnabled=Y&threeDSCheckPref=authenticated&avscv2CheckEnabled=N&cv2CheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&addressCheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&postcodeCheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&cardCVVMandatory=Y&customerReceiptsRequired=N&eReceiptsEnabled=N&eReceiptsStoreID=1&captureDelay=0&amount=284&currencyCode=826&statementNarrative1=merchant&statementNarrative2=product&type=1&threeDSRequired=N&customerName=Longbob+Longsen&cardExpiryMonth=12&cardExpiryYear=14&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG&countryCode=826&action=SALE&customerPostcode=NN17+8YG&requestID=586aae8406720&responseCode=0&responseMessage=AUTHCODE%3A684787&state=captured&requestMerchantID=103191&processMerchantID=103191&xref=17010219YV48VW21QH25TKS&paymentMethod=card&cardExpiryDate=1214&authorisationCode=684787&transactionID=13843073&responseStatus=0&timestamp=2017-01-02+19%3A48%3A21&amountReceived=284&avscv2ResponseCode=222100&avscv2ResponseMessage=ALL+MATCH&avscv2AuthEntity=merchant+host&cv2Check=matched&addressCheck=matched&postcodeCheck=matched&cardNumberMask=492942%2A%2A%2A%2A%2A%2A0821&cardType=Visa+Credit&cardTypeCode=VC&cardScheme=Visa+&cardSchemeCode=VC&cardIssuer=BARCLAYS+BANK+PLC&cardIssuerCountry=United+Kingdom&cardIssuerCountryCode=GBR&vcsResponseCode=0&vcsResponseMessage=Success+-+no+velocity+check+rules+applied&currencyExponent=2&signature=d47c9253d2d9ff6e9464a782b798b3fa699f6ed085eb03d5f87c4cf1f0994efab0c3145236df2163ea2b48fc0232bed25626b7ac331f0c98473ef4b551099eef"
  end

  def failed_purchase_card_declined_response
    "merchantID=0000000&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&amount=10000&currencyCode=826&transactionUnique=7385df1d9c5484142bb6be1e932cd2df&orderRef=AM+test+purchase&customerName=Longbob+Longsen&customerAddress=25+The+Larches+&customerPostCode=LE10+2RT&action=SALE&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=5&responseMessage=CARD+DECLINED&xref=13021914RQ07HK55HG29KPH&threeDSEnrolled=U&threeDSXID=00000000000004717495&transactionID=4717495&transactionPreviousID=0&timestamp=2013-02-19+14%3A08%3A18&amountReceived=0&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0191&cardTypeCode=MC&cardType=Mastercard&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+14%3A07%3A55&currencyExponent=2&responseStatus=1&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end

  def failed_authorization_response
    "merchantID=0000000&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&amount=10000&currencyCode=826&transactionUnique=7385df1d9c5484142bb6be1e932cd2df&orderRef=AM+test+purchase&customerName=Longbob+Longsen&customerAddress=25+The+Larches+&customerPostCode=LE10+2RT&action=SALE&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=5&responseMessage=CARD+DECLINED&xref=13021914RQ07HK55HG29KPH&threeDSEnrolled=U&threeDSXID=00000000000004717495&transactionID=4717495&transactionPreviousID=0&timestamp=2013-02-19+14%3A08%3A18&amountReceived=0&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0191&cardTypeCode=MC&cardType=Mastercard&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+14%3A07%3A55&currencyExponent=2&responseStatus=1&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end

  def failed_void_response
    "responseCode=65548&responseMessage=DB+ERROR&responseStatus=2&xref=16050317BX02HT10NH49ZRS&merchantID=103191&action=CANCEL&state=finished&remoteAddress=107.15.253.186&requestMerchantID=103191&processMerchantID=103191&timestamp=2016-05-03+17%3A02%3A10&signature=73d3ea59f106208fdf3b0fd1bc09a21c8bb66bbf481a7b6769959b1b3b2cbc18fbce434f2ea7f648a4dbdbf180003b0cc77036410be7f246e827ace0ed459d9b"
  end

  def successful_reference_purchase_response
    "merchantID=103191&threeDSEnabled=Y&threeDSCheckPref=authenticated&avscv2CheckEnabled=N&addressCheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&postcodeCheckPref=not+known%2Cnot+checked%2Cmatched%2Cnot+matched%2Cpartially+matched&customerReceiptsRequired=N&eReceiptsEnabled=N&eReceiptsStoreID=1&amount=142&currencyCode=826&transactionUnique=1f21b6d2fdf1f13378705707bc7e24bd&orderRef=AM+test+purchase&type=1&threeDSRequired=N&countryCode=826&action=SALE&responseCode=0&responseMessage=AUTHCODE%3A300382&state=captured&remoteAddress=107.15.253.186&requestMerchantID=103191&processMerchantID=103191&cardNumberMask=492942%2A%2A%2A%2A%2A%2A0821&cardExpiryMonth=12&cardExpiryYear=14&customerName=Longbob+Longsen&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostcode=NN17+8YG&previousID=10886746&cardCVVMandatory=N&xref=16040515PS17RG20GT73SBF&cardExpiryDate=1214&authorisationCode=300382&transactionID=10886747&responseStatus=0&timestamp=2016-04-05+15%3A17%3A20&amountReceived=142&avscv2ResponseCode=422100&avscv2ResponseMessage=ADDRESS+MATCH+ONLY&avscv2AuthEntity=merchant+host&cv2Check=not+matched&addressCheck=matched&postcodeCheck=matched&cardType=Visa+Credit&cardTypeCode=VC&cardScheme=Visa+&cardSchemeCode=VC&cardIssuer=BARCLAYS+BANK+PLC&cardIssuerCountry=United+Kingdom&cardIssuerCountryCode=GBR&vcsResponseCode=0&vcsResponseMessage=Success+-+no+velocity+check+rules+applied&currencyExponent=2&signature=9e13f5ffd9cf94215225ab60f80915879a242dcf8c30c7f39a0265acf0f3f7186cbea656d53fcce249e54f522050efd32e677726fc7d5aa1f7b6ee746e040956"
  end

  def failed_reference_purchase_response
    "responseCode=65548&responseMessage=DB+ERROR&responseStatus=2&amount=142&currencyCode=826&transactionUnique=740290de68c10d18acabe9fb0a52bd92&orderRef=AM+test+purchase&type=1&threeDSRequired=N&xref=16040515NM21GM43SF71MMR&countryCode=GB&merchantID=103191&action=SALE&state=finished&remoteAddress=107.15.253.186&requestMerchantID=103191&processMerchantID=103191&transactionID=10886787&timestamp=2016-04-05+15%3A21%3A43&vcsResponseCode=0&vcsResponseMessage=Success+-+no+velocity+check+rules+applied&signature=311f2bfd94c3807fae4fbeff13801c37d81c3e1082c5d3c5893281f18d7152b96420fa7b45285eb692b09b576b3b85d894ee35ff9e31cd06ace54019b806550f"
  end

  def transcript
    <<-eos
     POST /direct/ HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway.cardstream.com\r\nContent-Length: 501\r\n\r\n"
     amount=&currencyCode=826&transactionUnique=a017ca2ac0569188517ad8368c36a06d&orderRef=AM+test+purchase&customerName=Longbob+Longsen&cardNumber=4929421234600821&cardExpiryMonth=12&cardExpiryYear=14&cardCVV=356&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG+&merchantID=102922&action=SALE&type=1&countryCode=GB&threeDSRequired=N&signature=970b3fe099a85c9922a79af46c2cb798616b9fbd044a921ac5eb46cd1907a5e89b8c720aae59c7eb1d81a59563f209d5db51aa3c270838199f2bfdcbe2c1149d
     eos
  end

  def scrubbed_transcript
     <<-eos
     POST /direct/ HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway.cardstream.com\r\nContent-Length: 501\r\n\r\n"
     amount=&currencyCode=826&transactionUnique=a017ca2ac0569188517ad8368c36a06d&orderRef=AM+test+purchase&customerName=Longbob+Longsen&cardNumber=[FILTERED]&cardExpiryMonth=12&cardExpiryYear=14&cardCVV=[FILTERED]&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG+&merchantID=102922&action=SALE&type=1&countryCode=GB&threeDSRequired=N&signature=970b3fe099a85c9922a79af46c2cb798616b9fbd044a921ac5eb46cd1907a5e89b8c720aae59c7eb1d81a59563f209d5db51aa3c270838199f2bfdcbe2c1149d
    eos
  end
end
