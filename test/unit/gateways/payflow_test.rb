require File.dirname(__FILE__) + '/../../test_helper'

class PayflowTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = credit_card('4242424242424242')

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
  end
  
  def teardown
    Base.gateway_mode = :test
    PayflowGateway.certification_id = nil
  end
  
  def test_successful_request
    @creditcard.number = 1
    assert response = @gateway.purchase(100, @creditcard, {})
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(100, @creditcard, {})
    assert !response.success?
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(100, @creditcard, {}) }
  end
  
  def test_using_test_mode
    assert @gateway.test?
  end
  
  def test_overriding_test_mode
    Base.gateway_mode = :production
    
    gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD',
      :test => true
    )
    
    assert gateway.test?
  end
  
  def test_using_production_mode
    Base.gateway_mode = :production
    
    gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    
    assert !gateway.test?
  end
  
  def test_certification_id_class_accessor
    PayflowGateway.certification_id = 'test'
    assert_equal 'test', PayflowGateway.certification_id
    gateway = PayflowGateway.new(:login => 'test', :password => 'test')
    assert_equal 'test', gateway.options[:certification_id]
  end
  
  def test_passed_in_certificate_overrides_class_accessor
    PayflowGateway.certification_id = 'test'
    gateway = PayflowGateway.new(:login => 'test', :password => 'test', :certification_id => 'Clobber')
    assert_equal 'Clobber', gateway.options[:certification_id]
  end
  
  def test_partner_class_accessor
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test')
    assert_equal 'PayPal', gateway.options[:partner]
  end
  
  def test_passed_in_partner_overrides_class_accessor
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test', :partner => 'PayPalUk')
    assert_equal 'PayPalUk', gateway.options[:partner]
  end
  
  def test_express_instance
    PayflowGateway.certification_id = '123456'
    gateway = PayflowGateway.new(
      :login => 'test',
      :password => 'password'
    )
    express = gateway.express
    assert_instance_of PayflowExpressGateway, express
    assert_equal '123456', express.options[:certification_id]
    assert_equal 'PayPal', express.options[:partner]
    assert_equal 'test', express.options[:login]
    assert_equal 'password', express.options[:password]
  end

  def test_default_currency
    assert_equal 'USD', PayflowGateway.default_currency
  end
  
  def test_supported_countries
    assert_equal ['US', 'CA', 'SG', 'AU'], PayflowGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :jcb, :discover, :diners_club], PayflowGateway.supported_cardtypes
  end
  
  def test_initial_recurring_transaction_missing_parameters
    assert_raises ArgumentError do
      response = @gateway.recurring(1000, @creditcard, 
        :periodicity => :monthly,
        :initial_transaction => { }
      )
    end
  end
  
  def test_initial_purchase_missing_amount
    assert_raises ArgumentError do
      response = @gateway.recurring(1000, @creditcard, 
        :periodicity => :monthly,
        :initial_transaction => { :amount => :purchase }
      )
    end
  end
  
  def test_successful_recurring_action
    @gateway.stubs(:ssl_post).returns(successful_recurring_response)
    
    response = @gateway.recurring(1000, @creditcard, :periodicity => :monthly)
    
    assert_instance_of PayflowResponse, response
    assert response.success?
    assert_equal 'RT0000000009', response.profile_id
    assert response.test?
    assert_equal "R7960E739F80", response.authorization
  end
  
  def test_successful_authorization
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(100, @creditcard, { :address => @address })
    assert_equal "Approved", response.message
    assert response.success?
    assert response.test?
    assert_equal "VUJN1A6E11D9", response.authorization
  end
  
  def test_format_issue_number
    xml = Builder::XmlMarkup.new
    credit_card = credit_card("5641820000000005",
      :type         => "switch",
      :issue_number => 1
    )
    
    @gateway.send(:add_credit_card, xml, credit_card)
    doc = REXML::Document.new(xml.target!)
    node = REXML::XPath.first(doc, '/Card/ExtData')
    assert_equal '01', node.attributes['Value']
  end
  
  def test_eof_received_on_timeout
    Net::HTTP.any_instance.stubs(:post).raises(EOFError, "end of file reached")
    
    assert_raises(ActiveMerchant::ConnectionError) do
      @gateway.purchase(100, @creditcard, {})
    end
  end
  
  def test__received_on_timeout
    Net::HTTP.any_instance.stubs(:post).raises(Errno::ECONNREFUSED, "Connection refused - connect(2)")
    
    assert_raises(ActiveMerchant::ConnectionError) do
      @gateway.purchase(100, @creditcard, {})
    end
  end
  
  private
  def successful_recurring_response
    <<-XML
<ResponseData>
  <Result>0</Result>
  <Message>Approved</Message>
  <Partner>paypal</Partner>
  <RpRef>R7960E739F80</RpRef>
  <Vendor>ActiveMerchant</Vendor>
  <ProfileId>RT0000000009</ProfileId>
</ResponseData>
  XML
  end
  
  def successful_authorization_response
    <<-XML
<ResponseData>
    <Result>0</Result>
    <Message>Approved</Message>
    <Partner>verisign</Partner>
    <HostCode>000</HostCode>
    <ResponseText>AP</ResponseText>
    <PnRef>VUJN1A6E11D9</PnRef>
    <IavsResult>N</IavsResult>
    <ZipMatch>Match</ZipMatch>
    <AuthCode>094016</AuthCode>
    <Vendor>ActiveMerchant</Vendor>
    <AvsResult>Y</AvsResult>
    <StreetMatch>Match</StreetMatch>
    <CvResult>Match</CvResult>
</ResponseData>
    XML
  end
end
