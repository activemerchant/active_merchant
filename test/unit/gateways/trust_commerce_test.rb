require 'test_helper'

class TrustCommerceTest < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = TrustCommerceGateway.new(
      :login => 'TestMerchant',
      :password => 'password',
      :aggregator_id => 'abc123'
    )
    # Force SSL post
    @gateway.stubs(:tclink?).returns(false)

    @amount = 100
    @check = check
    @credit_card = credit_card('4111111111111111')
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '025-0007423614|sale', response.authorization
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_succesful_purchase_with_check
    ActiveMerchant::Billing::TrustCommerceGateway.application_id = 'abc123'
    stub_comms do
      @gateway.purchase(@amount, @check)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{aggregator1}, data)
      assert_match(%r{name=Jim\+Smith}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_successful_void_from_purchase
    stub_comms do
      @gateway.void('1235|sale')
    end.check_request do |endpoint, data, headers|
      assert_match(%r{action=void}, data)
    end.respond_with(successful_void_response)
  end

  def test_successful_void_from_authorize
    stub_comms do
      @gateway.void('1235|preauth')
    end.check_request do |endpoint, data, headers|
      assert_match(%r{action=reversal}, data)
    end.respond_with(successful_void_response)
  end

  def test_amount_style
    assert_equal '1034', @gateway.send(:amount, 1034)

    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.34')
    end
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Y', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'P', response.cvv_result['code']
  end

  def test_supported_countries
    assert_equal ['US'], TrustCommerceGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :discover, :american_express, :diners_club, :jcb], TrustCommerceGateway.supported_cardtypes
  end

  def test_test_flag_should_be_set_when_using_test_login_in_production
    Base.mode = :production
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert response.test?
  ensure
    Base.mode = :test
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    <<-RESPONSE
transid=025-0007423614
status=approved
avs=Y
cvv=P
    RESPONSE
  end

  def unsuccessful_purchase_response
    <<-RESPONSE
transid=025-0007423827
declinetype=cvv
status=decline
cvv=N
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
transid=025-0007423828
status=accpeted
    RESPONSE
  end

  def transcript
    <<-TRANSCRIPT
action=sale&demo=y&password=password&custid=TestMerchant&shipto_zip=90001&shipto_state=CA&shipto_city=Somewhere&shipto_address1=123+Test+St.&avs=n&zip=90001&state=CA&city=Somewhere&address1=123+Test+St.&cvv=1234&exp=0916&cc=4111111111111111&name=Longbob+Longsen&media=cc&ip=10.10.10.10&email=cody%40example.com&ticket=%231000.1&amount=100
    TRANSCRIPT
  end

  def scrubbed_transcript
    <<-TRANSCRIPT
action=sale&demo=y&password=[FILTERED]&custid=TestMerchant&shipto_zip=90001&shipto_state=CA&shipto_city=Somewhere&shipto_address1=123+Test+St.&avs=n&zip=90001&state=CA&city=Somewhere&address1=123+Test+St.&cvv=[FILTERED]&exp=0916&cc=[FILTERED]&name=Longbob+Longsen&media=cc&ip=10.10.10.10&email=cody%40example.com&ticket=%231000.1&amount=100
    TRANSCRIPT
  end
end
