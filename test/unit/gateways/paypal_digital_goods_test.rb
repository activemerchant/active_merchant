require 'test_helper'

class PaypalDigitalGoodsTest < Test::Unit::TestCase
  TEST_REDIRECT_URL         = 'https://www.sandbox.paypal.com/incontext?cmd=_express-checkout&token=1234567890&useraction=commit'
  MOBILE_TEST_REDIRECT_URL  = 'https://www.sandbox.paypal.com/incontext?cmd=_express-checkout-mobile&token=1234567890&useraction=commit'
  LIVE_REDIRECT_URL         = 'https://www.paypal.com/incontext?cmd=_express-checkout&token=1234567890&useraction=commit'
  MOBILE_LIVE_REDIRECT_URL  = 'https://www.paypal.com/incontext?cmd=_express-checkout-mobile&token=1234567890&useraction=commit'

  def setup
    @gateway = PaypalDigitalGoodsGateway.new(
      :login => 'cody',
      :password => 'test',
      :pem => 'PEM'
    )

    Base.gateway_mode = :test
  end

  def teardown
    Base.gateway_mode = :test
  end

  def test_live_redirect_url
    Base.gateway_mode = :production
    assert_equal LIVE_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
    assert_equal MOBILE_LIVE_REDIRECT_URL, @gateway.redirect_url_for('1234567890', mobile: true)
  end

  def test_test_redirect_url
    assert_equal :test, Base.gateway_mode
    assert_equal TEST_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
    assert_equal MOBILE_TEST_REDIRECT_URL, @gateway.redirect_url_for('1234567890', mobile: true)
  end

  def test_setup_request_invalid_requests
   assert_raise ArgumentError do
    @gateway.setup_purchase(100,
      :ip                => "127.0.0.1",
      :description       => "Test Title",
      :return_url        => "http://return.url",
      :cancel_return_url => "http://cancel.url")
   end

   assert_raise ArgumentError do
    @gateway.setup_purchase(100,
      :ip                => "127.0.0.1",
      :description       => "Test Title",
      :return_url        => "http://return.url",
      :cancel_return_url => "http://cancel.url",
      :items             => [ ])
   end

   assert_raise ArgumentError do
    @gateway.setup_purchase(100,
      :ip                => "127.0.0.1",
      :description       => "Test Title",
      :return_url        => "http://return.url",
      :cancel_return_url => "http://cancel.url",
      :items             => [ Hash.new ] )
   end

   assert_raise ArgumentError do
    @gateway.setup_purchase(100,
      :ip                => "127.0.0.1",
      :description       => "Test Title",
      :return_url        => "http://return.url",
      :cancel_return_url => "http://cancel.url",
      :items             => [ { :name => "Charge",
                                :number => "1",
                                :quantity => "1",
                                :amount   => 100,
                                :description => "Description",
                                :category => "Physical" } ] )
   end
  end


  def test_build_setup_request_valid
    @gateway.expects(:ssl_post).returns(successful_setup_response)

    @gateway.setup_purchase(100,
      :ip                => "127.0.0.1",
      :description       => "Test Title",
      :return_url        => "http://return.url",
      :cancel_return_url => "http://cancel.url",
      :items             => [ { :name => "Charge",
                                :number => "1",
                                :quantity => "1",
                                :amount   => 100,
                                :description => "Description",
                                :category => "Digital" } ] )

  end


  private

  def successful_setup_response
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xs=\"http://www.w3.org/2001/XMLSchema\" xmlns:cc=\"urn:ebay:apis:CoreComponentTypes\" xmlns:wsu=\"http://schemas.xmlsoap.org/ws/2002/07/utility\" xmlns:saml=\"urn:oasis:names:tc:SAML:1.0:assertion\" xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\" xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xmlns:ed=\"urn:ebay:apis:EnhancedDataTypes\" xmlns:ebl=\"urn:ebay:apis:eBLBaseComponents\" xmlns:ns=\"urn:ebay:api:PayPalAPI\">
	<SOAP-ENV:Header>
		<Security xmlns=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xsi:type=\"wsse:SecurityType\"></Security>
		<RequesterCredentials xmlns=\"urn:ebay:api:PayPalAPI\" xsi:type=\"ebl:CustomSecurityHeaderType\">
			<Credentials xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:UserIdPasswordType\">
				<Username xsi:type=\"xs:string\"></Username>
				<Password xsi:type=\"xs:string\"></Password>
				<Signature xsi:type=\"xs:string\">OMGOMGOMGOMGOMG</Signature>
				<Subject xsi:type=\"xs:string\"></Subject>
				</Credentials>
			</RequesterCredentials>
		</SOAP-ENV:Header>
	<SOAP-ENV:Body id=\"_0\">
		<SetExpressCheckoutResponse xmlns=\"urn:ebay:api:PayPalAPI\">
			<Timestamp xmlns=\"urn:ebay:apis:eBLBaseComponents\">2011-05-19T20:13:30Z</Timestamp>
			<Ack xmlns=\"urn:ebay:apis:eBLBaseComponents\">Success</Ack>
			<CorrelationID xmlns=\"urn:ebay:apis:eBLBaseComponents\">da0ed6bc90ef1</CorrelationID>
			<Version xmlns=\"urn:ebay:apis:eBLBaseComponents\">72</Version>
			<Build xmlns=\"urn:ebay:apis:eBLBaseComponents\">1882144</Build>
			<Token xsi:type=\"ebl:ExpressCheckoutTokenType\">EC-0XOMGOMGOMG</Token>
			</SetExpressCheckoutResponse>
		</SOAP-ENV:Body>
	</SOAP-ENV:Envelope>"
  end

end

