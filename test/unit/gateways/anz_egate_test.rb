require 'test_helper'

class AnzEgateTest < Test::Unit::TestCase
  def setup
    @gateway = AnzEgateGateway.new(
                 :merchant_id => 'TESTMERCHANT01',
                 :access_code => 'ABCDEF'
               )

    @credit_card = credit_card
    @amount = 100

    @authorization = '1234'
    
    @options = { 
      :invoice => '1',
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
    
    assert_equal @authorization, response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end

  def test_amount_style
    assert_equal '1034', @gateway.send(:amount, 1034)

    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.34')
    end
  end

  def test_ensure_does_not_respond_to_authorize
    assert !@gateway.respond_to?(:authorize)
  end
  
  def test_ensure_does_not_respond_to_capture
    assert !@gateway.respond_to?(:capture) || @gateway.method(:capture).owner != @gateway.class
  end

  private
  
  def successful_purchase_response
    "vpc_AVSResultCode=Unsupported&vpc_AcqAVSRespCode=Unsupported&vpc_AcqCSCRespCode=Unsupported&vpc_AcqResponseCode=00&vpc_Amount=100&vpc_AuthorizeId=47382&vpc_BatchNo=20120402&vpc_CSCResultCode=Unsupported&vpc_Card=MC&vpc_Command=pay&vpc_Locale=en_AU&vpc_MerchTxnRef=1&vpc_Message=Approved&vpc_OrderInfo=1&vpc_ReceiptNo=120402467852&vpc_TransactionNo=#{@authorization}&vpc_TxnResponseCode=0&vpc_Version=1"
  end
  
  def failed_purchase_response
    "vpc_AVSResultCode=Unsupported&vpc_AcqAVSRespCode=Unsupported&vpc_AcqCSCRespCode=Unsupported&vpc_AcqResponseCode=01&vpc_Amount=101&vpc_BatchNo=20120402&vpc_CSCResultCode=Unsupported&vpc_Card=MC&vpc_Command=pay&vpc_Locale=en_AU&vpc_MerchTxnRef=1&vpc_Message=Declined&vpc_OrderInfo=1&vpc_ReceiptNo=120402467935&vpc_TransactionNo=2000000359&vpc_TxnResponseCode=2&vpc_Version=1"
  end
end
