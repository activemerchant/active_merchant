require 'test_helper'

class CardStreamTest < Test::Unit::TestCase
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

  def test_successful_visacreditcard_cancellation
    @gateway.expects(:ssl_post).returns(successful_cancellation_response)

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

  def test_declined_mastercard_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_card_declined_response)

    assert response = @gateway.purchase(10000, @visacreditcard, @visacredit_options)
    assert_equal 'CARD DECLINED', response.message
    assert_failure response
    assert response.test?
  end

  def test_hmac_signature_added_to_post
    post_params = "action=SALE&amount=10000&cardCVV=356&cardExpiryMonth=12&cardExpiryYear=14&cardNumber=4929421234600821&countryCode=GB&currencyCode=826&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerName=Longbob+Longsen&customerPostCode=NN17+8YG+&merchantID=login&orderRef=AM+test+purchase&threeDSRequired=N&transactionUnique=#{@visacredit_options[:order_id]}&type=1"
    expected_signature = Digest::SHA512.hexdigest("#{post_params}#{@gateway.options[:shared_secret]}")

    @gateway.expects(:ssl_post).with do |url, data|
      data.include?("signature=#{expected_signature}")
    end.returns(successful_authorization_response)

    @gateway.purchase(10000, @visacreditcard, @visacredit_options)
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

  def successful_purchase_response
    "merchantID=0000000&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&amount=142&currencyCode=826&transactionUnique=27a594210e27846c8e9102647f210586&orderRef=AM+test+purchase&customerName=Longbob+Longsen&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG+&action=SALE&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=0&responseMessage=AUTHCODE%3A635959&xref=13021914LS06DW22NW22LVJ&threeDSEnrolled=U&threeDSXID=00000000000004717491&transactionID=4717491&transactionPreviousID=0&timestamp=2013-02-19+14%3A06%3A44&amountReceived=142&avscv2ResponseCode=222100&avscv2ResponseMessage=ALL+MATCH&avscv2AuthEntity=merchant+host&cv2Check=matched&addressCheck=matched&postcodeCheck=matched&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0821&cardTypeCode=VC&cardType=Visa+Credit&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+14%3A06%3A22&currencyExponent=2&responseStatus=0&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end

  def successful_cancellation_response
    "merchantID=0000992&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&xref=13021918BK14KR25PZ82GHH&action=REFUND&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=0&responseMessage=REFUNDACCEPTED&amount=284&currencyCode=826&customerName=Longbob+Longsen&customerAddress=Flat+6%2C+Primrose+Rise+347+Lavender+Road&customerPostCode=NN17+8YG+&transactionUnique=86935375de4da6e1dfd63e255976d812&orderRef=AM+test+purchase&amountReceived=284&avscv2ResponseCode=222100&avscv2ResponseMessage=ALL+MATCH&avscv2AuthEntity=merchant+host&cv2Check=matched&addressCheck=matched&postcodeCheck=matched&threeDSXID=00000000000004718188&threeDSEnrolled=U&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+18%3A14%3A02&cardTypeCode=VC&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0821&threeDSRequired=N&transactionID=4718190&transactionPreviousID=4718188&timestamp=2013-02-19+18%3A14%3A26&cardType=Visa+Credit&currencyExponent=2&responseStatus=0&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end

  def failed_purchase_card_declined_response
    "merchantID=0000000&threeDSEnabled=Y&merchantDescription=General+test+account+with+AVS%2FCV2+checking&amount=10000&currencyCode=826&transactionUnique=7385df1d9c5484142bb6be1e932cd2df&orderRef=AM+test+purchase&customerName=Longbob+Longsen&customerAddress=25+The+Larches+&customerPostCode=LE10+2RT&action=SALE&type=1&countryCode=826&merchantAlias=0000992&remoteAddress=80.229.33.63&responseCode=5&responseMessage=CARD+DECLINED&xref=13021914RQ07HK55HG29KPH&threeDSEnrolled=U&threeDSXID=00000000000004717495&transactionID=4717495&transactionPreviousID=0&timestamp=2013-02-19+14%3A08%3A18&amountReceived=0&cardNumberMask=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A0191&cardTypeCode=MC&cardType=Mastercard&threeDSErrorCode=-1&threeDSErrorDescription=Error+while+attempting+to+send+the+request+to%3A+https%3A%2F%2F3dstest.universalpaymentgateway.com%3A4343%2FAPI%0A%0DPlease+make+sure+that+ActiveMerchant+server+is+running+and+the+URL+is+valid.+ERROR_INTERNET_CANNOT_CONNECT%3A+The+attempt+to+connect+to+the+server+failed.&threeDSMerchantPref=PROCEED&threeDSVETimestamp=2013-02-19+14%3A07%3A55&currencyExponent=2&responseStatus=1&merchantName=CARDSTREAM+TEST&merchantID2=100001"
  end
end
