require 'test_helper'

class XChargeTest < Test::Unit::TestCase
  def setup
    @gateway = XChargeGateway.new(
                 :XWebID => 'login',
                 :AuthKey => 'password',
                 :TerminalID => "12345",
                 :Industry => "ECOMMERCE"
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_get).returns(successful_authorization_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '000000000785', response.authorization
    assert response.test?
  end
  
  def test_successful_authorization_and_capture
    @gateway.expects(:ssl_get).returns(successful_authorization_response)
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, auth
    assert_success auth
    assert_equal '000000000785', auth.authorization
    assert auth.test?
    
    @gateway.expects(:ssl_get).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, auth)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_get).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '000000000787', response.authorization
    assert response.test?
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_get).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_get).returns(successful_purchase_response)
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    
    @gateway.expects(:ssl_get).returns(successful_void_response)
    assert response = @gateway.void(purchase.authorization)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end
  
  def test_failed_void
    @gateway.expects(:ssl_get).returns(failed_void_response)
    assert response = @gateway.void("123")
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
  
  def test_successful_return
    @gateway.expects(:ssl_get).returns(successful_purchase_response)
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    
    @gateway.expects(:ssl_get).returns(successful_return_response)
    assert response = @gateway.return(@amount, purchase.authorization)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end
  
  def test_failed_return
    @gateway.expects(:ssl_get).returns(failed_return_response)
    assert response = @gateway.return(@amount, "123")
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
  
  def test_successful_alias_create
    @gateway.expects(:ssl_get).returns(successful_alias_create_response)
    assert response = @gateway.alias_create(@credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end
  
  def test_failed_alias_create
    @gateway.expects(:ssl_get).returns(failed_alias_create_response)
    assert response = @gateway.alias_create(@credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
  
  def test_successful_alias_update
    @gateway.expects(:ssl_get).returns(successful_alias_update_response)
    assert response = @gateway.alias_update("12345", @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end
  
  def test_failed_alias_update
    @gateway.expects(:ssl_get).returns(failed_alias_update_response)
    assert response = @gateway.alias_update("12345", @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
  
  def test_successful_alias_lookup
    @gateway.expects(:ssl_get).returns(successful_alias_lookup_response)
    assert response = @gateway.alias_lookup("12345")
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end
  
  def test_failed_alias_lookup
    @gateway.expects(:ssl_get).returns(failed_alias_lookup_response)
    assert response = @gateway.alias_lookup("12345")
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
  
  def test_successful_alias_delete
    @gateway.expects(:ssl_get).returns(successful_alias_delete_response)
    assert response = @gateway.alias_delete("12345")
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end
  
  def test_failed_alias_delete
    @gateway.expects(:ssl_get).returns(failed_alias_delete_response)
    assert response = @gateway.alias_delete("12345")
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
  
  def test_successful_purchase_with_alias
    @gateway.expects(:ssl_get).returns(successful_purchase_with_alias_response)
    assert response = @gateway.purchase(@amount, "123", @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '000000000985', response.authorization
    assert response.test?
  end
  
  def test_failed_purchase_with_alias
    @gateway.expects(:ssl_get).returns(failed_purchase_with_alias_response)
    assert response = @gateway.purchase(@amount, "123", @options)
    assert_failure response
    assert response.test?
  end
  
  private
  
  def successful_authorization_response
    "ResponseCode=000&ResponseDescription=Approval&TransactionID=000000000785&InvoiceNumber=1&Amount=1.00&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912&AcctNumSource=Manual&ProcessorResponse=DEVELOPMENT+APPROVAL&BatchNum=000039&BatchAmount=320.01&ApprovalCode=098825&CommercialCardResponseCode=0&CardCodeResponse=M"
  end
  
  def successful_capture_response
    "ResponseCode=000&ResponseDescription=Approval&TransactionID=000000000789&InvoiceNumber=1&Amount=1.00&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912&AcctNumSource=Manual&BatchNum=000039&BatchAmount=322.01&ApprovalCode=605109&CommercialCardResponseCode=0&CardCodeResponse=M"
  end
  
  def failed_authorization_response
    "ResponseCode=001&ResponseDescription=Decline&TransactionID=000000000786&InvoiceNumber=1&Amount=13.01&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912&AcctNumSource=Manual&ProcessorResponse=DEVELOPMENT+DECLINE&BatchNum=000039&BatchAmount=320.01&CommercialCardResponseCode=0&CardCodeResponse=M"
  end
  
  def successful_purchase_response
    "ResponseCode=000&ResponseDescription=Approval&TransactionID=000000000787&InvoiceNumber=1&Amount=1.00&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912&AcctNumSource=Manual&ProcessorResponse=DEVELOPMENT+APPROVAL&BatchNum=000039&BatchAmount=321.01&ApprovalCode=302826&CommercialCardResponseCode=0&CardCodeResponse=M"
  end
  
  def failed_purchase_response
    "ResponseCode=001&ResponseDescription=Decline&TransactionID=000000000788&InvoiceNumber=1&Amount=13.01&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912&AcctNumSource=Manual&ProcessorResponse=DEVELOPMENT+DECLINE&BatchNum=000039&BatchAmount=321.01&CommercialCardResponseCode=0&CardCodeResponse=M"
  end
  
  def successful_void_response
    "ResponseCode=000&ResponseDescription=Approval&TransactionID=000000000798&InvoiceNumber=1&Amount=1.00&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912&AcctNumSource=Manual&BatchNum=000039&BatchAmount=326.01"
  end
  
  def failed_void_response
    "ResponseCode=811&ResponseDescription=Improper+Field+Data+Error%3a+TransactionID&TransactionID=000000000800"
  end
  
  def successful_return_response
    "ResponseCode=000&ResponseDescription=Approval&TransactionID=000000000804&Amount=1.00&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912&AcctNumSource=Manual&BatchNum=000039&BatchAmount=327.01"
  end
  
  def failed_return_response
    "ResponseCode=811&ResponseDescription=Improper+Field+Data+Error%3a+TransactionID&TransactionID=000000000805"
  end
  
  def successful_alias_create_response
    "ResponseCode=005&ResponseDescription=Alias+Success%3a+Created&TransactionID=000000000856&Alias=Bog981RC18&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912"
  end
  
  def failed_alias_create_response
    "ResponseCode=800&ResponseDescription=Parsing+Error%3a+AcctNum+must+have+value+data+(index%3a+31)"
  end
  
  def successful_alias_update_response
    "ResponseCode=005&ResponseDescription=Alias+Success%3a+Updated&TransactionID=000000000883&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912"
  end
    
  def failed_alias_update_response
    "ResponseCode=811&ResponseDescription=Improper+Field+Data+Error%3a+Alias&TransactionID=000000000881"
  end
  
  def successful_alias_lookup_response
    "ResponseCode=005&ResponseDescription=Alias+Success%3a+Looked+Up&TransactionID=000000000889&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912"
  end
  
  def failed_alias_lookup_response
    "ResponseCode=811&ResponseDescription=Improper+Field+Data+Error%3a+Alias&TransactionID=000000000890"
  end
  
  def successful_alias_delete_response
    "ResponseCode=005&ResponseDescription=Alias+Success%3a+Deleted&TransactionID=000000000981"
  end
  
  def failed_alias_delete_response
    "ResponseCode=811&ResponseDescription=Improper+Field+Data+Error%3a+Alias&TransactionID=000000000982"
  end
  
  def successful_purchase_with_alias_response
    "ResponseCode=000&ResponseDescription=Approval&TransactionID=000000000985&InvoiceNumber=1&Amount=1.00&CardType=Visa&MaskedAcctNum=************2224&ExpDate=0912&AcctNumSource=Manual&ProcessorResponse=DEVELOPMENT+APPROVAL&BatchNum=000045&BatchAmount=3.00&ApprovalCode=840902&CommercialCardResponseCode=0&CardCodeResponse=M"
  end
  
  def failed_purchase_with_alias_response
    "ResponseCode=811&ResponseDescription=Improper+Field+Data+Error%3a+Alias&TransactionID=000000000986"
  end
  
end