require 'test_helper'
require 'openssl'

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
    ordered_values = "vpc_Amount=2995&vpc_MerchantId=MER123&vpc_OrderInfo=A48cvE28"
    @gateway.send(:add_secure_hash, params)
    assert_equal OpenSSL::HMAC.hexdigest('SHA256', [@gateway.options[:secure_hash]].pack('H*'), ordered_values).upcase, params[:SecureHash]
  end

  def test_purchase_offsite_response
    # Below response from instance running remote test
    response_params = "vpc_3DSXID=a1B8UcW%2BKYqkSinLQohGmqQd9uY%3D&vpc_3DSenrolled=U&vpc_AVSResultCode=Unsupported&vpc_AcqAVSRespCode=Unsupported&vpc_AcqCSCRespCode=Unsupported&vpc_AcqResponseCode=00&vpc_Amount=100&vpc_AuthorizeId=367739&vpc_BatchNo=20120421&vpc_CSCResultCode=Unsupported&vpc_Card=MC&vpc_Command=pay&vpc_Locale=en&vpc_MerchTxnRef=9&vpc_Merchant=TESTANZTEST3&vpc_Message=Approved&vpc_OrderInfo=1&vpc_ReceiptNo=120421367739&vpc_SecureHash=20DE2CDEBE40D6F24E3ABC5D74081CB5B341CD447530121AD51A9504A923BBD0&vpc_TransactionNo=2000025183&vpc_TxnResponseCode=0&vpc_VerSecurityLevel=06&vpc_VerStatus=U&vpc_VerType=3DS&vpc_Version=1"

    response_hash = @gateway.send(:parse, response_params)
    calculated_hash = @gateway.send(:calculate_secure_hash, response_hash, @gateway.options[:secure_hash])
    expected_hash_input = "vpc_3DSXID=a1B8UcW+KYqkSinLQohGmqQd9uY=&vpc_3DSenrolled=U&vpc_AVSResultCode=Unsupported&vpc_AcqAVSRespCode=Unsupported&vpc_AcqCSCRespCode=Unsupported&vpc_AcqResponseCode=00&vpc_Amount=100&vpc_AuthorizeId=367739&vpc_BatchNo=20120421&vpc_CSCResultCode=Unsupported&vpc_Card=MC&vpc_Command=pay&vpc_Locale=en&vpc_MerchTxnRef=9&vpc_Merchant=TESTANZTEST3&vpc_Message=Approved&vpc_OrderInfo=1&vpc_ReceiptNo=120421367739&vpc_TransactionNo=2000025183&vpc_TxnResponseCode=0&vpc_VerSecurityLevel=06&vpc_VerStatus=U&vpc_VerType=3DS&vpc_Version=1"
    assert_equal OpenSSL::HMAC.hexdigest('SHA256', [@gateway.options[:secure_hash]].pack('H*'), expected_hash_input).upcase, calculated_hash

    response = @gateway.purchase_offsite_response(response_params)
    assert_success response

    tampered_response1 = response_params.gsub('20DE', '20DF')
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
    options.collect { |key, value| "vpc_#{key}=#{CGI.escape(value.to_s)}"}.join('&')
  end
end
