require 'test_helper'

class MigsTest < Test::Unit::TestCase
  def setup
    @gateway = MigsGateway.new(
                 :login => 'login',
                 :password => 'password',
                 :secure_hash => '76AF3392002D202A60D0AB5F9D81653C'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '123456', response.authorization
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    
    assert_equal '654321', response.authorization
  end

  def test_secure_hash
    params = {
      :MerchantId => 'MER123',
      :OrderInfo  => 'A48cvE28',
      :Amount     => 2995
    }
    ordered_values = "#{@gateway.options[:secure_hash]}2995MER123A48cvE28"

    @gateway.send(:add_secure_hash, params)
    assert_equal Digest::MD5.hexdigest(ordered_values).upcase, params[:SecureHash]
  end

  def test_purchase_offsite_response
    # Below response from instance running remote test
    response_params = "vpc_3DSXID=a1B8UcW%2BKYqkSinLQohGmqQd9uY%3D&vpc_3DSenrolled=U&vpc_AVSResultCode=Unsupported&vpc_AcqAVSRespCode=Unsupported&vpc_AcqCSCRespCode=Unsupported&vpc_AcqResponseCode=00&vpc_Amount=100&vpc_AuthorizeId=367739&vpc_BatchNo=20120421&vpc_CSCResultCode=Unsupported&vpc_Card=MC&vpc_Command=pay&vpc_Locale=en&vpc_MerchTxnRef=9&vpc_Merchant=TESTANZTEST3&vpc_Message=Approved&vpc_OrderInfo=1&vpc_ReceiptNo=120421367739&vpc_SecureHash=8794D9478D030B65F3092282E76283F8&vpc_TransactionNo=2000025183&vpc_TxnResponseCode=0&vpc_VerSecurityLevel=06&vpc_VerStatus=U&vpc_VerType=3DS&vpc_Version=1"

    response_hash = @gateway.send(:parse, response_params)
    response_hash.delete(:SecureHash)
    calculated_hash = @gateway.send(:calculate_secure_hash, response_hash, @gateway.options[:secure_hash])
    assert_equal '8794D9478D030B65F3092282E76283F8', calculated_hash

    response = @gateway.purchase_offsite_response(response_params)
    assert_success response

    tampered_response1 = response_params.gsub('83F8', '93F8')
    assert_raise(SecurityError){@gateway.purchase_offsite_response(tampered_response1)}

    tampered_response2 = response_params.gsub('Locale=en', 'Locale=es')
    assert_raise(SecurityError){@gateway.purchase_offsite_response(tampered_response2)}
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    build_response(
      :TxnResponseCode => '0',
      :TransactionNo   => '123456'
    )
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    build_response(
      :TxnResponseCode => '3',
      :TransactionNo   => '654321'
    )
  end
  
  def build_response(options)
    options.collect { |key, value| "vpc_#{key}=#{CGI.escape(value.to_s)}" }.join('&')
  end

  def expect_commit_with_tx_source
    @gateway.expects(:commit).with(has_entries(TxSource: @tx_source))
  end

  def pre_scrubbed
    <<~REQUEST
      opening connection to migs.mastercard.com.au:443...
      opened
      starting SSL for migs.mastercard.com.au:443...
      SSL established
      <- "POST /vpcdps HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: migs.mastercard.com.au\r\nContent-Length: 354\r\n\r\n"
      <- "vpc_Amount=100&vpc_Currency=SAR&vpc_OrderInfo=1&vpc_CardNum=4987654321098769&vpc_CardSecurityCode=123&vpc_CardExp=2105&vpc_Version=1&vpc_Merchant=TESTH-STATION&vpc_AccessCode=F1CE6F32&vpc_Command=pay&vpc_MerchTxnRef=84c1f31ded35dea26ac297fd7ba092da&vpc_SecureHash=CD1B2B8BC325C6C8FC1A041AD6AC90821984277113DF708B16B37809E7B0EC33&vpc_SecureHashType=SHA256&vpc_VerType=3DS&vpc_3DSXID=YzRjZWRjODY4MmY2NGQ3ZTgzNDQ&vpc_VerToken=AAACAgeVABgnAggAQ5UAAAAAAAA&vpc_3DSenrolled=Y&vpc_3DSECI=05&3DSstatus=Y"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Tue, 13 Feb 2018 19:02:18 GMT\r\n"
      -> "Expires: Sun, 15 Jul 1990 00:00:00 GMT\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Content-Length: 595\r\n"
      -> "P3P: CP=\"NOI DSP COR CURa ADMa TA1a OUR BUS IND UNI COM NAV INT\"\r\n"
      -> "Content-Type: text/plain;charset=iso-8859-1\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: TS01c4b9ca=01fb8d8de2ba6ffaf7439497dd78d9b3348c82bcf24d4619e65a406161e57276b6b293e77732a293be63bf750213e588797bc86f05; Path=/; Secure; HTTPOnly\r\n"
      -> "\r\n"
      reading 595 bytes...
      -> "vpc_AVSResultCode=Unsupported&vpc_AcqAVSRespCode=Unsupported&vpc_AcqCSCRespCode=Unsupported&vpc_AcqResponseCode=00&vpc_Amount=100&vpc_AuthorizeId=239491&vpc_BatchNo=20180214&vpc_CSCResultCode=Unsupported&vpc_Card=VC&vpc_Command=pay&vpc_Currency=SAR&vpc_Locale=en_SA&vpc_MerchTxnRef=84c1f31ded35dea26ac297fd7ba092da&vpc_Merchant=TESTH-STATION&vpc_Message=Approved&vpc_OrderInfo=1&vpc_ReceiptNo=804506239491&vpc_RiskOverallResult=ACC&vpc_SecureHash=99993E000461810D9F71B1A4FC5EA2D68DF6BA1F7EBA6A9FC544DA035627C03C&vpc_SecureHashType=SHA256&vpc_TransactionNo=372&vpc_TxnResponseCode=0&vpc_Version=1&vpc_VerType=3DS&vpc_3DSXID=YzRjZWRjODY4MmY2NGQ3ZTgzNDQ&vpc_VerToken=AAACAgeVABgnAggAQ5UAAAAAAAA&vpc_3DSenrolled=Y&vpc_3DSECI=05&3DSstatus=Y"
      read 595 bytes
      Conn close
    REQUEST
  end

  def post_scrubbed
    <<~REQUEST
      opening connection to migs.mastercard.com.au:443...
      opened
      starting SSL for migs.mastercard.com.au:443...
      SSL established
      <- "POST /vpcdps HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: migs.mastercard.com.au\r\nContent-Length: 354\r\n\r\n"
      <- "vpc_Amount=100&vpc_Currency=SAR&vpc_OrderInfo=1&vpc_CardNum=[FILTERED]&vpc_CardSecurityCode=[FILTERED]&vpc_CardExp=2105&vpc_Version=1&vpc_Merchant=TESTH-STATION&vpc_AccessCode=[FILTERED]&vpc_Command=pay&vpc_MerchTxnRef=84c1f31ded35dea26ac297fd7ba092da&vpc_SecureHash=CD1B2B8BC325C6C8FC1A041AD6AC90821984277113DF708B16B37809E7B0EC33&vpc_SecureHashType=SHA256&vpc_VerType=3DS&vpc_3DSXID=[FILTERED]&vpc_VerToken=[FILTERED]&vpc_3DSenrolled=Y&vpc_3DSECI=05&3DSstatus=Y"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Tue, 13 Feb 2018 19:02:18 GMT\r\n"
      -> "Expires: Sun, 15 Jul 1990 00:00:00 GMT\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Content-Length: 595\r\n"
      -> "P3P: CP=\"NOI DSP COR CURa ADMa TA1a OUR BUS IND UNI COM NAV INT\"\r\n"
      -> "Content-Type: text/plain;charset=iso-8859-1\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: TS01c4b9ca=01fb8d8de2ba6ffaf7439497dd78d9b3348c82bcf24d4619e65a406161e57276b6b293e77732a293be63bf750213e588797bc86f05; Path=/; Secure; HTTPOnly\r\n"
      -> "\r\n"
      reading 595 bytes...
      -> "vpc_AVSResultCode=Unsupported&vpc_AcqAVSRespCode=Unsupported&vpc_AcqCSCRespCode=Unsupported&vpc_AcqResponseCode=00&vpc_Amount=100&vpc_AuthorizeId=239491&vpc_BatchNo=20180214&vpc_CSCResultCode=Unsupported&vpc_Card=VC&vpc_Command=pay&vpc_Currency=SAR&vpc_Locale=en_SA&vpc_MerchTxnRef=84c1f31ded35dea26ac297fd7ba092da&vpc_Merchant=TESTH-STATION&vpc_Message=Approved&vpc_OrderInfo=1&vpc_ReceiptNo=804506239491&vpc_RiskOverallResult=ACC&vpc_SecureHash=99993E000461810D9F71B1A4FC5EA2D68DF6BA1F7EBA6A9FC544DA035627C03C&vpc_SecureHashType=SHA256&vpc_TransactionNo=372&vpc_TxnResponseCode=0&vpc_Version=1&vpc_VerType=3DS&vpc_3DSXID=[FILTERED]&vpc_VerToken=[FILTERED]&vpc_3DSenrolled=Y&vpc_3DSECI=05&3DSstatus=Y"
      read 595 bytes
      Conn close
    REQUEST
  end
end
