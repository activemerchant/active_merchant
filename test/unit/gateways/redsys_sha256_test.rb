require 'test_helper'

class RedsysSHA256Test < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test
    @credentials = {
      login: '091952713',
      secret_key: 'QIK77hYl6UFcoCYFKcj+ZjJg8Q6I93Dx',
      signature_algorithm: 'sha256'
    }
    @gateway = RedsysGateway.new(@credentials)
    @credit_card = credit_card('4548812049400004')
    @threeds2_credit_card = credit_card('4918019199883839')
    @headers = {
      'Content-Type' => 'application/x-www-form-urlencoded'
    }
    @options = {}
  end

  def test_purchase_payload
    @credit_card.month = 9
    @credit_card.year = 2017
    @gateway.expects(:ssl_post).with(RedsysGateway.test_url, purchase_request, @headers).returns(successful_purchase_response)
    @gateway.purchase(100, @credit_card, order_id: '144742736014')
  end

  def test_purchase_payload_with_credit_card_token
    @gateway.expects(:ssl_post).with(RedsysGateway.test_url, purchase_request_with_credit_card_token, @headers).returns(successful_purchase_response)
    @gateway.purchase(100, '3126bb8b80a79e66eb1ecc39e305288b60075f86', order_id: '144742884282')
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    res = @gateway.purchase(100, credit_card, order_id: '144742736014')
    assert_success res
    assert_equal 'Transaction Approved', res.message
    assert_equal '144742736014|100|978', res.authorization
    assert_equal '144742736014', res.params['ds_order']
  end

  # This one is being werid...
  def test_successful_purchase_requesting_credit_card_token
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_credit_card_token)
    res = @gateway.purchase(100, 'e55e1d0ef338e281baf1d0b5b68be433260ddea0', order_id: '144742955848')
    assert_success res
    assert_equal 'Transaction Approved', res.message
    assert_equal '144742955848|100|978', res.authorization
    assert_equal '144742955848', res.params['ds_order']
    assert_equal 'e55e1d0ef338e281baf1d0b5b68be433260ddea0', res.params['ds_merchant_identifier']
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    res = @gateway.purchase(100, credit_card, order_id: '144743314659')
    assert_failure res
    assert_equal 'SIS0093 ERROR', res.message
  end

  def test_purchase_without_order_id
    assert_raise ArgumentError do
      @gateway.purchase(100, credit_card)
    end
  end

  def test_error_purchase
    @gateway.expects(:ssl_post).returns(error_purchase_response)
    res = @gateway.purchase(100, credit_card, order_id: '123')
    assert_failure res
    assert_equal 'SIS0051 ERROR', res.message
  end

  def test_refund_request
    @gateway.expects(:ssl_post).with(RedsysGateway.test_url, refund_request, @headers).returns(successful_refund_response)
    @gateway.refund(100, '144743427234')
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    res = @gateway.refund(100, '1001')
    assert_success res
    assert_equal 'Refund / Confirmation approved', res.message
    assert_equal '144743427234|100|978', res.authorization
    assert_equal '144743427234', res.params['ds_order']
  end

  def test_error_refund
    @gateway.expects(:ssl_post).returns(error_refund_response)
    res = @gateway.refund(100, '1001')
    assert_failure res
    assert_equal 'SIS0057 ERROR', res.message
  end

  # Remaining methods a pretty much the same, so we just test that
  # the commit method gets called.

  def test_authorize
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes(CGI.escape('<DS_MERCHANT_TRANSACTIONTYPE>1</DS_MERCHANT_TRANSACTIONTYPE>')),
        includes(CGI.escape('<DS_MERCHANT_PAN>4242424242424242</DS_MERCHANT_PAN>')),
        includes(CGI.escape('<DS_MERCHANT_AMOUNT>100</DS_MERCHANT_AMOUNT>'))
      ),
      anything
    ).returns(successful_authorize_response)
    response = @gateway.authorize(100, credit_card, order_id: '144743367273')
    assert_success response
  end

  def test_authorize_without_order_id
    assert_raise ArgumentError do
      @gateway.authorize(100, credit_card)
    end
  end

  def test_successful_authorize_with_3ds
    @gateway.expects(:ssl_post).returns(successful_authorize_with_3ds_response)
    response = @gateway.authorize(100, credit_card, { execute_threed: true, order_id: '156270437866' })
    assert response.test?
    assert response.params['ds_emv3ds']
    assert_equal response.message, 'CardConfiguration'
    assert_equal response.authorization, '156270437866||'
  end

  def test_successful_purchase_with_3ds
    @gateway.expects(:ssl_post).returns(successful_authorize_with_3ds_response)
    response = @gateway.purchase(100, credit_card, { execute_threed: true, order_id: '156270437866' })
    assert response.test?
    assert response.params['ds_emv3ds']
    assert_equal response.message, 'CardConfiguration'
    assert_equal response.authorization, '156270437866||'
  end

  def test_successful_purchase_with_3ds2
    @gateway.expects(:ssl_post).returns(successful_authorize_with_3ds_response)
    response = @gateway.purchase(100, @threeds2_credit_card, { execute_threed: true, order_id: '156270437866' })
    assert response.test?
    assert response.params['ds_emv3ds']
    assert_equal response.message, 'CardConfiguration'
    assert_equal response.authorization, '156270437866||'
  end

  def test_successful_purchase_with_3ds2_and_mit_exemption
    @gateway.expects(:ssl_post).returns(successful_purchase_with_3ds2_and_mit_exemption_response)
    response = @gateway.purchase(100, @threeds2_credit_card, { execute_threed: true, order_id: '161608782525', sca_exemption: 'MIT', sca_exemption_direct_payment_enabled: true })
    assert response.test?
    assert response.params['ds_emv3ds']

    assert_equal response.message, 'CardConfiguration'
    assert_equal response.authorization, '161608782525||'

    assert response.params['ds_card_psd2']
    assert_equal '2.1.0', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
    assert_equal 'Y', response.params['ds_card_psd2']
    assert_equal 'CardConfiguration', response.message
  end

  def test_3ds_data_passed
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, credit_card, { execute_threed: true, order_id: '156270437866', terminal: 12, sca_exemption: 'LWV' })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/iniciaPeticion/, data)
      assert_match(/<DS_MERCHANT_TERMINAL>12<\/DS_MERCHANT_TERMINAL>/, data)
      assert_match(/\"threeDSInfo\":\"CardData\"/, data)

      # as per docs on Inicia Peticion Y must be passed
      assert_match(/<DS_MERCHANT_EXCEP_SCA>Y<\/DS_MERCHANT_EXCEP_SCA>/, data)
    end.respond_with(successful_authorize_with_3ds_response)
  end

  def test_3ds_data_with_special_characters_properly_escaped
    @credit_card.first_name = 'Julián'
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, @credit_card, { execute_threed: true, order_id: '156270437866', terminal: 12, sca_exemption: 'LWV', description: 'esta es la descripción' })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/iniciaPeticion/, data)
      assert_match(/<DS_MERCHANT_TERMINAL>12<\/DS_MERCHANT_TERMINAL>/, data)
      assert_match(/\"threeDSInfo\":\"CardData\"/, data)

      # as per docs on Inicia Peticion Y must be passed
      assert_match(/<DS_MERCHANT_EXCEP_SCA>Y<\/DS_MERCHANT_EXCEP_SCA>/, data)
      assert_match(/Juli%C3%A1n/, data)
      assert_match(/descripci%C3%B3n/, data)
    end.respond_with(successful_authorize_with_3ds_response)
  end

  def test_3ds1_data_passed_as_mpi
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, credit_card, { order_id: '156270437866', description: 'esta es la descripción', three_d_secure: { version: '1.0.2', xid: 'xid', ds_transaction_id: 'ds_transaction_id', cavv: 'cavv', eci: '02' } })
    end.check_request do |_method, _endpoint, encdata, _headers|
      data = CGI.unescape(encdata)
      assert_match(/<DS_MERCHANT_MPIEXTERNAL>/, data)
      assert_match(%r("TXID":"xid"), data)
      assert_match(%r("CAVV":"cavv"), data)
      assert_match(%r("ECI":"02"), data)

      assert_not_match(%r("authenticacionMethod"), data)
      assert_not_match(%r("authenticacionType"), data)
      assert_not_match(%r("authenticacionFlow"), data)

      assert_not_match(%r("protocolVersion":"2.1.0"), data)
      assert_match(/descripción/, data)
    end.respond_with(successful_authorize_with_3ds_response)
  end

  def test_3ds2_data_passed_as_mpi
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, credit_card, { order_id: '156270437866', description: 'esta es la descripción', three_d_secure: { version: '2.1.0', three_ds_server_trans_id: 'three_ds_server_trans_id', ds_transaction_id: 'ds_transaction_id', cavv: 'cavv', eci: '02' } })
    end.check_request do |_method, _endpoint, encdata, _headers|
      data = CGI.unescape(encdata)
      assert_match(/<DS_MERCHANT_MPIEXTERNAL>/, data)
      assert_match(%r("threeDSServerTransID":"three_ds_server_trans_id"), data)
      assert_match(%r("dsTransID":"ds_transaction_id"), data)
      assert_match(%r("authenticacionValue":"cavv"), data)
      assert_match(%r("Eci":"02"), data)

      assert_not_match(%r("authenticacionMethod"), data)
      assert_not_match(%r("authenticacionType"), data)
      assert_not_match(%r("authenticacionFlow"), data)

      assert_match(%r("protocolVersion":"2.1.0"), data)
      assert_match(/descripción/, data)
    end.respond_with(successful_authorize_with_3ds_response)
  end

  def test_3ds2_data_passed_as_mpi_with_optional_values
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, credit_card, { order_id: '156270437866', description: 'esta es la descripción', three_d_secure: { version: '2.1.0', three_ds_server_trans_id: 'three_ds_server_trans_id', ds_transaction_id: 'ds_transaction_id', cavv: 'cavv', eci: '02' },
        authentication_method: '01',
        authentication_type: 'anything',
        authentication_flow: 'F' })
    end.check_request do |_method, _endpoint, encdata, _headers|
      data = CGI.unescape(encdata)
      assert_match(/<DS_MERCHANT_MPIEXTERNAL>/, data)
      assert_match(%r("threeDSServerTransID":"three_ds_server_trans_id"), data)
      assert_match(%r("dsTransID":"ds_transaction_id"), data)
      assert_match(%r("authenticacionValue":"cavv"), data)
      assert_match(%r("Eci":"02"), data)

      assert_match(%r("authenticacionMethod":"01"), data)
      assert_match(%r("authenticacionType":"anything"), data)
      assert_match(%r("authenticacionFlow":"F"), data)

      assert_match(%r("protocolVersion":"2.1.0"), data)
      assert_match(/descripción/, data)
    end.respond_with(successful_authorize_with_3ds_response)
  end

  def test_3ds2_data_as_mpi_with_special_characters_properly_escaped
    @credit_card.first_name = 'Julián'
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, @credit_card, { order_id: '156270437866', terminal: 12, description: 'esta es la descripción', three_d_secure: { version: '2.1.0', xid: 'xid', ds_transaction_id: 'ds_transaction_id', cavv: 'cavv' } })
    end.check_request do |_method, _endpoint, encdata, _headers|
      assert_match(/Juli%C3%A1n/, encdata)
      assert_match(%r(descripci%C3%B3n), encdata)
    end.respond_with(successful_authorize_with_3ds_response)
  end

  def test_mit_exemption_sets_direct_payment
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(100, @threeds2_credit_card, { order_id: '161608782525', terminal: 12, sca_exemption: 'MIT' })
    end.check_request do |_method, _endpoint, encdata, _headers|
      assert_match(/<DS_MERCHANT_DIRECTPAYMENT>true/, encdata)
    end.respond_with(successful_non_3ds_purchase_with_mit_exemption_response)
  end

  def test_mit_exemption_hits_webservice_endpoint
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(100, @threeds2_credit_card, { order_id: '161608782525', terminal: 12, sca_exemption: 'MIT' })
    end.check_request do |_method, endpoint, _encdata, _headers|
      assert_match(/\/sis\/services\/SerClsWSEntradaV2/, endpoint)
    end.respond_with(successful_non_3ds_purchase_with_mit_exemption_response)
  end

  def test_webservice_endpoint_override_hits_webservice_endpoint
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, @credit_card, { order_id: '156270437866', use_webservice_endpoint: true })
    end.check_request do |_method, endpoint, _encdata, _headers|
      assert_match(/\/sis\/services\/SerClsWSEntradaV2/, endpoint)
    end.respond_with(successful_non_3ds_purchase_with_mit_exemption_response)
  end

  def test_webservice_endpoint_requests_escapes_special_characters_in_card_name_and_description
    @credit_card.first_name = 'Julián'
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, @credit_card, { order_id: '156270437866', description: 'esta es la descripción', use_webservice_endpoint: true })
    end.check_request do |_method, _endpoint, encdata, _headers|
      assert_match(/Juli%C3%A1n/, encdata)
      assert_match(%r(descripci%C3%B3n), encdata)
    end.respond_with(successful_non_3ds_purchase_with_mit_exemption_response)
  end

  def test_moto_flag_passed
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, credit_card, { order_id: '156270437866', moto: true, metadata: { manual_entry: true } })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/DS_MERCHANT_DIRECTPAYMENT%3Emoto%3C%2FDS_MERCHANT_DIRECTPAYMENT/, data)
    end.respond_with(successful_authorize_with_3ds_response)
  end

  def test_moto_flag_not_passed_if_not_explicitly_requested
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, credit_card, { order_id: '156270437866', metadata: { manual_entry: true } })
    end.check_request do |_method, _endpoint, data, _headers|
      refute_match(/DS_MERCHANT_DIRECTPAYMENT%3Emoto%3C%2FDS_MERCHANT_DIRECTPAYMENT/, data)
    end.respond_with(successful_authorize_with_3ds_response)
  end

  def test_bad_order_id_format
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, credit_card, order_id: 'Una#cce-ptable44Format')
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/MERCHANT_ORDER%3E\d\d\d\dUnaccept%3C/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_order_id_numeric_start_but_too_long
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, credit_card, order_id: '1234ThisIs]FineButTooLong')
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/MERCHANT_ORDER%3E1234ThisIsFi%3C/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_capture
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes(CGI.escape('<DS_MERCHANT_TRANSACTIONTYPE>2</DS_MERCHANT_TRANSACTIONTYPE>')),
        includes(CGI.escape('<DS_MERCHANT_ORDER>144743367273</DS_MERCHANT_ORDER>')),
        includes(CGI.escape('<DS_MERCHANT_AMOUNT>100</DS_MERCHANT_AMOUNT>'))
      ),
      anything
    ).returns(successful_capture_response)
    @gateway.capture(100, '144743367273')
  end

  def test_void
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes(CGI.escape('<DS_MERCHANT_TRANSACTIONTYPE>9</DS_MERCHANT_TRANSACTIONTYPE>')),
        includes(CGI.escape('<DS_MERCHANT_ORDER>144743389043</DS_MERCHANT_ORDER>')),
        includes(CGI.escape('<DS_MERCHANT_AMOUNT>100</DS_MERCHANT_AMOUNT>')),
        includes(CGI.escape('<DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>'))
      ),
      anything
    ).returns(successful_void_response)
    @gateway.void('144743389043|100|978')
  end

  def test_override_currency
    @gateway.expects(:ssl_post).with(
      anything,
      includes(CGI.escape('<DS_MERCHANT_CURRENCY>840</DS_MERCHANT_CURRENCY>')),
      anything
    ).returns(successful_purchase_response)
    @gateway.authorize(100, credit_card, order_id: '1001', currency: 'USD')
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.verify(credit_card, order_id: '144743367273')
    assert_success response
  end

  def test_unsuccessful_verify
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    response = @gateway.verify(credit_card, order_id: '141278225678')
    assert_failure response
    assert_equal 'SIS0093 ERROR', response.message
  end

  def test_unknown_currency
    assert_raise ArgumentError do
      @gateway.purchase(100, credit_card, @options.merge(currency: 'HUH WUT'))
    end
  end

  def test_default_currency
    assert_equal 'EUR', RedsysGateway.default_currency
  end

  def test_supported_countries
    assert_equal %w[ES FR GB IT PL PT], RedsysGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal %i[visa master american_express jcb diners_club unionpay patagonia_365], RedsysGateway.supported_cardtypes
  end

  def test_using_test_mode
    assert @gateway.test?
    assert_equal @gateway.send(:url), RedsysGateway.test_url
  end

  def test_overriding_options
    Base.mode = :production
    gw = RedsysGateway.new(
      terminal: 1,
      login: '1234',
      secret_key: '12345',
      test: true
    )
    assert gw.test?
    assert_equal RedsysGateway.test_url, gw.send(:url)
  end

  def test_production_mode
    Base.mode = :production
    gw = RedsysGateway.new(
      terminal: 1,
      login: '1234',
      secret_key: '12345'
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

  def test_failed_3ds_transaction_transcript_scrubbing
    assert_equal failed_3ds_transaction_post_scrubbed, @gateway.scrub(failed_3ds_transaction_pre_scrubbed)
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

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end

  # Sample response for two main types of operation,
  # one with card and another without.

  def purchase_request
    'entrada=%3C%3Fxml+version%3D%221.0%22+encoding%3D%22UTF-8%22%3F%3E%3CREQUEST%3E%3CDATOSENTRADA%3E%3CDS_Version%3E0.1%3C%2FDS_Version%3E%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%3CDS_MERCHANT_ORDER%3E144742736014%3C%2FDS_MERCHANT_ORDER%3E%3CDS_MERCHANT_TRANSACTIONTYPE%3E0%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%3CDS_MERCHANT_PRODUCTDESCRIPTION%2F%3E%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%3CDS_MERCHANT_MERCHANTCODE%3E091952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%3CDS_MERCHANT_TITULAR%3ELongbob+Longsen%3C%2FDS_MERCHANT_TITULAR%3E%3CDS_MERCHANT_PAN%3E4548812049400004%3C%2FDS_MERCHANT_PAN%3E%3CDS_MERCHANT_EXPIRYDATE%3E1709%3C%2FDS_MERCHANT_EXPIRYDATE%3E%3CDS_MERCHANT_CVV2%3E123%3C%2FDS_MERCHANT_CVV2%3E%3C%2FDATOSENTRADA%3E%3CDS_SIGNATUREVERSION%3EHMAC_SHA256_V1%3C%2FDS_SIGNATUREVERSION%3E%3CDS_SIGNATURE%3Ef46TQxKLJJ6SjcETDp%2Bul92Qsb5kVve2QzGnZMj8JkI%3D%3C%2FDS_SIGNATURE%3E%3C%2FREQUEST%3E'
  end

  def purchase_request_with_credit_card_token
    'entrada=%3C%3Fxml+version%3D%221.0%22+encoding%3D%22UTF-8%22%3F%3E%3CREQUEST%3E%3CDATOSENTRADA%3E%3CDS_Version%3E0.1%3C%2FDS_Version%3E%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%3CDS_MERCHANT_ORDER%3E144742884282%3C%2FDS_MERCHANT_ORDER%3E%3CDS_MERCHANT_TRANSACTIONTYPE%3E0%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%3CDS_MERCHANT_PRODUCTDESCRIPTION%2F%3E%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%3CDS_MERCHANT_MERCHANTCODE%3E091952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%3CDS_MERCHANT_IDENTIFIER%3E3126bb8b80a79e66eb1ecc39e305288b60075f86%3C%2FDS_MERCHANT_IDENTIFIER%3E%3CDS_MERCHANT_DIRECTPAYMENT%3Etrue%3C%2FDS_MERCHANT_DIRECTPAYMENT%3E%3C%2FDATOSENTRADA%3E%3CDS_SIGNATUREVERSION%3EHMAC_SHA256_V1%3C%2FDS_SIGNATUREVERSION%3E%3CDS_SIGNATURE%3Eeozf9m%2FmDx7JKtcJSPvUa%2FdCZQmzzEAU2nrOVD84fp4%3D%3C%2FDS_SIGNATURE%3E%3C%2FREQUEST%3E'
  end

  def successful_purchase_response
    "<?xml version='1.0' encoding=\"UTF-8\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>144742736014</Ds_Order><Ds_Signature>P9OHK0+RjbFkx7Bgd/OVfn9garq3j3eNPig81jP/ziU=</Ds_Signature><Ds_MerchantCode>091952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>399127</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>"
  end

  def successful_purchase_response_with_credit_card_token
    "<?xml version='1.0' encoding=\"UTF-8\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>144742955848</Ds_Order><Ds_Signature>p9LAThJR5eC9QGUtf5ZNKtYTkQ8NAu9YOO3wgJfWP3U=</Ds_Signature><Ds_MerchantCode>091952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>399366</Ds_AuthorisationCode><Ds_TransactionType>A</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_Merchant_Identifier>e55e1d0ef338e281baf1d0b5b68be433260ddea0</Ds_Merchant_Identifier><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>\n"
  end

  def failed_purchase_response
    "<?xml version='1.0' encoding=\"UTF-8\" ?><RETORNOXML><CODIGO>SIS0093</CODIGO><RECIBIDO><?xml version=\"1.0\" encoding=\"UTF-8\"?><REQUEST><DATOSENTRADA><DS_Version>0.1</DS_Version><DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY><DS_MERCHANT_AMOUNT>100</DS_MERCHANT_AMOUNT><DS_MERCHANT_ORDER>144743314659</DS_MERCHANT_ORDER><DS_MERCHANT_TRANSACTIONTYPE>A</DS_MERCHANT_TRANSACTIONTYPE><DS_MERCHANT_PRODUCTDESCRIPTION/><DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL><DS_MERCHANT_MERCHANTCODE>091952713</DS_MERCHANT_MERCHANTCODE><DS_MERCHANT_TITULAR>Longbob Longsen</DS_MERCHANT_TITULAR><DS_MERCHANT_PAN>4242424242424242</DS_MERCHANT_PAN><DS_MERCHANT_EXPIRYDATE>1609</DS_MERCHANT_EXPIRYDATE><DS_MERCHANT_CVV2>123</DS_MERCHANT_CVV2></DATOSENTRADA><DS_SIGNATUREVERSION>HMAC_SHA256_V1</DS_SIGNATUREVERSION><DS_SIGNATURE>/iV3bMFP657mBtoRgUsW9hI/IQKMTiC9xV5YJiuK4hM=</DS_SIGNATURE></REQUEST></RECIBIDO></RETORNOXML>\n"
  end

  def error_purchase_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0051</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>1001</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>A</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>b5cdaf0f0672be67e6c77f219b63ecbeed1ce525</DS_MERCHANT_MERCHANTSIGNATURE>\n  <DS_MERCHANT_TITULAR>Sam Lown</DS_MERCHANT_TITULAR>\n  <DS_MERCHANT_PAN>4792587766554414</DS_MERCHANT_PAN>\n  <DS_MERCHANT_EXPIRYDATE>1510</DS_MERCHANT_EXPIRYDATE>\n  <DS_MERCHANT_CVV2>737</DS_MERCHANT_CVV2>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>\n"
  end

  def successful_authorize_response
    "<?xml version='1.0' encoding=\"UTF-8\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>144743367273</Ds_Order><Ds_Signature>29qv8K/6k3P1zyk5F+ZYmMel0uuOzC58kXCgp5rcnhI=</Ds_Signature><Ds_MerchantCode>091952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0000</Ds_Response><Ds_AuthorisationCode>399957</Ds_AuthorisationCode><Ds_TransactionType>1</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>\n"
  end

  def successful_authorize_with_3ds_response
    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Header/><soapenv:Body><p231:iniciaPeticionResponse xmlns:p231="http://webservice.sis.sermepa.es"><p231:iniciaPeticionReturn>&lt;RETORNOXML&gt;&lt;CODIGO&gt;0&lt;/CODIGO&gt;&lt;INFOTARJETA&gt;&lt;Ds_Order&gt;156270437866&lt;/Ds_Order&gt;&lt;Ds_MerchantCode&gt;091952713&lt;/Ds_MerchantCode&gt;&lt;Ds_Terminal&gt;1&lt;/Ds_Terminal&gt;&lt;Ds_TransactionType&gt;0&lt;/Ds_TransactionType&gt;&lt;Ds_EMV3DS&gt;{&quot;protocolVersion&quot;:&quot;NO_3DS_v2&quot;,&quot;threeDSInfo&quot;:&quot;CardConfiguration&quot;}&lt;/Ds_EMV3DS&gt;&lt;Ds_Signature&gt;LIWUaQh+lwsE0DBNpv2EOYALCY6ZxHDQ6gLvOcWiSB4=&lt;/Ds_Signature&gt;&lt;/INFOTARJETA&gt;&lt;/RETORNOXML&gt;</p231:iniciaPeticionReturn></p231:iniciaPeticionResponse></soapenv:Body></soapenv:Envelope>'
  end

  def successful_purchase_with_3ds2_and_mit_exemption_response
    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Header/><soapenv:Body><p231:iniciaPeticionResponse xmlns:p231="http://webservice.sis.sermepa.es"><p231:iniciaPeticionReturn>&lt;RETORNOXML&gt;&lt;CODIGO&gt;0&lt;/CODIGO&gt;&lt;INFOTARJETA&gt;&lt;Ds_Order&gt;161608782525&lt;/Ds_Order&gt;&lt;Ds_MerchantCode&gt;091952713&lt;/Ds_MerchantCode&gt;&lt;Ds_Terminal&gt;12&lt;/Ds_Terminal&gt;&lt;Ds_TransactionType&gt;0&lt;/Ds_TransactionType&gt;&lt;Ds_EMV3DS&gt;{&quot;protocolVersion&quot;:&quot;2.1.0&quot;,&quot;threeDSServerTransID&quot;:&quot;65120b61-28a3-476a-9aac-7b78c63a907a&quot;,&quot;threeDSInfo&quot;:&quot;CardConfiguration&quot;,&quot;threeDSMethodURL&quot;:&quot;https://sis-d.redsys.es/sis-simulador-web/threeDsMethod.jsp&quot;}&lt;/Ds_EMV3DS&gt;&lt;Ds_Card_PSD2&gt;Y&lt;/Ds_Card_PSD2&gt;&lt;Ds_Signature&gt;q4ija0q0x48NBb3O6EFLwEavCUMbtUWR/U38Iv0qSn0=&lt;/Ds_Signature&gt;&lt;/INFOTARJETA&gt;&lt;/RETORNOXML&gt;</p231:iniciaPeticionReturn></p231:iniciaPeticionResponse></soapenv:Body></soapenv:Envelope>'
  end

  def successful_non_3ds_purchase_with_mit_exemption_response
    '<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><soapenv:Header/><soapenv:Body><p231:trataPeticionResponse xmlns:p231=\"http://webservice.sis.sermepa.es\"><p231:trataPeticionReturn>&lt;RETORNOXML&gt;&lt;CODIGO&gt;0&lt;/CODIGO&gt;&lt;Ds_Version&gt;0.1&lt;/Ds_Version&gt;&lt;OPERACION&gt;&lt;Ds_Amount&gt;100&lt;/Ds_Amount&gt;&lt;Ds_Currency&gt;978&lt;/Ds_Currency&gt;&lt;Ds_Order&gt;162068064777&lt;/Ds_Order&gt;&lt;Ds_Signature&gt;axkiHGkNxpGp/JZFGC5/S0+u2n5r/S7jj6FY+F9eZ6k=&lt;/Ds_Signature&gt;&lt;Ds_MerchantCode&gt;091952713&lt;/Ds_MerchantCode&gt;&lt;Ds_Terminal&gt;1&lt;/Ds_Terminal&gt;&lt;Ds_Response&gt;0000&lt;/Ds_Response&gt;&lt;Ds_AuthorisationCode&gt;363732&lt;/Ds_AuthorisationCode&gt;&lt;Ds_TransactionType&gt;A&lt;/Ds_TransactionType&gt;&lt;Ds_SecurePayment&gt;0&lt;/Ds_SecurePayment&gt;&lt;Ds_Language&gt;1&lt;/Ds_Language&gt;&lt;Ds_MerchantData&gt;&lt;/Ds_MerchantData&gt;&lt;Ds_Card_Country&gt;724&lt;/Ds_Card_Country&gt;&lt;Ds_Card_Brand&gt;1&lt;/Ds_Card_Brand&gt;&lt;Ds_ProcessedPayMethod&gt;3&lt;/Ds_ProcessedPayMethod&gt;&lt;/OPERACION&gt;&lt;/RETORNOXML&gt;</p231:trataPeticionReturn></p231:trataPeticionResponse></soapenv:Body></soapenv:Envelope>'
  end

  def failed_authorize_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0093</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>100</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>141278225678</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>1</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>1c34699589507802f800b929ea314dc143b0b8a5</DS_MERCHANT_MERCHANTSIGNATURE>\n  <DS_MERCHANT_TITULAR>Longbob Longsen</DS_MERCHANT_TITULAR>\n  <DS_MERCHANT_PAN>4242424242424242</DS_MERCHANT_PAN>\n  <DS_MERCHANT_EXPIRYDATE>1509</DS_MERCHANT_EXPIRYDATE>\n  <DS_MERCHANT_CVV2>123</DS_MERCHANT_CVV2>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>"
  end

  def refund_request
    'entrada=%3C%3Fxml+version%3D%221.0%22+encoding%3D%22UTF-8%22%3F%3E%3CREQUEST%3E%3CDATOSENTRADA%3E%3CDS_Version%3E0.1%3C%2FDS_Version%3E%3CDS_MERCHANT_CURRENCY%3E978%3C%2FDS_MERCHANT_CURRENCY%3E%3CDS_MERCHANT_AMOUNT%3E100%3C%2FDS_MERCHANT_AMOUNT%3E%3CDS_MERCHANT_ORDER%3E144743427234%3C%2FDS_MERCHANT_ORDER%3E%3CDS_MERCHANT_TRANSACTIONTYPE%3E3%3C%2FDS_MERCHANT_TRANSACTIONTYPE%3E%3CDS_MERCHANT_PRODUCTDESCRIPTION%2F%3E%3CDS_MERCHANT_TERMINAL%3E1%3C%2FDS_MERCHANT_TERMINAL%3E%3CDS_MERCHANT_MERCHANTCODE%3E091952713%3C%2FDS_MERCHANT_MERCHANTCODE%3E%3C%2FDATOSENTRADA%3E%3CDS_SIGNATUREVERSION%3EHMAC_SHA256_V1%3C%2FDS_SIGNATUREVERSION%3E%3CDS_SIGNATURE%3EQhNVtjoee6s%2Bvo%2B5bJVM4esT58bz7zkY1Xe7qjdmxA0%3D%3C%2FDS_SIGNATURE%3E%3C%2FREQUEST%3E'
  end

  def successful_refund_response
    "<?xml version='1.0' encoding=\"UTF-8\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>144743427234</Ds_Order><Ds_Signature>Iyc7inddQUGys6zbCZQUteIeR31ZDyQOT4zW+uxjB0M=</Ds_Signature><Ds_MerchantCode>091952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0900</Ds_Response><Ds_AuthorisationCode>400062</Ds_AuthorisationCode><Ds_TransactionType>3</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>\n"
  end

  def error_refund_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0057</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>123</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>1001</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>3</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>9e12f1607147b4611bfdbff80aa143241c27f935</DS_MERCHANT_MERCHANTSIGNATURE>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>\n"
  end

  def successful_void_response
    "<?xml version='1.0' encoding=\"UTF-8\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>144743389043</Ds_Order><Ds_Signature>nqT1A3Kk9BeFrpwwl+n5YyBZ23ufqiEvu7/gzl9xBqM=</Ds_Signature><Ds_MerchantCode>091952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0400</Ds_Response><Ds_AuthorisationCode>400002</Ds_AuthorisationCode><Ds_TransactionType>9</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>\n"
  end

  def failed_void_response
    "<?xml version='1.0' encoding=\"ISO-8859-1\" ?><RETORNOXML><CODIGO>SIS0222</CODIGO><RECIBIDO><DATOSENTRADA>\n  <DS_Version>0.1</DS_Version>\n  <DS_MERCHANT_CURRENCY>978</DS_MERCHANT_CURRENCY>\n  <DS_MERCHANT_AMOUNT>100</DS_MERCHANT_AMOUNT>\n  <DS_MERCHANT_ORDER>141278298713</DS_MERCHANT_ORDER>\n  <DS_MERCHANT_TRANSACTIONTYPE>9</DS_MERCHANT_TRANSACTIONTYPE>\n  <DS_MERCHANT_TERMINAL>1</DS_MERCHANT_TERMINAL>\n  <DS_MERCHANT_MERCHANTCODE>91952713</DS_MERCHANT_MERCHANTCODE>\n  <DS_MERCHANT_MERCHANTSIGNATURE>ead33f15453316e86dfc51642e400e2467fe71bb</DS_MERCHANT_MERCHANTSIGNATURE>\n</DATOSENTRADA>\n</RECIBIDO></RETORNOXML>"
  end

  def successful_capture_response
    "<?xml version='1.0' encoding=\"UTF-8\" ?><RETORNOXML><CODIGO>0</CODIGO><Ds_Version>0.1</Ds_Version><OPERACION><Ds_Amount>100</Ds_Amount><Ds_Currency>978</Ds_Currency><Ds_Order>144743367273</Ds_Order><Ds_Signature>mPJiCwWEFf21P44slxLsxqX37DGJRoQyYJUXUhOjXvI=</Ds_Signature><Ds_MerchantCode>091952713</Ds_MerchantCode><Ds_Terminal>1</Ds_Terminal><Ds_Response>0900</Ds_Response><Ds_AuthorisationCode>399957</Ds_AuthorisationCode><Ds_TransactionType>2</Ds_TransactionType><Ds_SecurePayment>0</Ds_SecurePayment><Ds_Language>1</Ds_Language><Ds_MerchantData></Ds_MerchantData><Ds_Card_Country>724</Ds_Card_Country></OPERACION></RETORNOXML>\n"
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

  def failed_3ds_transaction_pre_scrubbed
    %q(
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Header/><soapenv:Body><p231:trataPeticionResponse xmlns:p231="http://webservice.sis.sermepa.es"><p231:trataPeticionReturn>&lt;RETORNOXML&gt;&lt;CODIGO&gt;SIS0571&lt;/CODIGO&gt;&lt;RECIBIDO&gt;\n                &lt;REQUEST&gt;&lt;DATOSENTRADA&gt;&lt;DS_Version&gt;0.1&lt;/DS_Version&gt;&lt;DS_MERCHANT_CURRENCY&gt;978&lt;/DS_MERCHANT_CURRENCY&gt;&lt;DS_MERCHANT_AMOUNT&gt;100&lt;/DS_MERCHANT_AMOUNT&gt;&lt;DS_MERCHANT_ORDER&gt;82973d604ba1&lt;/DS_MERCHANT_ORDER&gt;&lt;DS_MERCHANT_TRANSACTIONTYPE&gt;1&lt;/DS_MERCHANT_TRANSACTIONTYPE&gt;&lt;DS_MERCHANT_PRODUCTDESCRIPTION/&gt;&lt;DS_MERCHANT_TERMINAL&gt;12&lt;/DS_MERCHANT_TERMINAL&gt;&lt;DS_MERCHANT_MERCHANTCODE&gt;091952713&lt;/DS_MERCHANT_MERCHANTCODE&gt;&lt;DS_MERCHANT_TITULAR&gt;Jane Doe&lt;/DS_MERCHANT_TITULAR&gt;&lt;DS_MERCHANT_PAN&gt;4548812049400004&lt;/DS_MERCHANT_PAN&gt;&lt;DS_MERCHANT_EXPIRYDATE&gt;2012&lt;/DS_MERCHANT_EXPIRYDATE&gt;&lt;DS_MERCHANT_CVV2&gt;123&lt;/DS_MERCHANT_CVV2&gt;&lt;DS_MERCHANT_EMV3DS&gt;{&quot;threeDSInfo&quot;:&quot;AuthenticationData&quot;,&quot;browserAcceptHeader&quot;:&quot;text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3&quot;,&quot;browserUserAgent&quot;:&quot;Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36&quot;}&lt;/DS_MERCHANT_EMV3DS&gt;&lt;/DATOSENTRADA&gt;&lt;DS_SIGNATUREVERSION&gt;HMAC_SHA256_V1&lt;/DS_SIGNATUREVERSION&gt;&lt;DS_SIGNATURE&gt;ips3TqR6upMAEbC0D6vmzV9tldU5224MSR63dpWPBT0=&lt;/DS_SIGNATURE&gt;&lt;/REQUEST&gt;\n                &lt;/RECIBIDO&gt;&lt;/RETORNOXML&gt;</p231:trataPeticionReturn></p231:trataPeticionResponse></soapenv:Body></soapenv:Envelope>
    )
  end

  def failed_3ds_transaction_post_scrubbed
    %q(
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Header/><soapenv:Body><p231:trataPeticionResponse xmlns:p231="http://webservice.sis.sermepa.es"><p231:trataPeticionReturn>&lt;RETORNOXML&gt;&lt;CODIGO&gt;SIS0571&lt;/CODIGO&gt;&lt;RECIBIDO&gt;\n                &lt;REQUEST&gt;&lt;DATOSENTRADA&gt;&lt;DS_Version&gt;0.1&lt;/DS_Version&gt;&lt;DS_MERCHANT_CURRENCY&gt;978&lt;/DS_MERCHANT_CURRENCY&gt;&lt;DS_MERCHANT_AMOUNT&gt;100&lt;/DS_MERCHANT_AMOUNT&gt;&lt;DS_MERCHANT_ORDER&gt;82973d604ba1&lt;/DS_MERCHANT_ORDER&gt;&lt;DS_MERCHANT_TRANSACTIONTYPE&gt;1&lt;/DS_MERCHANT_TRANSACTIONTYPE&gt;&lt;DS_MERCHANT_PRODUCTDESCRIPTION/&gt;&lt;DS_MERCHANT_TERMINAL&gt;12&lt;/DS_MERCHANT_TERMINAL&gt;&lt;DS_MERCHANT_MERCHANTCODE&gt;091952713&lt;/DS_MERCHANT_MERCHANTCODE&gt;&lt;DS_MERCHANT_TITULAR&gt;Jane Doe&lt;/DS_MERCHANT_TITULAR&gt;&lt;DS_MERCHANT_PAN&gt;[FILTERED]&lt;/DS_MERCHANT_PAN&gt;&lt;DS_MERCHANT_EXPIRYDATE&gt;2012&lt;/DS_MERCHANT_EXPIRYDATE&gt;&lt;DS_MERCHANT_CVV2&gt;[FILTERED]&lt;/DS_MERCHANT_CVV2&gt;&lt;DS_MERCHANT_EMV3DS&gt;{&quot;threeDSInfo&quot;:&quot;AuthenticationData&quot;,&quot;browserAcceptHeader&quot;:&quot;text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3&quot;,&quot;browserUserAgent&quot;:&quot;Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36&quot;}&lt;/DS_MERCHANT_EMV3DS&gt;&lt;/DATOSENTRADA&gt;&lt;DS_SIGNATUREVERSION&gt;HMAC_SHA256_V1&lt;/DS_SIGNATUREVERSION&gt;&lt;DS_SIGNATURE&gt;ips3TqR6upMAEbC0D6vmzV9tldU5224MSR63dpWPBT0=&lt;/DS_SIGNATURE&gt;&lt;/REQUEST&gt;\n                &lt;/RECIBIDO&gt;&lt;/RETORNOXML&gt;</p231:trataPeticionReturn></p231:trataPeticionResponse></soapenv:Body></soapenv:Envelope>
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
