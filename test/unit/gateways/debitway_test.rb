require 'test_helper'

class DebitwayTest < Test::Unit::TestCase
  def setup
    @gateway = DebitwayGateway.new(
        :identifier => 'identifier',
        :vericode => 'vericode',
        :website_unique_id => 'website_unique_id')

    @credit_card = credit_card

    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'SUCCESS', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'FAILURE', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
    assert_equal 'FAILURE', auth.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'SUCCESS', capture.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(failed_capture_response)
    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_failure capture
    assert_equal 'FAILURE', capture.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_post).returns(failed_refund_response)
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_failure refund
    assert_equal 'FAILURE', refund.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'SUCCESS', void.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(failed_void_response)
    assert void = @gateway.void(auth.authorization)
    assert_failure void
    assert_equal 'FAILURE', void.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    '"action=payment&address=4444+Levesque+St.+Apt+B&amount=10.00&cc_expdate=1812&cc_number=4444777711119999&cc_security_code=123&cc_type=VISA&city=Montreal&country=CA&currency=USD&custom=Additional+Description&email=testemail%40debitway.com&first_name=Jon&identifier=EGN1151306ay288&ip_address=126.44.22.11&item_name=Store+Purchase&last_name=Doe&merchant_transaction_id=cb72422d9b45495fabb1e18328ab14b8&phone=55544433344&quantity=1&return_url=http%3A%2F%2Fwww.sample.com%2Freturn%2F&state_or_province=QC&vericode=Veri4SRskraQg6&website_unique_id=uBR4zYoAXEdcZsKh&zip_or_postal_code=H2C1X8"'
  end

  def post_scrubbed
    '"action=payment&address=4444+Levesque+St.+Apt+B&amount=10.00&cc_expdate=[FILTERED]&cc_number=[FILTERED]&cc_security_code=[FILTERED]&cc_type=VISA&city=Montreal&country=CA&currency=USD&custom=Additional+Description&email=testemail%40debitway.com&first_name=Jon&identifier=[FILTERED]&ip_address=126.44.22.11&item_name=Store+Purchase&last_name=Doe&merchant_transaction_id=cb72422d9b45495fabb1e18328ab14b8&phone=55544433344&quantity=1&return_url=http%3A%2F%2Fwww.sample.com%2Freturn%2F&state_or_province=QC&vericode=[FILTERED]&website_unique_id=[FILTERED]&zip_or_postal_code=H2C1X8"'
  end

  def successful_purchase_response
    'transaction_id="7792020717140638" merchant_transaction_id="5f6d85ff930d59a8946db91dea7f2661" action="payment" result="success" amount="10.00" currency="USD" gross="10.00" net="10.00" custom="ADDITIONAL DESCRIPTION" identifier="EGN1151306ay288" business="tech@debitway.ca" item_name="STORE PURCHASE" item_code="" quantity="1" transaction_type="payment" transaction_status="approved" transaction_date="2017-02-07 14:06:39" processing_rate="0" discount_fee="0" additional_fee="0" first_name="JON" last_name="DOE" phone="55544433344" email="testemail@debitway.com" shipment="no" address="4444 LEVESQUE ST. APT B" city="MONTREAL" state_or_province="QC" country="CA" zip_or_postal_code="H2C1X8" shipping_address="" shipping_city="" shipping_state_or_province="" shipping_country="" shipping_zip_or_postal_code="" processing_time="1.723"'
  end

  def failed_purchase_response
    'transaction_id="4384020717141444" merchant_transaction_id="fe47eb391ef98a7b4df0da0052de6d00" action="payment" currency="USD" result="failed" transaction_type="payment" transaction_status="declined" transaction_date="2017-02-07 14:14:45" errors="22" errors_meaning="(22) Card has been declined." pg="testmode"  processing_time="1.6682"'
  end

  def successful_authorize_response
    'transaction_id="7097020717141657" merchant_transaction_id="69008d37eb26df26ba1d7dcf6fbdec51" action="authorized payment" result="success" amount="10.00" currency="USD" gross="10.00" net="0.00" custom="ADDITIONAL DESCRIPTION" identifier="EGN1151306ay288" business="tech@debitway.ca" item_name="STORE PURCHASE" item_code="" quantity="1" transaction_type="authorized payment" transaction_status="pending" transaction_date="2017-02-07 14:16:59" processing_rate="0.00" discount_fee="0.00" additional_fee="0.00" first_name="JON" last_name="DOE" phone="55544433344" email="testemail@debitway.com" shipment="no" address="4444 LEVESQUE ST. APT B" city="MONTREAL" state_or_province="QC" country="CA" zip_or_postal_code="H2C1X8" shipping_address="" shipping_city="" shipping_state_or_province="" shipping_country="" shipping_zip_or_postal_code="" processing_time="1.6894"'
  end

  def failed_authorize_response
    'transaction_id="8166020717141805" merchant_transaction_id="9e1f592b612b56509ce4e736da8287e9" action="authorized payment" currency="USD" result="failed" transaction_type="authorized payment" transaction_status="declined" transaction_date="2017-02-07 14:18:06" errors="22" errors_meaning="(22) Card has been declined." pg="testmode"  processing_time="1.7368"'
  end

  def successful_capture_response
    'transaction_id="7097020717141657" action="capture" result="success" amount="10.00" currency="USD"gross="10.00" net="10.00" custom="ADDITIONAL DESCRIPTION" identifier="EGN1151306ay288" business="tech@debitway.ca" item_name="STORE PURCHASE" item_code="" quantity="1" transaction_type="capture" transaction_status="approved" transaction_date="2017-02-07 14:16:59" processing_rate="0.00" discount_fee="0.00" first_name="JON" last_name="DOE" phone="55544433344" email="testemail@debitway.com" shipment="no" shipment_info="Shipment Method:  --- Tracking #: 	--- Date:  --- Comments: " address="4444 LEVESQUE ST. APT B" city="MONTREAL" state_or_province="QC" country="CA" zip_or_postal_code="H2C1X8" shipping_address="" shipping_city="" shipping_state_or_province="" shipping_country="" shipping_zip_or_postal_code=""'
  end

  def failed_capture_response
    'transaction_id="" action="capture" result="failed" errors="60" errors_meaning="(60) The transaction_id required for the operation has not been received."'
  end

  def successful_refund_response
    'transaction_id="6923020717142034" action="refund" result="success" amount="10.00" currency="USD"gross="-10.00" net="-10.00" custom="ADDITIONAL DESCRIPTION" identifier="EGN1151306ay288" business="tech@debitway.ca" item_name="STORE PURCHASE" item_code="" quantity="1" transaction_type="refund" transaction_status="approved" transaction_date="2017-02-07 14:20:36" processing_rate="0" discount_fee="0.00" first_name="JON" last_name="DOE" phone="55544433344" email="testemail@debitway.com" shipment="no" shipment_info="" address="4444 LEVESQUE ST. APT B" city="MONTREAL" state_or_province="QC" country="CA" zip_or_postal_code="H2C1X8" shipping_address="" shipping_city="" shipping_state_or_province="" shipping_country="" shipping_zip_or_postal_code=""'
  end

  def failed_refund_response
    'transaction_id="" action="refund" result="failed" errors="60" errors_meaning="(60) The transaction_id required for the operation has not been received."'
  end

  def successful_void_response
    'transaction_id="9727020717142146" action="decline authorized payment" result="success" amount="10.00" gross="10.00" net="0.00" custom="ADDITIONAL DESCRIPTION" identifier="EGN1151306ay288" business="tech@debitway.ca" item_name="STORE PURCHASE" item_code="" quantity="1" transaction_type="decline" transaction_status="approved" transaction_date="2017-02-07 14:21:48" processing_rate="0" discount_fee="0.00" first_name="JON" last_name="DOE" phone="55544433344" email="testemail@debitway.com" shipment="no" shipment_info="" address="4444 LEVESQUE ST. APT B" city="MONTREAL" state_or_province="QC" country="CA" zip_or_postal_code="H2C1X8" shipping_address="" shipping_city="" shipping_state_or_province="" shipping_country="" shipping_zip_or_postal_code=""'
  end

  def failed_void_response
    'transaction_id="" action="decline authorized payment" result="failed" errors="60" errors_meaning="(60) The transaction_id required for the operation has not been received." customer_errors_meaning="(60) The transaction_id required for the operation has not been received."'
  end

end
