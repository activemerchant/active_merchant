require File.dirname(__FILE__) + '/../../test_helper'

class PaypalExpressNvTest < Test::Unit::TestCase
  API_VER = 50.0000
  BUILD_NUM = 1
  DEBUG_TOKEN = 1

  TEST_REDIRECT_URL = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=1234567890'
  LIVE_REDIRECT_URL = 'https://www.paypal.com/cgibin/webscr?cmd=_express-checkout&token=1234567890'
  TEST_REDIRECT_URL_WITHOUT_REVIEW = "#{TEST_REDIRECT_URL}&useraction=commit"
  LIVE_REDIRECT_URL_WITHOUT_REVIEW = "#{LIVE_REDIRECT_URL}&useraction=commit"

  def setup
    @gateway = PaypalExpressNvGateway.new(
      :login => 'cody',
      :password => 'test',
      :pem => 'PEM'
    )

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }

    Base.gateway_mode = :test
  end

  def teardown
    Base.gateway_mode = :test
  end

  def test_live_redirect_url
    Base.gateway_mode = :production
    assert_equal LIVE_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
  end

  def test_force_sandbox_redirect_url
    Base.gateway_mode = :production

    gateway = PaypalExpressNvGateway.new(
      :login => 'cody',
      :password => 'test',
      :pem => 'PEM',
      :test => true
    )

    assert gateway.test?
    assert_equal TEST_REDIRECT_URL, gateway.redirect_url_for('1234567890')
  end

  def test_test_redirect_url
    assert_equal :test, Base.gateway_mode
    assert_equal TEST_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
  end
  
  def test_live_redirect_url_without_review
    Base.gateway_mode = :production
    assert_equal LIVE_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false)
  end
  
  def test_test_redirect_url_without_review
    assert_equal :test, Base.gateway_mode
    assert_equal TEST_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false)
  end

  def test_get_express_details
    @gateway.expects(:ssl_post).returns(successful_details_response)
    response = @gateway.details_for('EC-3DJ78083ES565113B')

    assert_instance_of PaypalExpressNvResponse, response
    assert response.success?
    assert response.test?

    assert_equal 'EC-3DJ78083ES565113B', response.token
    assert_equal '95HR9CM6D56Q2', response.payer_id
    assert_equal 'abcdef@anyemail.com', response.email

    assert address = response.address
    assert_equal 'John Smith', address['name']
    assert_equal 'foo inc.',  address['company']
    assert_equal '144 Main St.', address['address1']
    assert_nil address['address2']
    assert_equal 'San Jose', address['city']
    assert_equal 'CA', address['state']
    assert_equal '99221', address['zip']
    assert_equal 'US', address['country']
    assert_nil address['phone']
  end

  def test_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    response = @gateway.authorize(300, :token => 'EC-6WS104951Y388951L', :payer_id => 'FWRVKNRRZ3WUC')
    assert response.success?
    assert_not_nil response.authorization
    assert response.test?
  end

  def test_default_payflow_currency
    assert_equal 'USD', PayflowExpressNvGateway.default_currency
  end

  def test_default_partner
    assert_equal 'PayPal', PayflowExpressNvGateway.partner
  end

  def test_uk_partner
    assert_equal 'PayPalUk', PayflowExpressUkGateway.partner
  end

  def test_handle_non_zero_amount
    data = @gateway.send(:build_setup_request, 'SetExpressCheckout', 50, {})
    assert_equal '0.50', data[:amt]
  end

  def test_handles_zero_amount
    data = @gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {})
    assert_equal '0.00', data[:amt]
  end

  def test_handle_locale_code
    data = @gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :locale => 'GB' })
    assert_equal 'GB', data[:locale]
  end

  def test_supported_countries
    assert_equal ['US'], PaypalExpressNvGateway.supported_countries
  end

  def test_button_source
    PaypalExpressNvGateway.application_id = 'ActiveMerchant_EC'

    data  = @gateway.send(:build_sale_or_authorization_request, 'Test', 100, {})
    assert_equal 'ActiveMerchant_EC', data[:buttonsource]
  end

  private
  def timestamp
    Time.new.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def successful_response_fields
    resp = "ACK=Success&TIMESTAMP=#{timestamp}&"
    resp << "CORRELATIONID=#{DEBUG_TOKEN}&"
    resp << "VERSION=#{API_VER}&BUILD=#{BUILD_NUM}"
  end

  def successful_setup_response
    resp = successful_response_fields
    resp << "&TOKEN=EC-3DJ78083ES565113B"
  end

  def successful_details_response
    resp = successful_response_fields
    resp << "&TOKEN=EC-3DJ78083ES565113B&EMAIL=abcdef@anyemail.com"
    resp << "&PAYERID=95HR9CM6D56Q2&PAYERSTATUS=verified&FIRSTNAME=John"
    resp << "&LASTNAME=Smith&COUNTRYCODE=US"
    resp << "&SHIPTONAME=John Smith&SHIPTOSTREET=144+Main+St."
    resp << "&SHIPTOCITY=San+Jose&SHIPTOSTATE=CA&SHIPTOCOUNTRYCODE=US"
    resp << "&SHIPTOZIP=99221&ADDRESSID=PayPal"
    resp << "&ADDRESSSTATUS=Confirmed&BUSINESS=foo inc."
  end

  def successful_authorization_response
    resp = successful_response_fields
    resp << "&TOKEN=EC-30P862430W113011F"
    resp << "&TRANSACTIONID=4D479374VP578364Y&TRANSACTIONTYPE=expresscheckout"
    resp << "&PAYMENTTYPE=instant&ORDERTIME=2006-08-22T22:02:42Z&AMT=10.00"
    resp << "&CURRENCYCODE=USD&TAXAMT=0.00&PAYMENTSTATUS=Pending"
    resp << "&PENDINGREASON=authorization&REASONCODE=None"
  end

  def successful_sale_response
    resp = successful_response_fields
    resp << "&TOKEN=EC-0E881823PA052770A"
    resp << "&TRANSACTIONID=8SC56973LM923823H&TRANSACTIONTYPE=expresscheckout"
    resp << "&PAYMENTTYPE=instant&ORDERTIME=2006-08-22T20:16:05Z&AMT=10.00"
    resp << "&CURRENCYCODE=USD&FEEAMT=0.59&TAXAMT=0.00"
    resp << "&PAYMENTSTATUS=Completed&PENDINGREASON=None&REASONCODE=None"
  end
end
