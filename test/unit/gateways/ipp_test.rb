require 'test_helper'

class IppTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = IppGateway.new(
      username: 'username',
      password: 'password',
    )

    @amount = 100
    @credit_card = credit_card
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: 1)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{<SubmitSinglePayment }, data)
      assert_match(%r{<UserName>username<}, data)
      assert_match(%r{<Password>password<}, data)
      assert_match(%r{<CustRef>1<}, data)
      assert_match(%r{<Amount>100<}, data)
      assert_match(%r{<TrnType>1<}, data)
      assert_match(%r{<CardNumber>#{@credit_card.number}<}, data)
      assert_match(%r{<ExpM>#{"%02d" % @credit_card.month}<}, data)
      assert_match(%r{<ExpY>#{@credit_card.year}<}, data)
      assert_match(%r{<CVN>#{@credit_card.verification_value}<}, data)
      assert_match(%r{<CardHolderName>#{@credit_card.name}<}, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "89435577", response.authorization
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Do Not Honour", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert_equal "", response.authorization
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, order_id: 1)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{<SubmitSinglePayment }, data)
      assert_match(%r{<CustRef>1<}, data)
      assert_match(%r{<TrnType>2<}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "89435583", response.authorization
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount, "receipt")
    end.check_request do |endpoint, data, headers|
      assert_match(%r{<SubmitSingleCapture }, data)
      assert_match(%r{<Receipt>receipt<}, data)
      assert_match(%r{<Amount>100<}, data)
    end.respond_with(successful_capture_response)

    assert_success response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, "receipt")
    end.check_request do |endpoint, data, headers|
      assert_match(%r{<SubmitSingleRefund }, data)
      assert_match(%r{<Receipt>receipt<}, data)
      assert_match(%r{<Amount>100<}, data)
    end.respond_with(successful_refund_response)

    assert_success response
  end

  private

  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSinglePaymentResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSinglePaymentResult>&lt;Response&gt;
  &lt;ResponseCode&gt;0&lt;/ResponseCode&gt;
  &lt;Timestamp&gt;20-Dec-2014 04:07:39&lt;/Timestamp&gt;
  &lt;Receipt&gt;89435577&lt;/Receipt&gt;
  &lt;SettlementDate&gt;22-Dec-2014&lt;/SettlementDate&gt;
  &lt;DeclinedCode&gt;&lt;/DeclinedCode&gt;
  &lt;DeclinedMessage&gt;&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSinglePaymentResult></SubmitSinglePaymentResponse></soap:Body></soap:Envelope>
    XML
  end

  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSinglePaymentResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSinglePaymentResult>&lt;Response&gt;
  &lt;ResponseCode&gt;1&lt;/ResponseCode&gt;
  &lt;Timestamp&gt;20-Dec-2014 04:14:56&lt;/Timestamp&gt;
  &lt;Receipt&gt;&lt;/Receipt&gt;
  &lt;SettlementDate&gt;22-Dec-2014&lt;/SettlementDate&gt;
  &lt;DeclinedCode&gt;05&lt;/DeclinedCode&gt;
  &lt;DeclinedMessage&gt;Do Not Honour&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSinglePaymentResult></SubmitSinglePaymentResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_authorize_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSinglePaymentResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSinglePaymentResult>&lt;Response&gt;
  &lt;ResponseCode&gt;0&lt;/ResponseCode&gt;
  &lt;Timestamp&gt;20-Dec-2014 04:18:13&lt;/Timestamp&gt;
  &lt;Receipt&gt;89435583&lt;/Receipt&gt;
  &lt;SettlementDate&gt;22-Dec-2014&lt;/SettlementDate&gt;
  &lt;DeclinedCode&gt;&lt;/DeclinedCode&gt;
  &lt;DeclinedMessage&gt;&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSinglePaymentResult></SubmitSinglePaymentResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_capture_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSingleCaptureResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSingleCaptureResult>&lt;Response&gt;
  &lt;ResponseCode&gt;0&lt;/ResponseCode&gt;
  &lt;Timestamp&gt;20-Dec-2014 04:18:15&lt;/Timestamp&gt;
  &lt;Receipt&gt;89435584&lt;/Receipt&gt;
  &lt;SettlementDate&gt;22-Dec-2014&lt;/SettlementDate&gt;
  &lt;DeclinedCode&gt;&lt;/DeclinedCode&gt;
  &lt;DeclinedMessage&gt;&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSingleCaptureResult></SubmitSingleCaptureResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_refund_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSingleRefundResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSingleRefundResult>&lt;Response&gt;
  &lt;ResponseCode&gt;0&lt;/ResponseCode&gt;
  &lt;Timestamp&gt;20-Dec-2014 04:24:51&lt;/Timestamp&gt;
  &lt;Receipt&gt;89435596&lt;/Receipt&gt;
  &lt;SettlementDate&gt;22-Dec-2014&lt;/SettlementDate&gt;
  &lt;DeclinedCode&gt;&lt;/DeclinedCode&gt;
  &lt;DeclinedMessage&gt;&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSingleRefundResult></SubmitSingleRefundResponse></soap:Body></soap:Envelope>
    XML
  end
end
