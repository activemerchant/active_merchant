require 'test_helper'

class NetbillingTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = NetbillingGateway.new(:login => 'login')

    @credit_card = credit_card('4242424242424242')
    @amount = 100
    @options = { :billing_address => address }
  end

  def test_successful_request
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '110270311543', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_site_tag_sent_if_provided
    @gateway = NetbillingGateway.new(:login => 'login', :site_tag => 'dummy-site-tag')

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/site_tag=dummy-site-tag/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_site_tag_not_sent_if_not_provided
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/site_tag/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_repeat_purchase
    @gateway.expects(:ssl_post).returns(successful_repeat_purchase_response)

    assert response = @gateway.purchase(@amount, '112281536850', @options)
    assert_success response
    assert_equal '112232503575', response.authorization
    assert response.test?
  end

  def test_unsuccessful_repeat_purchase_invalid_trans_id
    http_response = mock()
    http_response.stubs(:code).returns('611')
    http_response.stubs(:body).returns('')
    http_response.stubs(:message).returns(unsuccessful_repeat_purchase_invalid_trans_id_response)
    response_error = ::ActiveMerchant::ResponseError.new(http_response)
    @gateway.expects(:ssl_post).raises(response_error)

    assert response = @gateway.purchase(@amount, '1111', @options)
    assert_failure response
    assert_match(/no record found/i, response.message)
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_store_invalid_billing_info
    http_response = mock()
    http_response.stubs(:code).returns('699')
    http_response.stubs(:body).returns('')
    http_response.stubs(:message).returns(unsuccessful_store_invalid_billing_info_response)
    response_error = ::ActiveMerchant::ResponseError.new(http_response)
    @gateway.expects(:ssl_post).raises(response_error)

    assert response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_match(/invalid credit card number/i, response.message)
    assert response.test?
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private
  def successful_purchase_response
    "avs_code=X&cvv2_code=M&status_code=1&auth_code=999999&trans_id=110270311543&auth_msg=TEST+APPROVED&auth_date=2008-01-25+16:43:54"
  end

  def unsuccessful_purchase_response
    "status_code=0&auth_msg=CARD+EXPIRED&trans_id=110492608613&auth_date=2008-01-25+17:47:44"
  end

  def successful_repeat_purchase_response
    "avs_code=X&cvv2_code=M&status_code=1&processor=TEST&auth_code=999999&settle_amount=1.00&settle_currency=USD&trans_id=112232503575&auth_msg=TEST+APPROVED&auth_date=2014-12-29+18:23:40"
  end

  def unsuccessful_repeat_purchase_invalid_trans_id_response
    "No Record Found For Specified ID"
  end

  def successful_store_response
    "status_code=T&processor=TEST&settle_amount=0.00&settle_currency=USD&trans_id=112235386882&auth_msg=OFFLINE+RECORD&auth_date=2014-12-29+18:23:43"
  end

  def unsuccessful_store_invalid_billing_info_response
    "20111: Invalid credit card number: 123"
  end

  def transcript
    "amount=1.00&description=Internet+purchase&bill_name1=Longbob&bill_name2=Longsen&card_number=4444111111111119&card_expire=0916&card_cvv2=123&bill_street=1600+Amphitheatre+Parkway&cust_phone=650-253-0001&bill_zip=94043&bill_city=Mountain+View&bill_country=US&bill_state=CA&account_id=104901072025&pay_type=C&tran_type=S"
  end

  def scrubbed_transcript
    "amount=1.00&description=Internet+purchase&bill_name1=Longbob&bill_name2=Longsen&card_number=[FILTERED]&card_expire=0916&card_cvv2=[FILTERED]&bill_street=1600+Amphitheatre+Parkway&cust_phone=650-253-0001&bill_zip=94043&bill_city=Mountain+View&bill_country=US&bill_state=CA&account_id=104901072025&pay_type=C&tran_type=S"
  end
end
