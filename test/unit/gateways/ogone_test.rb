require 'test_helper'

class OgoneTest < Test::Unit::TestCase

  def setup
    @credentials = { :login => 'pspid',
                     :user => 'username',
                     :password => 'password',
                     :signature => 'mynicesig',
                     :signature_encryptor => 'sha512' }
    @gateway = OgoneGateway.new(@credentials)
    @credit_card = credit_card
    @amount = 100
    @identification = "3014726"
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

  def test_successful_authorize
    @gateway.expects(:add_pair).at_least(1)
    @gateway.expects(:add_pair).with(anything, 'ECI', '7')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '3014726;RES', response.authorization
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

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, "3048326")
    assert_success response
    assert_equal '3048326;SAL', response.authorization
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
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
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
    assert_equal ['BE', 'DE', 'FR', 'NL', 'AT', 'CH'], OgoneGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro], OgoneGateway.supported_cardtypes
  end

  def test_default_currency
    assert_equal 'EUR', OgoneGateway.default_currency

    gateway = OgoneGateway.new(@credentials)
    gateway.expects(:add_pair).at_least(1)
    gateway.expects(:add_pair).with(anything, 'currency', 'EUR')
    gateway.expects(:ssl_post).returns(successful_purchase_response)
    gateway.purchase(@amount, @credit_card, @options)
  end

  def test_custom_currency_at_gateway_level
    gateway = OgoneGateway.new(@credentials.merge(:currency => 'USD'))
    gateway.expects(:add_pair).at_least(1)
    gateway.expects(:add_pair).with(anything, 'currency', 'USD')
    gateway.expects(:ssl_post).returns(successful_purchase_response)
    gateway.purchase(@amount, @credit_card, @options)
  end

  def test_local_custom_currency_overwrite_gateway_level
    gateway = OgoneGateway.new(@credentials.merge(:currency => 'USD'))
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

  def test_production_mode
    Base.mode = :production
    gateway = OgoneGateway.new(@credentials)
    assert !gateway.test?
  end

  def test_test_mode
    Base.mode = :production
    @credentials[:test] = true
    gateway = OgoneGateway.new(@credentials)
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
    gateway = OgoneGateway.new(@credentials.merge(:signature => nil))
    gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert_deprecation_warning(OgoneGateway::OGONE_NO_SIGNATURE_DEPRECATION_MESSAGE, gateway) do
      gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_signature_for_accounts_created_before_10_may_20101
    gateway = OgoneGateway.new(@credentials.merge(:signature_encryptor => nil))
    assert_deprecation_warning(OgoneGateway::OGONE_LOW_ENCRYPTION_DEPRECATION_MESSAGE, gateway) do
      assert signature = gateway.send(:add_signature, @parameters)
      assert_equal Digest::SHA1.hexdigest("1100EUR4111111111111111MrPSPIDRES2mynicesig").upcase, signature
    end
  end

  def test_signature_for_accounts_with_signature_encryptor_to_sha1
    gateway = OgoneGateway.new(@credentials.merge(:signature_encryptor => 'sha1'))

    assert_deprecation_warning(OgoneGateway::OGONE_LOW_ENCRYPTION_DEPRECATION_MESSAGE, gateway) do
      assert signature = gateway.send(:add_signature, @parameters)
      assert_equal Digest::SHA1.hexdigest(string_to_digest).upcase, signature
    end
  end

  def test_signature_for_accounts_with_signature_encryptor_to_sha256
    gateway = OgoneGateway.new(@credentials.merge(:signature_encryptor => 'sha256'))

    assert_deprecation_warning(OgoneGateway::OGONE_LOW_ENCRYPTION_DEPRECATION_MESSAGE, gateway) do
      assert signature = gateway.send(:add_signature, @parameters)
      assert_equal Digest::SHA256.hexdigest(string_to_digest).upcase, signature
    end
  end

  def test_signature_for_accounts_with_signature_encryptor_to_sha512
    gateway = OgoneGateway.new(@credentials.merge(:signature_encryptor => 'sha512'))
    assert signature = gateway.send(:add_signature, @parameters)
    assert_equal Digest::SHA512.hexdigest(string_to_digest).upcase, signature
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

  private

  def string_to_digest
    "ALIAS=2mynicesigAMOUNT=100mynicesigCARDNO=4111111111111111mynicesig"+
    "CN=Client NamemynicesigCURRENCY=EURmynicesigOPERATION=RESmynicesig"+
    "ORDERID=1mynicesigPSPID=MrPSPIDmynicesig"
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
        BRAND="VISA">
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
        BRAND="VISA">
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
      BRAND="">
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
      currency="EUR">
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
    currency="EUR">
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
    currency="EUR">
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
    BRAND="VISA">
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
    BRAND="">
    </ncresponse>
    END
  end

end
