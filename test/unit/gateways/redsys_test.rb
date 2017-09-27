require 'test_helper'

class RedsysTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test
    @credentials = {
      :login      => '091952713',
      :secret_key => "qwertyasdf0123456789",
      :terminal   => '1',
    }
    @gateway = RedsysGateway.new(@credentials)
    @headers = {
      'Content-Type' => 'application/x-www-form-urlencoded'
    }

    @options = { order_id: '1001' }
  end

  def test_purchase_payload
    @gateway.expects(:ssl_post).with(RedsysGateway.test_url, purchase_request, @headers).returns(successful_purchase_response)
    @gateway.purchase(123, credit_card, :order_id => '1001')
  end

  def test_purchase_payload_with_credit_card_token
    @gateway.expects(:ssl_post).with(RedsysGateway.test_url, purchase_request_with_credit_card_token, @headers).returns(successful_purchase_response)
    @gateway.purchase(123, '77bff3a969d6f97b2ec815448cdcff453971f573', :order_id => '1001')
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    res = @gateway.purchase(123, credit_card, @options)
    assert_success res
    assert_equal "Transaction Approved", res.message
    assert_equal "1001|123|978", res.authorization
    assert_equal '1001', res.params['ds_order']
  end

  def test_successful_purchase_requesting_credit_card_token
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_credit_card_token)
    res = @gateway.purchase(123, credit_card, @options)
    assert_success res
    assert_equal "Transaction Approved", res.message
    assert_equal "141661632759|100|978", res.authorization
    assert_equal '141661632759', res.params['ds_order']
    assert_equal '77bff3a969d6f97b2ec815448cdcff453971f573', res.params['ds_merchant_identifier']
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    res = @gateway.purchase(123, credit_card, @options)
    assert_failure res
    assert_equal "Refusal with no specific reason", res.message
    assert_equal '1002', res.params['ds_order']
  end

  def test_purchase_without_order_id
    assert_raise ArgumentError do
      @gateway.purchase(123, credit_card)
    end
  end

  def test_error_purchase
    @gateway.expects(:ssl_post).returns(error_purchase_response)
    res = @gateway.purchase(123, credit_card, @options)
    assert_failure res
    assert_equal "SIS0051 ERROR", res.message
  end

  def test_refund_request
    @gateway.expects(:ssl_post).with(RedsysGateway.test_url, refund_request, @headers).returns(successful_refund_response)
    @gateway.refund(123, '1001')
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    res = @gateway.refund(123, "1001")
    assert_success res
    assert_equal "Refund / Confirmation approved", res.message
    assert_equal "1001|123|978", res.authorization
    assert_equal "1001", res.params['ds_order']
  end

  def test_error_refund
    @gateway.expects(:ssl_post).returns(error_refund_response)
    res = @gateway.refund(123, "1001")
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
    ).returns(successful_authorize_response)
    response = @gateway.authorize(123, credit_card, @options)
    assert_success response
  end

  def test_authorize_without_order_id
    assert_raise ArgumentError do
      @gateway.authorize(123, credit_card)
    end
  end

  def test_bad_order_id_format
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(123, credit_card, order_id: "Una#cce-ptable44Format")
    end.check_request do |method, endpoint, data, headers|
      assert_match(/MERCHANT_ORDER%3E\d\d\d\dUnaccept%3C/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_order_id_numeric_start_but_too_long
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(123, credit_card, order_id: "1234ThisIs]FineButTooLong")
    end.check_request do |method, endpoint, data, headers|
      assert_match(/MERCHANT_ORDER%3E1234ThisIsFi%3C/, data)
    end.respond_with(successful_authorize_response)
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
    ).returns(successful_capture_response)
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
    ).returns(successful_void_response)
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

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response).then.returns(successful_void_response)
    response = @gateway.verify(credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response).then.returns(failed_void_response)
    response = @gateway.verify(credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved", response.message
  end

  def test_unsuccessful_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.verify(credit_card, @options)
    assert_failure response
    assert_equal "SIS0093 ERROR", response.message
  end

  def test_unknown_currency
    assert_raise ArgumentError do
      @gateway.purchase(123, credit_card, @options.merge(currency: "HUH WUT"))
    end
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
    Base.mode = :production
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
    Base.mode = :production
    gw = RedsysGateway.new(
      :terminal => 1,
      :login => '1234',
      :secret_key => '12345'
    )
    assert !gw.test?
    assert_equal RedsysGateway.live_url, gw.send(:url)
  end

  def test_transcript_scrubbing
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  def test_failed_transaction_transcript_scrubbing
    assert_equal failed_transaction_post_scrubbed, @gateway.scrub(failed_transaction_pre_scrubbed)
  end

  def test_nil_cvv_transcript_scrubbing
    assert_equal nil_cvv_post_scrubbed, @gateway.scrub(nil_cvv_pre_scrubbed)
  end

  def test_empty_string_cvv_transcript_scrubbing
    assert_equal empty_string_cvv_post_scrubbed, @gateway.scrub(empty_string_cvv_pre_scrubbed)
  end

  def test_whitespace_string_cvv_transcript_scrubbing
    assert_equal whitespace_string_cvv_post_scrubbed, @gateway.scrub(whitespace_string_cvv_pre_scrubbed)
  end

  private

  # Sample response for two main types of operation,
  # one with card and another without.

  def purchase_request
    "entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E123%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E1001%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_PRODUCTDESCRIPTION%2F%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E091952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3Eb98b606a6a588d8c45c239f244160efbbe30b4a8%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E4242424242424242%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E#{(Time.now.year + 1).to_s.slice(2,2)}09%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E123%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A"
  end

  def purchase_request_with_credit_card_token
    "entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E123%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E1001%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_PRODUCTDESCRIPTION%2F%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E091952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3Ecbcc0dee5724cd3fff08bbd4371946a0599c7fb9%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_IDENTIFIER%3E77bff3a969d6f97b2ec815448cdcff453971f573%3C%2FDS_MERCHANT_IDENTIFIER%3E%0A%3C%2FDATOSENTRADA%3E%0A"
  end

  def successful_purchase_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>123</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>1001</Ds_Order><Ds_Signature>989D357BCC9EF0962A456C51422C4FAF4BF4399F</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>561350</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def successful_purchase_response_with_credit_card_token
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>141661632759</Ds_Order><Ds_Signature>C65E11D80534B432042ABAA47DCA54F5AFEC23ED</Ds_Signature><Ds_MerchantCode>327234688</Ds_MerchantCode><Ds_Terminal>2</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>341129</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_Merchant_Identifier>77bff3a969d6f97b2ec815448cdcff453971f573</Ds_Merchant_Identifier><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def failed_purchase_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>123</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>1002</Ds_Order><Ds_Signature>80D5D1BE64777946519C4E633EE5498C6187747B</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>190</Ds_Response><Ds_AuthorisationCode>561350</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def error_purchase_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0051</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>1001</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>A</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>b5cdaf0f0672be67e6c77f219b63ecbeed1ce525</DS_MERCHANT_MERCHANTSIGNATURE>\n  <DS_MERCHANT_TITULAR>Sam Lown</DS_MERCHANT_TITULAR>\n  <DS_MERCHANT_PAN>4792587766554414</DS_MERCHANT_PAN>\n  <DS_MERCHANT_EXPIRYDATE>1510</DS_MERCHANT_EXPIRYDATE>\n  <DS_MERCHANT_CVV2>737</DS_MERCHANT_CVV2>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>\n"
  end

  def successful_authorize_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>141278659571</Ds_Order><Ds_Signature>c0d1d069d7ee1443e356927818b2abe281d077e5</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>385661</Ds_AuthorisationCode><Ds_TransactionType>1</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def failed_authorize_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0093</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>100</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>141278225678</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>1</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>1c34699589507802f800b929ea314dc143b0b8a5</DS_MERCHANT_MERCHANTSIGNATURE>\n  <DS_MERCHANT_TITULAR>Longbob Longsen</DS_MERCHANT_TITULAR>\n  <DS_MERCHANT_PAN>4242424242424242</DS_MERCHANT_PAN>\n  <DS_MERCHANT_EXPIRYDATE>1509</DS_MERCHANT_EXPIRYDATE>\n  <DS_MERCHANT_CVV2>123</DS_MERCHANT_CVV2>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>"
  end

  def refund_request
    'entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E123%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E1001%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3E3%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_PRODUCTDESCRIPTION%2F%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E091952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3Eba048e120a510e3ef4382bc65e8f29bf132d8ee7%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A%3C%2FDATOSENTRADA%3E%0A'
  end

  def successful_refund_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>123</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>1001</Ds_Order><Ds_Signature>4D7DDF84BFABA0D968D4021DB48ECF72A73DDF7D</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0900</Ds_Response><Ds_AuthorisationCode>561664</Ds_AuthorisationCode><Ds_TransactionType>3</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>\n"
  end

  def error_refund_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0057</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>1001</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>3</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>9e12f1607147b4611bfdbff80aa143241c27f935</DS_MERCHANT_MERCHANTSIGNATURE>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>\n"
  end

  def successful_void_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>141278288802</Ds_Order><Ds_Signature>A29ED7C7E46ED8F4A5F4F05ED7BA0BF83149E062</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0400</Ds_Response><Ds_AuthorisationCode>385387</Ds_AuthorisationCode><Ds_TransactionType>9</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def failed_void_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0222</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>100</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>141278298713</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>9</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>ead33f15453316e86dfc51642e400e2467fe71bb</DS_MERCHANT_MERCHANTSIGNATURE>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>"
  end

  def successful_capture_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>141278546960</Ds_Order><Ds_Signature>D138D4178F28BC71661B8015CFBB2656AFF8F722</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0900</Ds_Response><Ds_AuthorisationCode>385584</Ds_AuthorisationCode><Ds_TransactionType>2</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
  entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E135214014098%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E39589b03cdd3c525885cdb3b3761e2fb7a8be9ee%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E4548812049400004%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1309%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E123%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A
  <?xml version='1.0' encoding="ISO-8859-1" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>135214014098</Ds_Order><Ds_Signature>97FBF7E648015AC8AFCA107CD67A1F600FBE9611</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>701841</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
  entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E135214014098%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E39589b03cdd3c525885cdb3b3761e2fb7a8be9ee%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E[FILTERED]%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1309%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E[FILTERED]%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A
  <?xml version='1.0' encoding="ISO-8859-1" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>135214014098</Ds_Order><Ds_Signature>97FBF7E648015AC8AFCA107CD67A1F600FBE9611</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>701841</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>
    POST_SCRUBBED
  end

  def failed_transaction_pre_scrubbed
    %q(
POST /sis/operaciones HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sis-t.redsys.es:25443\r\nContent-Length: 969\r\n\r\n"<- "entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E144009991943%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_PRODUCTDESCRIPTION%3ETest+Description%3C%2FDS_MERCHANT_PRODUCTDESCRIPTION%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E2bf324cba60dcdd9e2c1bc8de2458a6ed168778f%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E4548812049400004%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1609%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E123%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A
<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0018</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT></DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>144009991943</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>A</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_PRODUCTDESCRIPTION>Test Description</DS_MERCHANT_PRODUCTDESCRIPTION>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>2bf324cba60dcdd9e2c1bc8de2458a6ed168778f</DS_MERCHANT_MERCHANTSIGNATURE>\n  <DS_MERCHANT_TITULAR>Longbob Longsen</DS_MERCHANT_TITULAR>\n  <DS_MERCHANT_PAN>4548812049400004</DS_MERCHANT_PAN>\n  <DS_MERCHANT_EXPIRYDATE>1609</DS_MERCHANT_EXPIRYDATE>\n  <DS_MERCHANT_CVV2>123</DS_MERCHANT_CVV2>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>\n
    )
  end

  def failed_transaction_post_scrubbed
    %q(
POST /sis/operaciones HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sis-t.redsys.es:25443\r\nContent-Length: 969\r\n\r\n"<- "entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E144009991943%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_PRODUCTDESCRIPTION%3ETest+Description%3C%2FDS_MERCHANT_PRODUCTDESCRIPTION%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E2bf324cba60dcdd9e2c1bc8de2458a6ed168778f%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E[FILTERED]%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1609%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E[FILTERED]%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A
<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0018</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT></DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>144009991943</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>A</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_PRODUCTDESCRIPTION>Test Description</DS_MERCHANT_PRODUCTDESCRIPTION>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>2bf324cba60dcdd9e2c1bc8de2458a6ed168778f</DS_MERCHANT_MERCHANTSIGNATURE>\n  <DS_MERCHANT_TITULAR>Longbob Longsen</DS_MERCHANT_TITULAR>\n  <DS_MERCHANT_PAN>[FILTERED]</DS_MERCHANT_PAN>\n  <DS_MERCHANT_EXPIRYDATE>1609</DS_MERCHANT_EXPIRYDATE>\n  <DS_MERCHANT_CVV2>[FILTERED]</DS_MERCHANT_CVV2>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>\n
    )
  end

  def nil_cvv_pre_scrubbed
    <<-PRE_SCRUBBED
  entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E135214014098%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E39589b03cdd3c525885cdb3b3761e2fb7a8be9ee%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E4548812049400004%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1309%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%2F%3E%0A%3C%2FDATOSENTRADA%3E%0A
  <?xml version='1.0' encoding="ISO-8859-1" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>135214014098</Ds_Order><Ds_Signature>97FBF7E648015AC8AFCA107CD67A1F600FBE9611</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>701841</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>
    PRE_SCRUBBED
  end

  def nil_cvv_post_scrubbed
    <<-POST_SCRUBBED
  entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E135214014098%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E39589b03cdd3c525885cdb3b3761e2fb7a8be9ee%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E[FILTERED]%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1309%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2[BLANK]DATOSENTRADA%3E%0A
  <?xml version='1.0' encoding="ISO-8859-1" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>135214014098</Ds_Order><Ds_Signature>97FBF7E648015AC8AFCA107CD67A1F600FBE9611</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>701841</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>
    POST_SCRUBBED
  end

  def empty_string_cvv_pre_scrubbed
    <<-PRE_SCRUBBED
  entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E135214014098%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E39589b03cdd3c525885cdb3b3761e2fb7a8be9ee%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E4548812049400004%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1309%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A
  <?xml version='1.0' encoding="ISO-8859-1" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>135214014098</Ds_Order><Ds_Signature>97FBF7E648015AC8AFCA107CD67A1F600FBE9611</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>701841</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>
    PRE_SCRUBBED
  end

  def empty_string_cvv_post_scrubbed
    <<-PRE_SCRUBBED
  entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E135214014098%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E39589b03cdd3c525885cdb3b3761e2fb7a8be9ee%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E[FILTERED]%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1309%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E[BLANK]%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A
  <?xml version='1.0' encoding="ISO-8859-1" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>135214014098</Ds_Order><Ds_Signature>97FBF7E648015AC8AFCA107CD67A1F600FBE9611</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>701841</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>
    PRE_SCRUBBED
  end

  def whitespace_string_cvv_pre_scrubbed
    <<-PRE_SCRUBBED
  entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E135214014098%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E39589b03cdd3c525885cdb3b3761e2fb7a8be9ee%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E4548812049400004%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1309%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E+++%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A
  <?xml version='1.0' encoding="ISO-8859-1" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>135214014098</Ds_Order><Ds_Signature>97FBF7E648015AC8AFCA107CD67A1F600FBE9611</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>701841</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>
  PRE_SCRUBBED
  end

  def whitespace_string_cvv_post_scrubbed
    <<-PRE_SCRUBBED
  entrada=%3CDATOSENTRADA%3E%0A++%3CDS_Version%3E0.1%3C%2FDS_Version%3E%0A++%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%0A++%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%0A++%3CDS_MERCHANT_ORDER%3E135214014098%3C%2FDS_MERCHANT_ORDER%3E%0A++%3CDS_MERCHANT_TRANSACTIONTYPE%3EA%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%0A++%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%0A++%3CDS_MERCHANT_MERCHANTCODE%3E91952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%0A++%3CDS_MERCHANT_MERCHANTSIGNATURE%3E39589b03cdd3c525885cdb3b3761e2fb7a8be9ee%3C%2FDS_MERCHANT_MERCHANTSIGNATURE%3E%0A++%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%0A++%3CDS_MERCHANT_PAN%3E[FILTERED]%3C%2FDS_MERCHANT_PAN%3E%0A++%3CDS_MERCHANT_EXPIRYDATE%3E1309%3C%2FDS_MERCHANT_EXPIRYDATE%3E%0A++%3CDS_MERCHANT_CVV2%3E[BLANK]%3C%2FDS_MERCHANT_CVV2%3E%0A%3C%2FDATOSENTRADA%3E%0A
  <?xml version='1.0' encoding="ISO-8859-1" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>135214014098</Ds_Order><Ds_Signature>97FBF7E648015AC8AFCA107CD67A1F600FBE9611</Ds_Signature><Ds_MerchantCode>91952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>701841</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>
  PRE_SCRUBBED
  end
end
