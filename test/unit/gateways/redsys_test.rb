require 'test_helper'

class RedsysTest < Test::Unit::TestCase

  def setup
    Base.gateway_mode = :test
    @credentials = {
      :login      => '091952713',
      :secret_key => "qwertyasdf0123456789",
      :terminal   => '1',
    }
    @gateway = RedsysGateway.new(@credentials)
    @headers = {
      'Content-Type' => 'application/x-www-form-urlencoded'
    }
  end

  def test_purchase_payload
    @gateway.expects(:ssl_post).with(RedsysGateway.test_url, purchase_request, @headers).returns(successful_purchase_response)
    @gateway.purchase(123, credit_card, :order_id => '1001')
  end

  def test_successful_purchase
    order_id = '1001'
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    res = @gateway.purchase(123, credit_card, :order_id => order_id)
    assert_success res
    assert_equal "Transaction Approved", res.message
    assert_equal "1001|123|978", res.authorization
    assert_equal order_id, res.params['ds_order']
  end

  def test_failed_purchase
    order_id = '1002'
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    res = @gateway.purchase(123, credit_card, :order_id => order_id)
    assert_failure res
    assert_equal "Refusal with no specific reason", res.message
    assert_equal order_id, res.params['ds_order']
  end

  def test_purchase_without_order_id
    assert_raise ArgumentError do
      @gateway.purchase(123, credit_card)
    end
  end

  def test_error_purchase
    order_id = '1001' # duplicate!
    @gateway.expects(:ssl_post).returns(error_purchase_response)
    res = @gateway.purchase(123, credit_card, :order_id => order_id)
    assert_failure res
    assert_equal "SIS0051 ERROR", res.message
  end

  def test_refund_request
    @gateway.expects(:ssl_post).with(RedsysGateway.test_url, refund_request, @headers).returns(successful_refund_response)
    @gateway.refund(123, '1001')
  end

  def test_successful_refund
    order_id = '1001'
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    res = @gateway.refund(123, order_id)
    assert_success res
    assert_equal "Refund / Confirmation approved", res.message
    assert_equal "1001|123|978", res.authorization
    assert_equal order_id, res.params['ds_order']
  end

  def test_error_refund
    order_id = '1001' # duplicate!
    @gateway.expects(:ssl_post).returns(error_refund_response)
    res = @gateway.refund(123, order_id)
    assert_failure res
    assert_equal "SIS0057 ERROR", res.message
  end

  # Remaining methods a pretty much the same, so we just test that
  # the commit method gets called.

  def test_authorize
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes(CGI.escape("<DS_MERCHANT_TRANSACTIONTYPE>1</DS_MERCHANT_TRANSACTIONTYPE>")),
        includes(CGI.escape("<DS_MERCHANT_PAN>4242424242424242</DS_MERCHANT_PAN>")),
        includes(CGI.escape("<DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>"))
      ),
      anything
    ).returns(successful_purchase_response)
    @gateway.authorize(123, credit_card, :order_id => '1001')
  end

  def test_authorize_without_order_id
    assert_raise ArgumentError do
      @gateway.authorize(123, credit_card)
    end
  end

  def test_bad_order_id_format
    assert_raise ArgumentError do
      @gateway.authorize(123, credit_card, :order_id => "a")
    end
  end

  def test_capture
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes(CGI.escape("<DS_MERCHANT_TRANSACTIONTYPE>2</DS_MERCHANT_TRANSACTIONTYPE>")),
        includes(CGI.escape("<DS_MERCHANT_ORDER>1001</DS_MERCHANT_ORDER>")),
        includes(CGI.escape("<DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>"))
      ),
      anything
    ).returns(successful_purchase_response)
    @gateway.capture(123, '1001')
  end

  def test_void
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes(CGI.escape("<DS_MERCHANT_TRANSACTIONTYPE>9</DS_MERCHANT_TRANSACTIONTYPE>")),
        includes(CGI.escape("<DS_MERCHANT_ORDER>1001</DS_MERCHANT_ORDER>")),
        includes(CGI.escape("<DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>")),
        includes(CGI.escape("<DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>"))
      ),
      anything
    ).returns(successful_purchase_response)
    @gateway.void('1001|123|978')
  end

  def test_override_currency
    @gateway.expects(:ssl_post).with(
      anything,
      includes(CGI.escape("<DS_MERCHANT_CURRENCY>840</DS_MERCHANT_CURRENCY>")),
      anything
    ).returns(successful_purchase_response)
    @gateway.authorize(123, credit_card, :order_id => '1001', :currency => 'USD')
  end

  def test_default_currency
    assert_equal 'EUR', RedsysGateway.default_currency
  end

  def test_supported_countries
    assert_equal ['ES'], RedsysGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal [:visa, :master, :american_express, :jcb, :diners_club], RedsysGateway.supported_cardtypes
  end

  def test_using_test_mode
    assert @gateway.test?
    assert_equal @gateway.send(:url), RedsysGateway.test_url
  end

  def test_overriding_options
    Base.gateway_mode = :production
    gw = RedsysGateway.new(
      :terminal => 1,
      :login => '1234',
      :secret_key => '12345',
      :test => true
    )
    assert gw.test?
    assert_equal RedsysGateway.test_url, gw.send(:url)
  end

  def test_production_mode
    Base.gateway_mode = :production
    gw = RedsysGateway.new(
      :terminal => 1,
      :login => '1234',
      :secret_key => '12345'
    )
    assert !gw.test?
    assert_equal RedsysGateway.live_url, gw.send(:url)
  end

  private

  # Sample response for two main types of operation,
  # one with card and another without.

  def purchase_request
    "entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E123%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E1001%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E091952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3Eb98b606a6a588d8c45c239f244160efbbe30b4a8%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E4242424242424242%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E#{(Time.now.year + 1).to_s.slice(2,2)}09%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E123%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A"
  end

  def successful_purchase_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>123</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>1001</Ds_Order><Ds_Signature>989D357BCC9EF0962A456C51422C4FAF4BF4399F</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>561350</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def failed_purchase_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>123</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>1002</Ds_Order><Ds_Signature>80D5D1BE64777946519C4E633EE5498C6187747B</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>190</Ds_Response><Ds_AuthorisationCode>561350</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def error_purchase_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0051</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>1001</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>A</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>b5cdaf0f0672be67e6c77f219b63ecbeed1ce525</DS_MERCHANT_MERCHANTSIGNATURE>\n  <DS_MERCHANT_TITULAR>Sam Lown</DS_MERCHANT_TITULAR>\n  <DS_MERCHANT_PAN>4792587766554414</DS_MERCHANT_PAN>\n  <DS_MERCHANT_EXPIRYDATE>1510</DS_MERCHANT_EXPIRYDATE>\n  <DS_MERCHANT_CVV2>737</DS_MERCHANT_CVV2>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>\n"
  end

  def refund_request
    'entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E123%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E1001%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3E3%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E091952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3Eba048e120a510e3ef4382bc65e8f29bf132d8ee7%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A%3C%2FDATOSENTRADA%3E%0A'
  end

  def successful_refund_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>123</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>1001</Ds_Order><Ds_Signature>4D7DDF84BFABA0D968D4021DB48ECF72A73DDF7D</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0900</Ds_Response><Ds_AuthorisationCode>561664</Ds_AuthorisationCode><Ds_TransactionType>3</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>\n"
  end

  def error_refund_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0057</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>1001</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>3</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>9e12f1607147b4611bfdbff80aa143241c27f935</DS_MERCHANT_MERCHANTSIGNATURE>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>\n"
  end

end
