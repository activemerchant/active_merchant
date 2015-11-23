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

  def test_scrub
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
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
    options.collect { |key, value| "vpc_#{key}=#{CGI.escape(value.to_s)}"}.join('&')
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to migs.mastercard.com.au:443...
      opened
      starting SSL for migs.mastercard.com.au:443...
      SSL established
      <- "POST /vpcdps HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUse
      r-Agent: Ruby\r\nConnection: close\r\nHost: migs.mastercard.com.au\r\nContent-Length: 247\r\n\r\n"
      <- "vpc_Amount=100&vpc_Currency=USD&vpc_OrderInfo=1&vpc_CardNum=4005550000000001&vpc_CardSecurityCode=123&vpc_CardExp=1705&vpc_Version=1&vpc_Merchant=TESTANZT
      EST3&vpc_AccessCode=6447E199&vpc_Command=pay&vpc_MerchTxnRef=40a11adade08d908b5fa177cf836b859"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 23 Nov 2015 15:25:27 GMT\r\n"
      -> "Expires: Sun, 15 Jul 1990 00:00:00 GMT\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Content-Length: 239\r\n"
      -> "P3P: CP=\"NOI DSP COR CURa ADMa TA1a OUR BUS IND UNI COM NAV INT\"\r\n"
      -> "Content-Type: text/plain;charset=iso-8859-1\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: TS0152bea3=01fb8d8de263e558e41015064dff5d113e343478b105102b3bc3774803917cbecf6200ca8f; Path=/; Secure\r\n"
      -> "\r\n"
      reading 239 bytes...
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to migs.mastercard.com.au:443...
      opened
      starting SSL for migs.mastercard.com.au:443...
      SSL established
      <- "POST /vpcdps HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUse
      r-Agent: Ruby\r\nConnection: close\r\nHost: migs.mastercard.com.au\r\nContent-Length: 247\r\n\r\n"
      <- "vpc_Amount=100&vpc_Currency=USD&vpc_OrderInfo=1&vpc_CardNum=4[FILTERED]0001&vpc_CardSecurityCode=[FILTERED]&vpc_CardExp=1705&vpc_Version=1&vpc_Merchant=TESTANZT
      EST3&vpc_AccessCode=[FILTERED]&vpc_Command=pay&vpc_MerchTxnRef=40a11adade08d908b5fa177cf836b859"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 23 Nov 2015 15:25:27 GMT\r\n"
      -> "Expires: Sun, 15 Jul 1990 00:00:00 GMT\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Content-Length: 239\r\n"
      -> "P3P: CP=\"NOI DSP COR CURa ADMa TA1a OUR BUS IND UNI COM NAV INT\"\r\n"
      -> "Content-Type: text/plain;charset=iso-8859-1\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: TS0152bea3=01fb8d8de263e558e41015064dff5d113e343478b105102b3bc3774803917cbecf6200ca8f; Path=/; Secure\r\n"
      -> "\r\n"
      reading 239 bytes...
    POST_SCRUBBED
  end
end
