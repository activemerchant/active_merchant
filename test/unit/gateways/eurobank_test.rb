require 'test_helper'

class EurobankTest < Test::Unit::TestCase
  def setup
    @gateway = EurobankGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number     => '4111111111111111',
      :month      => '8',
      :year       => '2011',
      :first_name => 'Tobias',
      :last_name  => 'Luetke',
      :verification_value  => '123'
    )

    @amount = 100
    
    @options = { 
      :order_id => 'Some order id',
      :description => 'Description'
    }
  end

  def test_authorize_xml
    expected_authorize_request_xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
  <JProxyPayLink>
    <Message>
      <Type>PreAuth</Type>
      <Authentication>
        <MerchantID>login</MerchantID>
        <Password>password</Password>
      </Authentication>
      <OrderInfo>
        <Amount>100</Amount>
        <MerchantRef>Some order id</MerchantRef>
        <MerchantDesc>Description</MerchantDesc>
        <Currency>978</Currency>
        <CustomerEmail></CustomerEmail>
        <Var1>Variable 1</Var1>
        <Var2>Variable 2</Var2>
        <Var3 />
        <Var4 />
        <Var5 />
        <Var6 />
        <Var7 />
        <Var8 />
        <Var9 />
      </OrderInfo>
      <PaymentInfo>
        <CCN>4111111111111111</CCN>
        <Expdate>0811</Expdate>
        <CVCCVV>123</CVCCVV>
        <InstallmentOffset>0</InstallmentOffset>
        <InstallmentPeriod>0</InstallmentPeriod>
      </PaymentInfo>
    </Message>
  </JProxyPayLink>
XML

    params = {:money => @amount,
              :order_id => @options[:order_id],
              :description => @options[:description],
              :variables => ["Variable 1", "Variable 2"],
              :creditcard => @credit_card}
    actual_authorize_request_xml = @gateway.send(:build_xml, :authorize, params)

    assert_equal expected_authorize_request_xml, actual_authorize_request_xml
  end

  def test_successful_authorize_request
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    
    assert_equal '10186301', response.authorization
    assert response.test?
  end

  def test_unsuccessful_authorize_request
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '0', response.authorization
    assert response.test?
  end

  def test_capture_xml
    expected_capture_request_xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
  <JProxyPayLink>
    <Message>
      <Type>Capture</Type>
      <Authentication>
        <MerchantID>login</MerchantID>
        <Password>password</Password>
      </Authentication>
      <OrderInfo>
        <Amount>100</Amount>
        <MerchantRef>Some order id</MerchantRef>
        <MerchantDesc>Description</MerchantDesc>
        <Currency>978</Currency>
        <CustomerEmail></CustomerEmail>
        <Var1>Variable 1</Var1>
        <Var2>Variable 2</Var2>
        <Var3 />
        <Var4 />
        <Var5 />
        <Var6 />
        <Var7 />
        <Var8 />
        <Var9 />
      </OrderInfo>
    </Message>
  </JProxyPayLink>
XML

    params = {:money => @amount,
              :order_id => @options[:order_id],
              :description => @options[:description],
              :variables => ["Variable 1", "Variable 2"]}
    actual_capture_request_xml = @gateway.send(:build_xml, :capture, params)

    assert_equal expected_capture_request_xml, actual_capture_request_xml
  end

  def test_successful_capture_request
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response

    assert_equal '0', response.authorization
    assert response.test?
  end

    def test_credit_xml
    expected_credit_request_xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
  <JProxyPayLink>
    <Message>
      <Type>Refund</Type>
      <Authentication>
        <MerchantID>login</MerchantID>
        <Password>password</Password>
      </Authentication>
      <OrderInfo>
        <Amount>100</Amount>
        <MerchantRef>Some order id</MerchantRef>
        <MerchantDesc>Description</MerchantDesc>
        <Currency>978</Currency>
        <CustomerEmail></CustomerEmail>
        <Var1>Variable 1</Var1>
        <Var2>Variable 2</Var2>
        <Var3 />
        <Var4 />
        <Var5 />
        <Var6 />
        <Var7 />
        <Var8 />
        <Var9 />
      </OrderInfo>
    </Message>
  </JProxyPayLink>
XML

    params = {:money => @amount,
              :order_id => @options[:order_id],
              :description => @options[:description],
              :variables => ["Variable 1", "Variable 2"]}
    actual_credit_request_xml = @gateway.send(:build_xml, :credit, params)

    assert_equal expected_credit_request_xml, actual_credit_request_xml
  end

  def test_void_xml
    expected_void_request_xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
  <JProxyPayLink>
    <Message>
      <Type>Cancel</Type>
      <Authentication>
        <MerchantID>login</MerchantID>
        <Password>password</Password>
      </Authentication>
      <OrderInfo>
        <Amount>0</Amount>
        <MerchantRef>Some order id</MerchantRef>
        <MerchantDesc>Description</MerchantDesc>
        <Currency>978</Currency>
        <CustomerEmail></CustomerEmail>
        <Var1>Variable 1</Var1>
        <Var2>Variable 2</Var2>
        <Var3 />
        <Var4 />
        <Var5 />
        <Var6 />
        <Var7 />
        <Var8 />
        <Var9 />
      </OrderInfo>
    </Message>
  </JProxyPayLink>
XML

    params = {:money => 0,
              :order_id => @options[:order_id],
              :description => @options[:description],
              :variables => ["Variable 1", "Variable 2"]}
    actual_void_request_xml = @gateway.send(:build_xml, :void, params)

    assert_equal expected_void_request_xml, actual_void_request_xml
  end

  #######
  private
  #######

  def successful_authorize_response
    <<XML
<?xml version="1.0" encoding="UTF-8"?><RESPONSE> <ERRORCODE>0</ERRORCODE> <ERRORMESSAGE> </ERRORMESSAGE> <REFERENCE>Some order id</REFERENCE> <PROXYPAYREF>10186301</PROXYPAYREF> <SEQUENCE>0</SEQUENCE></RESPONSE>
XML
  end
  
  def failed_authorize_response
    <<XML
<?xml version="1.0" encoding="UTF-8"?><RESPONSE> <ERRORCODE>30</ERRORCODE> <ERRORMESSAGE> Could not send payment request to acquirer</ERRORMESSAGE> <REFERENCE>Some order id</REFERENCE> <PROXYPAYREF>0</PROXYPAYREF> <SEQUENCE>0</SEQUENCE></RESPONSE>
XML
  end

  def successful_capture_response
    <<XML
<?xml version="1.0" encoding="UTF-8"?><RESPONSE> <ERRORCODE>0</ERRORCODE> <ERRORMESSAGE> </ERRORMESSAGE> <REFERENCE>Some order id</REFERENCE> <PROXYPAYREF>0</PROXYPAYREF> <SEQUENCE>0</SEQUENCE></RESPONSE>
XML
  end

end
