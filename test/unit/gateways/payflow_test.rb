require File.dirname(__FILE__) + '/../../test_helper'

class PayflowTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card('4242424242424242')

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
  end
  
  def test_successful_request
    @credit_card.number = 1
    assert response = @gateway.purchase(100, @credit_card, {})
    assert_success response
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @credit_card.number = 2
    assert response = @gateway.purchase(100, @credit_card, {})
    assert_failure response
    assert response.test?
  end

  def test_request_error
    @credit_card.number = 3
    assert_raise(Error){ @gateway.purchase(100, @credit_card, {}) }
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
      response = @gateway.recurring(1000, @credit_card, 
        :periodicity => :monthly,
        :initial_transaction => { }
      )
    end
  end
  
  def test_initial_purchase_missing_amount
    assert_raises ArgumentError do
      response = @gateway.recurring(1000, @credit_card, 
        :periodicity => :monthly,
        :initial_transaction => { :amount => :purchase }
      )
    end
  end
  
  def test_successful_recurring_action
    @gateway.stubs(:ssl_post).returns(successful_recurring_response)
    
    response = @gateway.recurring(1000, @credit_card, :periodicity => :monthly)
    
    assert_instance_of PayflowResponse, response
    assert_success response
    assert_equal 'RT0000000009', response.profile_id
    assert response.test?
    assert_equal "R7960E739F80", response.authorization
  end
  
  def test_successful_authorization
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(100, @credit_card)
    assert_equal "Approved", response.message
    assert_success response
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
  
  def test_duplicate_response_flag
    @gateway.expects(:ssl_post).returns(successful_duplicate_response)
    
    response = @gateway.authorize(100, @credit_card)
    assert_success response
    assert response.params['duplicate']
  end
  
  def test_ensure_gateway_uses_safe_retry
    assert @gateway.retry_safe
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
  
  def successful_duplicate_response
    <<-XML
<?xml version="1.0"?>
<XMLPayResponse xmlns="http://www.verisign.com/XMLPay">
	<ResponseData>
		<Vendor>ActiveMerchant</Vendor>
		<Partner>paypal</Partner>
		<TransactionResults>
			<TransactionResult Duplicate="true">
				<Result>0</Result>
				<ProcessorResult>
					<AVSResult>A</AVSResult>
					<CVResult>M</CVResult>
					<HostCode>A</HostCode>
				</ProcessorResult>
				<IAVSResult>N</IAVSResult>
				<AVSResult>
					<StreetMatch>Match</StreetMatch>
					<ZipMatch>No Match</ZipMatch>
				</AVSResult>
				<CVResult>Match</CVResult>
				<Message>Approved</Message>
				<PNRef>V18A0CBB04CF</PNRef>
				<AuthCode>692PNI</AuthCode>
				<ExtData Name="DATE_TO_SETTLE" Value="2007-11-28 10:53:50"/>
			</TransactionResult>
		</TransactionResults>
	</ResponseData>
</XMLPayResponse>
    XML
  end
end
