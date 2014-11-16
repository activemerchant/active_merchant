require 'test_helper'

class IppTest < Test::Unit::TestCase
  def setup
    @gateway = IppGateway.new(
      login: 'login',
      password: 'password',
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.test?
    assert_success response
    assert_equal '10001197', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.test?
    assert_failure response
    assert_equal 'Do Not Honour', response.message
  end

  private

  def successful_purchase_response
    <<-EOF
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSinglePaymentResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSinglePaymentResult>&lt;Response&gt;
	&lt;ResponseCode&gt;0&lt;/ResponseCode&gt;
	&lt;Timestamp&gt;23-Sep-2011 15:33:25&lt;/Timestamp&gt;
	&lt;Receipt&gt;10001197&lt;/Receipt&gt;
	&lt;SettlementDate&gt;23-Sep-2011&lt;/SettlementDate&gt;
	&lt;DeclinedCode&gt;&lt;/DeclinedCode&gt;
	&lt;DeclinedMessage&gt;&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSinglePaymentResult></SubmitSinglePaymentResponse></soap:Body></soap:Envelope>
    EOF
  end

  def failed_purchase_response
    <<-EOF
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSinglePaymentResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSinglePaymentResult>&lt;Response&gt;
	&lt;ResponseCode&gt;1&lt;/ResponseCode&gt;
	&lt;Timestamp&gt;23-Sep-2011 15:33:25&lt;/Timestamp&gt;
	&lt;Receipt&gt;10001197&lt;/Receipt&gt;
	&lt;SettlementDate&gt;23-Sep-2011&lt;/SettlementDate&gt;
	&lt;DeclinedCode&gt;5&lt;/DeclinedCode&gt;
	&lt;DeclinedMessage&gt;Do Not Honour&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSinglePaymentResult></SubmitSinglePaymentResponse></soap:Body></soap:Envelope>
    EOF
  end
end
