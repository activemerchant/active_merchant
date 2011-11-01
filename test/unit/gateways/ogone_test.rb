require 'test_helper'

class OgoneTest < Test::Unit::TestCase

  def setup
    @credentials = { :login => 'merchant id',
                     :user => 'username',
                     :password => 'password',
                     :signature => 'mynicesig' }
    @gateway = OgoneGateway.new(@credentials)
    @credit_card = credit_card
    @amount = 100
    @identification = "3014726"
    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def teardown
    Base.mode = :test
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '3014726;RES', response.authorization
    assert response.test?
  end

  def test_successful_purchase
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

  def test_successful_referenced_credit
    @gateway.expects(:ssl_post).returns(successful_referenced_credit_response)
    assert response = @gateway.credit(@amount, "3049652")
    assert_success response
    assert_equal '3049652;RFD', response.authorization
    assert response.test?
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

  def test_response_params_is_hash
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Hash, response.params
  end
  
  private

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
