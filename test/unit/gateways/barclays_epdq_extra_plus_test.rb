require 'test_helper'

class BarclaysEpdqExtraPlusTest < Test::Unit::TestCase
  def setup
    @credentials = { :login => 'pspid',
                     :user => 'username',
                     :password => 'password',
                     :signature => 'mynicesig',
                     :signature_encryptor => 'sha512' }
    @gateway = BarclaysEpdqExtraPlusGateway.new(@credentials)
    @credit_card = credit_card
    @mastercard  = credit_card('5399999999999999', :brand => "mastercard")
    @amount = 100
    @identification = "3014726"
    @billing_id = "myalias"
    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
    @parameters = {
      'orderID' => '1',
      'amount' => '100',
      'currency' => 'EUR',
      'CARDNO' => '4111111111111111',
      'PSPID' => 'MrPSPID',
      'Operation' => 'RES',
      'ALIAS' => '2',
      'CN' => 'Client Name'
    }
    @parameters_d3d = {
      'FLAG3D' => 'Y',
      'WIN3DS' => 'MAINW',
      'HTTP_ACCEPT' => "*/*"
    }
  end

  def teardown
    Base.mode = :test
  end

  def test_successful_purchase
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'ECI', '7')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '3014726;SAL', response.authorization
    assert response.params['HTML_ANSWER'].nil?
    assert response.test?
  end

  def test_successful_purchase_with_action_param
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'ECI', '7')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:action => 'SAS'))
    assert_success response
    assert_equal '3014726;SAS', response.authorization
    assert response.params['HTML_ANSWER'].nil?
    assert response.test?
  end

  def test_successful_purchase_without_order_id
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    @options.delete(:order_id)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '3014726;SAL', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_custom_eci
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'ECI', '4')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:eci => 4))
    assert_success response
    assert_equal '3014726;SAL', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_3dsecure
    @gateway.expects(:ssl_post).returns(successful_3dsecure_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:d3d => true))
    assert_success response
    assert_equal '3014726;SAL', response.authorization
    assert response.params['HTML_ANSWER']
    assert_equal nil, response.params['HTML_ANSWER'] =~ /<HTML_ANSWER>/
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'ECI', '7')
    @gateway.expects(:add_pair).with(anything, 'Operation', 'RES')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '3014726;RES', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_mastercard
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'Operation', 'PAU')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @mastercard, @options)
    assert_success response
    assert_equal '3014726;PAU', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_custom_eci
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'ECI', '4')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options.merge(:eci => 4))
    assert_success response
    assert_equal '3014726;RES', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_3dsecure
    @gateway.expects(:ssl_post).returns(successful_3dsecure_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options.merge(:d3d => true))
    assert_success response
    assert_equal '3014726;RES', response.authorization
    assert response.params['HTML_ANSWER']
    assert_equal nil, response.params['HTML_ANSWER'] =~ /<HTML_ANSWER>/
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, "3048326")
    assert_success response
    assert_equal '3048326;SAL', response.authorization
    assert response.test?
  end

  def test_successful_capture_with_action_option
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, "3048326", :action => 'SAS')
    assert_success response
    assert_equal '3048326;SAS', response.authorization
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void("3048606")
    assert_success response
    assert_equal '3048606;DES', response.authorization
    assert response.test?
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).returns(successful_referenced_credit_response)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      assert response = @gateway.credit(@amount, "3049652;SAL")
      assert_success response
      assert_equal '3049652;RFD', response.authorization
      assert response.test?
    end
  end

  def test_successful_unreferenced_credit
    @gateway.expects(:ssl_post).returns(successful_unreferenced_credit_response)
    assert response = @gateway.credit(@amount, @credit_card)
    assert_success response
    assert_equal "3049654;RFD", response.authorization
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_referenced_credit_response)
    assert response = @gateway.refund(@amount, "3049652")
    assert_success response
    assert_equal '3049652;RFD', response.authorization
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'ECI', '7')
    @gateway.expects(:ssl_post).times(2).returns(successful_purchase_response)
    assert response = @gateway.store(@credit_card, :billing_id => @billing_id)
    assert_success response
    assert_equal '3014726;RES', response.authorization
    assert_equal '2', response.billing_id
    assert response.test?
  end

  def test_deprecated_store_option
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'ECI', '7')
    @gateway.expects(:ssl_post).times(2).returns(successful_purchase_response)
    assert_deprecation_warning(BarclaysEpdqExtraPlusGateway::OGONE_STORE_OPTION_DEPRECATION_MESSAGE) do
      assert response = @gateway.store(@credit_card, :store => @billing_id)
      assert_success response
      assert_equal '3014726;RES', response.authorization
      assert response.test?
    end
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_create_readable_error_message_upon_failure
    @gateway.expects(:ssl_post).returns(test_failed_authorization_due_to_unknown_order_number)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?

    assert_equal "Unknown order", response.message
  end

  def test_supported_countries
    assert_equal ['GB'], BarclaysEpdqExtraPlusGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro], BarclaysEpdqExtraPlusGateway.supported_cardtypes
  end

  def test_default_currency
    assert_equal 'GBP', BarclaysEpdqExtraPlusGateway.default_currency

    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials)
    gateway.expects(:add_pair).at_least(1)
    gateway.expects(:add_pair).with(anything, 'currency', 'GBP')
    gateway.expects(:ssl_post).returns(successful_purchase_response)
    gateway.purchase(@amount, @credit_card, @options)
  end

  def test_custom_currency_at_gateway_level
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials.merge(:currency => 'USD'))
    gateway.expects(:add_pair).at_least(1)
    gateway.expects(:add_pair).with(anything, 'currency', 'USD')
    gateway.expects(:ssl_post).returns(successful_purchase_response)
    gateway.purchase(@amount, @credit_card, @options)
  end

  def test_local_custom_currency_overwrite_gateway_level
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials.merge(:currency => 'USD'))
    gateway.expects(:add_pair).at_least(1)
    gateway.expects(:add_pair).with(anything, 'currency', 'EUR')
    gateway.expects(:ssl_post).returns(successful_purchase_response)
    gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'EUR'))
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'R', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'P', response.cvv_result['code']
  end

  def test_billing_id
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal '2', response.billing_id
  end

  def test_order_id
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal '1233680882919266242708828', response.order_id
  end

  def test_production_mode
    Base.mode = :production
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials)
    assert !gateway.test?
  end

  def test_test_mode
    Base.mode = :production
    @credentials[:test] = true
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials)
    assert gateway.test?
  end

  def test_format_error_message_with_slash_separator
    @gateway.expects(:ssl_post).returns('<ncresponse NCERRORPLUS="unknown order/1/i/67.192.100.64" STATUS="0" />')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal "Unknown order", response.message
  end

  def test_format_error_message_with_pipe_separator
    @gateway.expects(:ssl_post).returns('<ncresponse NCERRORPLUS=" no card no|no exp date|no brand" STATUS="0" />')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal "No card no, no exp date, no brand", response.message
  end

  def test_format_error_message_with_no_separator
    @gateway.expects(:ssl_post).returns('<ncresponse NCERRORPLUS=" unknown order " STATUS="0" />')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal "Unknown order", response.message
  end

  def test_without_signature
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials.merge(:signature => nil, :signature_encryptor => nil))
    gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert_deprecation_warning(BarclaysEpdqExtraPlusGateway::OGONE_NO_SIGNATURE_DEPRECATION_MESSAGE) do
      gateway.purchase(@amount, @credit_card, @options)
    end

    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials.merge(:signature => nil, :signature_encryptor => "none"))
    gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert_no_deprecation_warning do
      gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_signature_for_accounts_created_before_10_may_20101
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials.merge(:signature_encryptor => nil))
    assert signature = gateway.send(:add_signature, @parameters)
    assert_equal Digest::SHA1.hexdigest("1100EUR4111111111111111MrPSPIDRES2mynicesig").upcase, signature
  end

  def test_signature_for_accounts_with_signature_encryptor_to_sha1
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials.merge(:signature_encryptor => 'sha1'))

    assert signature = gateway.send(:add_signature, @parameters)
    assert_equal Digest::SHA1.hexdigest(string_to_digest).upcase, signature
  end

  def test_signature_for_accounts_with_signature_encryptor_to_sha256
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials.merge(:signature_encryptor => 'sha256'))

    assert signature = gateway.send(:add_signature, @parameters)
    assert_equal Digest::SHA256.hexdigest(string_to_digest).upcase, signature
  end

  def test_signature_for_accounts_with_signature_encryptor_to_sha512
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials.merge(:signature_encryptor => 'sha512'))
    assert signature = gateway.send(:add_signature, @parameters)
    assert_equal Digest::SHA512.hexdigest(string_to_digest).upcase, signature
  end

  def test_signature_for_accounts_with_3dsecure
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials)
    assert signature = gateway.send(:add_signature, @parameters.merge(@parameters_d3d))
    assert_equal Digest::SHA512.hexdigest(d3d_string_to_digest).upcase, signature
  end

  def test_3dsecure_win_3ds_option
    post = {}
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials)

    gateway.send(:add_d3d, post, { :win_3ds => :pop_up })
    assert 'POPUP', post["WIN3DS"]

    gateway.send(:add_d3d, post, { :win_3ds => :pop_ix })
    assert 'POPIX', post["WIN3DS"]

    gateway.send(:add_d3d, post, { :win_3ds => :invalid })
    assert 'MAINW', post["WIN3DS"]
  end

  def test_3dsecure_additional_options
    post = {}
    gateway = BarclaysEpdqExtraPlusGateway.new(@credentials)

    gateway.send(:add_d3d, post, {
      :http_accept => "text/html",
      :http_user_agent => "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)",
      :accept_url => 'https://accept_url',
      :decline_url => 'https://decline_url',
      :exception_url => 'https://exception_url',
      :paramsplus => 'params_plus',
      :complus => 'com_plus',
      :language => 'fr_FR'
    })
    assert 'HTTP_ACCEPT', "text/html"
    assert 'HTTP_USER_AGENT', "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)"
    assert 'ACCEPTURL', 'https://accept_url'
    assert 'DECLINEURL', 'https://decline_url'
    assert 'EXCEPTIONURL', 'https://exception_url'
    assert 'PARAMSPLUS', 'params_plus'
    assert 'COMPLUS', 'com_plus'
    assert 'LANGUAGE', 'fr_FR'
  end

  def test_accessing_params_attribute_of_response
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'test123', response.params['ACCEPTANCE']
    assert response.test?
  end

  def test_response_params_is_hash
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Hash, response.params
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def string_to_digest
    "ALIAS=2mynicesigAMOUNT=100mynicesigCARDNO=4111111111111111mynicesig"+
    "CN=Client NamemynicesigCURRENCY=EURmynicesigOPERATION=RESmynicesig"+
    "ORDERID=1mynicesigPSPID=MrPSPIDmynicesig"
  end

  def d3d_string_to_digest
    "ALIAS=2mynicesigAMOUNT=100mynicesigCARDNO=4111111111111111mynicesig"+
    "CN=Client NamemynicesigCURRENCY=EURmynicesigFLAG3D=Ymynicesig"+
    "HTTP_ACCEPT=*/*mynicesigOPERATION=RESmynicesigORDERID=1mynicesig"+
    "PSPID=MrPSPIDmynicesigWIN3DS=MAINWmynicesig"
  end

  def successful_authorize_response
    <<-END
      <?xml version="1.0"?><ncresponse
        orderID="1233680882919266242708828"
        PAYID="3014726"
        NCSTATUS="0"
        NCERROR="0"
        NCERRORPLUS="!"
        ACCEPTANCE="test123"
        STATUS="5"
        IPCTY="99"
        CCCTY="99"
        ECI="7"
        CVCCheck="NO"
        AAVCheck="NO"
        VC="NO"
        amount="1"
        currency="EUR"
        PM="CreditCard"
        BRAND="VISA"
        ALIAS="2">
      </ncresponse>
    END
  end

  def successful_purchase_response
    <<-END
      <?xml version="1.0"?><ncresponse
        orderID="1233680882919266242708828"
        PAYID="3014726"
        NCSTATUS="0"
        NCERROR="0"
        NCERRORPLUS="!"
        ACCEPTANCE="test123"
        STATUS="5"
        IPCTY="99"
        CCCTY="99"
        ECI="7"
        CVCCheck="NO"
        AAVCheck="NO"
        VC="NO"
        amount="1"
        currency="EUR"
        PM="CreditCard"
        BRAND="VISA"
        ALIAS="2">
      </ncresponse>
    END
  end

  def successful_3dsecure_purchase_response
    <<-END
      <?xml version="1.0"?><ncresponse
        orderID="1233680882919266242708828"
        PAYID="3014726"
        NCSTATUS="0"
        NCERROR="0"
        NCERRORPLUS="!"
        ACCEPTANCE="test123"
        STATUS="46"
        IPCTY="99"
        CCCTY="99"
        ECI="7"
        CVCCheck="NO"
        AAVCheck="NO"
        VC="NO"
        amount="1"
        currency="EUR"
        PM="CreditCard"
        BRAND="VISA">
        <HTML_ANSWER>PGZvcm0gbmFtZT0iZG93bmxvYWRmb3JtM0QiIGFjdGlvbj0iaHR0cHM6Ly9z
        ZWN1cmUub2dvbmUuY29tL25jb2wvdGVzdC9UZXN0XzNEX0FDUy5hc3AiIG1l
        dGhvZD0icG9zdCI+CiAgPE5PU0NSSVBUPgogICAgSmF2YVNjcmlwdCBpcyBj
        dXJyZW50bHkgZGlzYWJsZWQgb3IgaXMgbm90IHN1cHBvcnRlZCBieSB5b3Vy
        IGJyb3dzZXIuPGJyPgogICAgUGxlYXNlIGNsaWNrIG9uIHRoZSAmcXVvdDtD
        b250aW51ZSZxdW90OyBidXR0b24gdG8gY29udGludWUgdGhlIHByb2Nlc3Np
        bmcgb2YgeW91ciAzLUQgc2VjdXJlIHRyYW5zYWN0aW9uLjxicj4KICAgIDxp
        bnB1dCBjbGFzcz0ibmNvbCIgdHlwZT0ic3VibWl0IiB2YWx1ZT0iQ29udGlu
        dWUiIGlkPSJzdWJtaXQxIiBuYW1lPSJzdWJtaXQxIiAvPgogIDwvTk9TQ1JJ
        UFQ+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iQ1NSRktFWSIgdmFs
        dWU9IjExMDc0NkE4QTExRTBDMEVGMUFDQjQ2NkY0MkU0RERBMDQ5QkZBNTgi
        IC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iQ1NSRlRTIiB2YWx1
        ZT0iMjAxMTAzMTUxNTA0MzEiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIg
        bmFtZT0iQ1NSRlNQIiB2YWx1ZT0iL25jb2wvdGVzdC9vcmRlcmRpcmVjdC5h
        c3AiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iUGFSZXEiIHZh
        bHVlPSI8P3htbCB2ZXJzaW9uPSZxdW90OzEuMCZxdW90Oz8+PFRocmVlRFNl
        Y3VyZT48TWVzc2FnZSBpZD0mcXVvdDsxMjMmcXVvdDs+PFBBUmVxPjx2ZXJz
        aW9uPjEuMDI8L3ZlcnNpb24+PE1lcmNoYW50PjxtZXJJRD5tZXJjaGFudF9u
        YW1lPC9tZXJJRD48bmFtZT5NZXJjaGFudDwvbmFtZT48dXJsPmh0dHA6Ly9t
        ZXJjaGFudC5jb208L3VybD48L01lcmNoYW50PjxQdXJjaGFzZT48eGlkPjk2
        NTU4NDg8L3hpZD48YW1vdW50PjEuOTM8L2Ftb3VudD48cHVyY2hBbW91bnQ+
        MS45MzwvcHVyY2hBbW91bnQ+PGN1cnJlbmN5PlVTRDwvY3VycmVuY3k+PC9Q
        dXJjaGFzZT48Q0g+PGFjY3RJRD40MDAwMDAwMDAwMDAwMDAyPC9hY2N0SUQ+
        PGV4cGlyeT4wMzEyPC9leHBpcnk+PHNlbEJyYW5kPjwvc2VsQnJhbmQ+PC9D
        SD48L1BBUmVxPjwvTWVzc2FnZT48L1RocmVlRFNlY3VyZT4KICAiIC8+CiAg
        PGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iVGVybVVybCIgdmFsdWU9Imh0
        dHBzOi8vc2VjdXJlLm9nb25lLmNvbS9uY29sL3Rlc3Qvb3JkZXJfQTNEUy5h
        c3AiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iTUQiIHZhbHVl
        PSJNQUlOV1BURVNUMDAwMDA5NjU1ODQ4MDExMTEiIC8+CjwvZm9ybT4KCjxm
        b3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSJodHRwczovL3NlY3VyZS5vZ29u
        ZS5jb20vbmNvbC90ZXN0L29yZGVyX2FncmVlLmFzcCIgbmFtZT0idXBsb2Fk
        Rm9ybTNEIj4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJDU1JGS0VZ
        IiB2YWx1ZT0iMEI2NDNEMDZFNTczQzkxRDBDQkQwOEY4RjlFREU4RjdDNDJD
        MjQ2OSIgLz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJDU1JGVFMi
        IHZhbHVlPSIyMDExMDMxNTE1MDQzMSIgLz4KICA8aW5wdXQgdHlwZT0iaGlk
        ZGVuIiBuYW1lPSJDU1JGU1AiIHZhbHVlPSIvbmNvbC90ZXN0L29yZGVyZGly
        ZWN0LmFzcCIgLz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJicmFu
        ZGluZyIgdmFsdWU9Ik9nb25lIiAvPgogIDxpbnB1dCB0eXBlPSJoaWRkZW4i
        IG5hbWU9InBheWlkIiB2YWx1ZT0iOTY1NTg0OCIgLz4KICA8aW5wdXQgdHlw
        ZT0iaGlkZGVuIiBuYW1lPSJzdG9yZWFsaWFzIiB2YWx1ZT0iIiAvPgogIDxp
        bnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9Imhhc2hfcGFyYW0iIHZhbHVlPSJE
        NzY2NzhBRkE0MTBERjYxOUMzMkZGRUNFQTIzQTZGMkI1QkQxRDdBIiAvPgog
        IDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9InhpZF8zRCIgdmFsdWU9IiIg
        Lz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJzdGF0dXNfM0QiIHZh
        bHVlPSJYWCIgLz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJlY2lf
        M0QiIHZhbHVlPSIwIiAvPgogIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9
        ImNhcmRudW1iZXIiIHZhbHVlPSIiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRl
        biIgbmFtZT0iRWNvbV9QYXltZW50X0NhcmRfVmVyaWZpY2F0aW9uIiB2YWx1
        ZT0iMTExIiAvPgogIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9IkNWQ0Zs
        YWciIHZhbHVlPSIxIiAvPgogIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9
        ImNhdnZfM0QiIHZhbHVlPSIiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIg
        bmFtZT0iY2F2dmFsZ29yaXRobV8zRCIgdmFsdWU9IiIgLz4KICA8aW5wdXQg
        dHlwZT0iaGlkZGVuIiBuYW1lPSJzaWduYXR1cmVPS18zRCIgdmFsdWU9IiIg
        Lz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJoYXNoX3BhcmFtXzNE
        IiB2YWx1ZT0iODQzNDg3RDNEQzkyRkFDQ0FCMEZBQTRGMUM1NTYyMUFBMjhE
        Qzk4OCIgLz4KPC9mb3JtPgo8U0NSSVBUIExBTkdVQUdFPSJKYXZhc2NyaXB0
        IiA+CjwhLS0KdmFyIHBvcHVwV2luOwp2YXIgc3VibWl0cG9wdXBXaW4gPSAw
        OwoKZnVuY3Rpb24gTG9hZFBvcHVwKCkgewogIGlmIChzZWxmLm5hbWUgPT0g
        bnVsbCkJewogICAgc2VsZi5uYW1lID0gIm9nb25lTWFpbiI7CiAgfQogIHBv
        cHVwV2luID0gd2luZG93Lm9wZW4oJ2Fib3V0OmJsYW5rJywgJ3BvcHVwV2lu
        JywgJ2hlaWdodD00MDAsIHdpZHRoPTM5MCwgc3RhdHVzPXllcywgZGVwZW5k
        ZW50PW5vLCBzY3JvbGxiYXJzPXllcywgcmVzaXphYmxlPW5vJyk7CiAgaWYg
        KHBvcHVwV2luICE9IG51bGwpIHsKICAgIGlmICAoIXBvcHVwV2luIHx8IHBv
        cHVwV2luLmNsb3NlZCkgewogICAgICByZXR1cm4gMTsKICAgIH0gZWxzZSB7
        CiAgICAgIGlmICghcG9wdXBXaW4ub3BlbmVyIHx8IHBvcHVwV2luLm9wZW5l
        ciA9PSBudWxsKSB7CiAgICAgICAgcG9wdXBXaW4ub3BlbmVyID0gc2VsZjsK
        ICAgICAgfQogICAgICBzZWxmLmRvY3VtZW50LmZvcm1zLmRvd25sb2FkZm9y
        bTNELnRhcmdldCA9ICdwb3B1cFdpbic7CiAgICAgIGlmIChzdWJtaXRwb3B1
        cFdpbiA9PSAxKSB7CiAgICAgICAgc2VsZi5kb2N1bWVudC5mb3Jtcy5kb3du
        bG9hZGZvcm0zRC5zdWJtaXQoKTsKICAgICAgfQogICAgICBwb3B1cFdpbi5m
        b2N1cygpOwogICAgICByZXR1cm4gMDsKICAgIH0KICB9IGVsc2UgewogICAg
        cmV0dXJuIDE7CiAgfQp9CnNlbGYuZG9jdW1lbnQuZm9ybXMuZG93bmxvYWRm
        b3JtM0Quc3VibWl0KCk7Ci8vLS0+CjwvU0NSSVBUPgo=\n</HTML_ANSWER>
      </ncresponse>
    END
  end

  def failed_purchase_response
    <<-END
      <?xml version="1.0"?>
      <ncresponse
      orderID=""
      PAYID="0"
      NCSTATUS="5"
      NCERROR="50001111"
      NCERRORPLUS=" no orderid"
      ACCEPTANCE=""
      STATUS="0"
      amount=""
      currency="EUR"
      PM=""
      BRAND=""
      ALIAS="2">
      </ncresponse>
    END
  end

  def successful_capture_response
    <<-END
      <?xml version="1.0"?>
      <ncresponse
      orderID="1234956106974734203514539"
      PAYID="3048326"
      PAYIDSUB="1"
      NCSTATUS="0"
      NCERROR="0"
      NCERRORPLUS="!"
      ACCEPTANCE=""
      STATUS="91"
      amount="1"
      currency="EUR"
      ALIAS="2">
      </ncresponse>
    END
  end

  def successful_void_response
    <<-END
    <?xml version="1.0"?>
    <ncresponse
    orderID="1234961140253559268757474"
    PAYID="3048606"
    PAYIDSUB="1"
    NCSTATUS="0"
    NCERROR="0"
    NCERRORPLUS="!"
    ACCEPTANCE=""
    STATUS="61"
    amount="1"
    currency="EUR"
    ALIAS="2">
    </ncresponse>
    END
  end

  def successful_referenced_credit_response
    <<-END
    <?xml version="1.0"?>
    <ncresponse
    orderID="1234976251872867104376350"
    PAYID="3049652"
    PAYIDSUB="1"
    NCSTATUS="0"
    NCERROR="0"
    NCERRORPLUS="!"
    ACCEPTANCE=""
    STATUS="81"
    amount="1"
    currency="EUR"
    ALIAS="2">
    </ncresponse>
    END
  end

  def successful_unreferenced_credit_response
    <<-END
    <?xml version="1.0"?><ncresponse
    orderID="1234976330656672481134758"
    PAYID="3049654"
    NCSTATUS="0"
    NCERROR="0"
    NCERRORPLUS="!"
    ACCEPTANCE=""
    STATUS="81"
    IPCTY="99"
    CCCTY="99"
    ECI="7"
    CVCCheck="NO"
    AAVCheck="NO"
    VC="NO"
    amount="1"
    currency="EUR"
    PM="CreditCard"
    BRAND="VISA"
    ALIAS="2">
    </ncresponse>
    END
  end

  def test_failed_authorization_due_to_unknown_order_number
    <<-END
    <?xml version="1.0"?>
    <ncresponse
    orderID="#1019.22"
    PAYID="0"
    NCSTATUS="5"
    NCERROR="50001116"
    NCERRORPLUS="unknown order/1/i/67.192.100.64"
    ACCEPTANCE=""
    STATUS="0"
    amount=""
    currency="EUR"
    PM=""
    BRAND=""
    ALIAS="2">
    </ncresponse>
    END
  end

  def transcript
    <<-TRANSCRIPT
    CARDNO=4000100011112224&CN=Longbob+Longsen&COM=Store+Purchase&CVC=123&ECI=7&ED=0914&Operation=SAL&OwnerZip=K1C2N6&Owneraddress=1234+My+Street&PSPID=epdq1004895&PSWD=test&SHASign=0798F0F333C1867CC2B22D77E6452F8CAEFE9888&USERID=spreedly&amount=100&currency=GBP&orderID=b15d2f92e3ddee1a14b1b4b92cae9c&ownercty=CA&ownertelno=%28555%29555-5555&ownertown=Ottawa
    <?xml version="1.0"?><ncresponse
    orderID="b15d2f92e3ddee1a14b1b4b92cae9c"
    PAYID="22489229"
    NCSTATUS="0"
    NCERROR="0"
    ACCEPTANCE="test123"
    STATUS="9"
    amount="1"
    currency="GBP"
    PM="CreditCard"
    BRAND="VISA"
    NCERRORPLUS="!">
    </ncresponse>
    TRANSCRIPT
  end

  def scrubbed_transcript
    <<-SCRUBBED_TRANSCRIPT
    CARDNO=[FILTERED]&CN=Longbob+Longsen&COM=Store+Purchase&CVC=[FILTERED]&ECI=7&ED=0914&Operation=SAL&OwnerZip=K1C2N6&Owneraddress=1234+My+Street&PSPID=epdq1004895&PSWD=[FILTERED]&SHASign=0798F0F333C1867CC2B22D77E6452F8CAEFE9888&USERID=spreedly&amount=100&currency=GBP&orderID=b15d2f92e3ddee1a14b1b4b92cae9c&ownercty=CA&ownertelno=%28555%29555-5555&ownertown=Ottawa
    <?xml version="1.0"?><ncresponse
    orderID="b15d2f92e3ddee1a14b1b4b92cae9c"
    PAYID="22489229"
    NCSTATUS="0"
    NCERROR="0"
    ACCEPTANCE="test123"
    STATUS="9"
    amount="1"
    currency="GBP"
    PM="CreditCard"
    BRAND="VISA"
    NCERRORPLUS="!">
    </ncresponse>
    SCRUBBED_TRANSCRIPT
  end
end
