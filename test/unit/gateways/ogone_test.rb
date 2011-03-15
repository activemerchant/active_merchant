require 'test_helper'

# Allow us to test private method, required for the signature tests
class Class
  def publicize_methods
    saved_private_instance_methods = self.private_instance_methods
    self.class_eval { public *saved_private_instance_methods }
    yield
    self.class_eval { private *saved_private_instance_methods }
  end
end

class OgoneTest < Test::Unit::TestCase

  def setup
    @credentials = { :login => 'merchant id',
                     :user => 'username',
                     :password => 'password',
                     :signature => 'mynicesig',
                     :created_after_10_may_2010 => false }
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
    @parameters_3ds = {
      'FLAG3D' => 'Y',
      'WIN3DS' => 'MAINW',
      'HTTP_ACCEPT' => "*/*"
    }
  end

  def teardown
    Base.mode = :test
  end

  # Successful transactions

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '3014726;RES', response.authorization
    assert response.params['HTML_ANSWER'].nil?
    assert response.test?
  end

  def test_successful_3dsecure_authorize
    @gateway.expects(:ssl_post).returns(successful_3dsecure_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options.merge({ :flag_3ds => true }))
    assert_success response
    assert_equal '3014726;RES', response.authorization
    assert response.params['HTML_ANSWER']
    assert_equal nil, response.params['HTML_ANSWER'] =~ /<HTML_ANSWER>/
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


  # Unsuccessful transactions

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

  def test_signature_for_accounts_created_before_10_may_2010
    ActiveMerchant::Billing::OgoneGateway.publicize_methods do
      assert signature = @gateway.add_signature(@parameters)
      assert_equal Digest::SHA1.hexdigest("1100EUR4111111111111111MrPSPIDRES2mynicesig").upcase, signature
    end
  end

  def test_signature_for_accounts_created_before_10_may_2010_with_signature_encryptor_to_sha256
    ActiveMerchant::Billing::OgoneGateway.publicize_methods do
      gateway = OgoneGateway.new(@credentials.merge({ :signature_encryptor => 'sha256' }))
      assert signature = gateway.add_signature(@parameters)
      assert_equal Digest::SHA256.hexdigest("1100EUR4111111111111111MrPSPIDRES2mynicesig").upcase, signature
    end
  end

  def test_signature_for_accounts_created_before_10_may_2010_with_signature_encryptor_to_sha512
    ActiveMerchant::Billing::OgoneGateway.publicize_methods do
      gateway = OgoneGateway.new(@credentials.merge({ :signature_encryptor => 'sha512' }))
      assert signature = gateway.add_signature(@parameters)
      assert_equal Digest::SHA512.hexdigest("1100EUR4111111111111111MrPSPIDRES2mynicesig").upcase, signature
    end
  end

  def test_signature_for_accounts_created_after_10_may_2010
    ActiveMerchant::Billing::OgoneGateway.publicize_methods do
      gateway = OgoneGateway.new(@credentials.merge({ :created_after_10_may_2010 => true }))
      assert signature = gateway.add_signature(@parameters)
      assert_equal Digest::SHA1.hexdigest("ALIAS=2mynicesigAMOUNT=100mynicesigCARDNO=4111111111111111mynicesigCN=Client NamemynicesigCURRENCY=EURmynicesigOPERATION=RESmynicesigORDERID=1mynicesigPSPID=MrPSPIDmynicesig").upcase, signature
    end
  end

  def test_signature_for_accounts_created_after_10_may_2010_with_3dsecure
    ActiveMerchant::Billing::OgoneGateway.publicize_methods do
      gateway = OgoneGateway.new(@credentials.merge({ :created_after_10_may_2010 => true }))
      assert signature = gateway.add_signature(@parameters.merge(@parameters_3ds))
      assert_equal Digest::SHA1.hexdigest("ALIAS=2mynicesigAMOUNT=100mynicesigCARDNO=4111111111111111mynicesigCN=Client NamemynicesigCURRENCY=EURmynicesigFLAG3D=YmynicesigHTTP_ACCEPT=*/*mynicesigOPERATION=RESmynicesigORDERID=1mynicesigPSPID=MrPSPIDmynicesigWIN3DS=MAINWmynicesig").upcase, signature
    end
  end

  def test_signature_for_accounts_created_after_10_may_2010_with_signature_encryptor_to_sha256
    ActiveMerchant::Billing::OgoneGateway.publicize_methods do
      gateway = OgoneGateway.new(@credentials.merge({ :created_after_10_may_2010 => true, :signature_encryptor => 'sha256' }))
      assert signature = gateway.add_signature(@parameters)
      assert_equal Digest::SHA256.hexdigest("ALIAS=2mynicesigAMOUNT=100mynicesigCARDNO=4111111111111111mynicesigCN=Client NamemynicesigCURRENCY=EURmynicesigOPERATION=RESmynicesigORDERID=1mynicesigPSPID=MrPSPIDmynicesig").upcase, signature
    end
  end

  def test_signature_for_accounts_created_after_10_may_2010_with_signature_encryptor_to_sha512
    ActiveMerchant::Billing::OgoneGateway.publicize_methods do
      gateway = OgoneGateway.new(@credentials.merge({ :created_after_10_may_2010 => true, :signature_encryptor => 'sha512' }))
      assert signature = gateway.add_signature(@parameters)
      assert_equal Digest::SHA512.hexdigest("ALIAS=2mynicesigAMOUNT=100mynicesigCARDNO=4111111111111111mynicesigCN=Client NamemynicesigCURRENCY=EURmynicesigOPERATION=RESmynicesigORDERID=1mynicesigPSPID=MrPSPIDmynicesig").upcase, signature
    end
  end

  def test_accessing_params_attribute_of_response
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'test123', response.params['ACCEPTANCE']
    assert response.test?
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
        <HTML_ANSWER>PGZvcm0gbmFtZT0iZG93bmxvYWRmb3JtM0QiIGFjdGlvbj0iaHR0cHM6Ly9z\nZWN1cmUub2dvbmUuY29tL25jb2wvdGVzdC9UZXN0XzNEX0FDUy5hc3AiIG1l\ndGhvZD0icG9zdCI+CiAgPE5PU0NSSVBUPgogICAgSmF2YVNjcmlwdCBpcyBj\ndXJyZW50bHkgZGlzYWJsZWQgb3IgaXMgbm90IHN1cHBvcnRlZCBieSB5b3Vy\nIGJyb3dzZXIuPGJyPgogICAgUGxlYXNlIGNsaWNrIG9uIHRoZSAmcXVvdDtD\nb250aW51ZSZxdW90OyBidXR0b24gdG8gY29udGludWUgdGhlIHByb2Nlc3Np\nbmcgb2YgeW91ciAzLUQgc2VjdXJlIHRyYW5zYWN0aW9uLjxicj4KICAgIDxp\nbnB1dCBjbGFzcz0ibmNvbCIgdHlwZT0ic3VibWl0IiB2YWx1ZT0iQ29udGlu\ndWUiIGlkPSJzdWJtaXQxIiBuYW1lPSJzdWJtaXQxIiAvPgogIDwvTk9TQ1JJ\nUFQ+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iQ1NSRktFWSIgdmFs\ndWU9IjExMDc0NkE4QTExRTBDMEVGMUFDQjQ2NkY0MkU0RERBMDQ5QkZBNTgi\nIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iQ1NSRlRTIiB2YWx1\nZT0iMjAxMTAzMTUxNTA0MzEiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIg\nbmFtZT0iQ1NSRlNQIiB2YWx1ZT0iL25jb2wvdGVzdC9vcmRlcmRpcmVjdC5h\nc3AiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iUGFSZXEiIHZh\nbHVlPSI8P3htbCB2ZXJzaW9uPSZxdW90OzEuMCZxdW90Oz8+PFRocmVlRFNl\nY3VyZT48TWVzc2FnZSBpZD0mcXVvdDsxMjMmcXVvdDs+PFBBUmVxPjx2ZXJz\naW9uPjEuMDI8L3ZlcnNpb24+PE1lcmNoYW50PjxtZXJJRD5tZXJjaGFudF9u\nYW1lPC9tZXJJRD48bmFtZT5NZXJjaGFudDwvbmFtZT48dXJsPmh0dHA6Ly9t\nZXJjaGFudC5jb208L3VybD48L01lcmNoYW50PjxQdXJjaGFzZT48eGlkPjk2\nNTU4NDg8L3hpZD48YW1vdW50PjEuOTM8L2Ftb3VudD48cHVyY2hBbW91bnQ+\nMS45MzwvcHVyY2hBbW91bnQ+PGN1cnJlbmN5PlVTRDwvY3VycmVuY3k+PC9Q\ndXJjaGFzZT48Q0g+PGFjY3RJRD40MDAwMDAwMDAwMDAwMDAyPC9hY2N0SUQ+\nPGV4cGlyeT4wMzEyPC9leHBpcnk+PHNlbEJyYW5kPjwvc2VsQnJhbmQ+PC9D\nSD48L1BBUmVxPjwvTWVzc2FnZT48L1RocmVlRFNlY3VyZT4KICAiIC8+CiAg\nPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iVGVybVVybCIgdmFsdWU9Imh0\ndHBzOi8vc2VjdXJlLm9nb25lLmNvbS9uY29sL3Rlc3Qvb3JkZXJfQTNEUy5h\nc3AiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iTUQiIHZhbHVl\nPSJNQUlOV1BURVNUMDAwMDA5NjU1ODQ4MDExMTEiIC8+CjwvZm9ybT4KCjxm\nb3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSJodHRwczovL3NlY3VyZS5vZ29u\nZS5jb20vbmNvbC90ZXN0L29yZGVyX2FncmVlLmFzcCIgbmFtZT0idXBsb2Fk\nRm9ybTNEIj4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJDU1JGS0VZ\nIiB2YWx1ZT0iMEI2NDNEMDZFNTczQzkxRDBDQkQwOEY4RjlFREU4RjdDNDJD\nMjQ2OSIgLz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJDU1JGVFMi\nIHZhbHVlPSIyMDExMDMxNTE1MDQzMSIgLz4KICA8aW5wdXQgdHlwZT0iaGlk\nZGVuIiBuYW1lPSJDU1JGU1AiIHZhbHVlPSIvbmNvbC90ZXN0L29yZGVyZGly\nZWN0LmFzcCIgLz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJicmFu\nZGluZyIgdmFsdWU9Ik9nb25lIiAvPgogIDxpbnB1dCB0eXBlPSJoaWRkZW4i\nIG5hbWU9InBheWlkIiB2YWx1ZT0iOTY1NTg0OCIgLz4KICA8aW5wdXQgdHlw\nZT0iaGlkZGVuIiBuYW1lPSJzdG9yZWFsaWFzIiB2YWx1ZT0iIiAvPgogIDxp\nbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9Imhhc2hfcGFyYW0iIHZhbHVlPSJE\nNzY2NzhBRkE0MTBERjYxOUMzMkZGRUNFQTIzQTZGMkI1QkQxRDdBIiAvPgog\nIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9InhpZF8zRCIgdmFsdWU9IiIg\nLz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJzdGF0dXNfM0QiIHZh\nbHVlPSJYWCIgLz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJlY2lf\nM0QiIHZhbHVlPSIwIiAvPgogIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9\nImNhcmRudW1iZXIiIHZhbHVlPSIiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRl\nbiIgbmFtZT0iRWNvbV9QYXltZW50X0NhcmRfVmVyaWZpY2F0aW9uIiB2YWx1\nZT0iMTExIiAvPgogIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9IkNWQ0Zs\nYWciIHZhbHVlPSIxIiAvPgogIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9\nImNhdnZfM0QiIHZhbHVlPSIiIC8+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIg\nbmFtZT0iY2F2dmFsZ29yaXRobV8zRCIgdmFsdWU9IiIgLz4KICA8aW5wdXQg\ndHlwZT0iaGlkZGVuIiBuYW1lPSJzaWduYXR1cmVPS18zRCIgdmFsdWU9IiIg\nLz4KICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJoYXNoX3BhcmFtXzNE\nIiB2YWx1ZT0iODQzNDg3RDNEQzkyRkFDQ0FCMEZBQTRGMUM1NTYyMUFBMjhE\nQzk4OCIgLz4KPC9mb3JtPgo8U0NSSVBUIExBTkdVQUdFPSJKYXZhc2NyaXB0\nIiA+CjwhLS0KdmFyIHBvcHVwV2luOwp2YXIgc3VibWl0cG9wdXBXaW4gPSAw\nOwoKZnVuY3Rpb24gTG9hZFBvcHVwKCkgewogIGlmIChzZWxmLm5hbWUgPT0g\nbnVsbCkJewogICAgc2VsZi5uYW1lID0gIm9nb25lTWFpbiI7CiAgfQogIHBv\ncHVwV2luID0gd2luZG93Lm9wZW4oJ2Fib3V0OmJsYW5rJywgJ3BvcHVwV2lu\nJywgJ2hlaWdodD00MDAsIHdpZHRoPTM5MCwgc3RhdHVzPXllcywgZGVwZW5k\nZW50PW5vLCBzY3JvbGxiYXJzPXllcywgcmVzaXphYmxlPW5vJyk7CiAgaWYg\nKHBvcHVwV2luICE9IG51bGwpIHsKICAgIGlmICAoIXBvcHVwV2luIHx8IHBv\ncHVwV2luLmNsb3NlZCkgewogICAgICByZXR1cm4gMTsKICAgIH0gZWxzZSB7\nCiAgICAgIGlmICghcG9wdXBXaW4ub3BlbmVyIHx8IHBvcHVwV2luLm9wZW5l\nciA9PSBudWxsKSB7CiAgICAgICAgcG9wdXBXaW4ub3BlbmVyID0gc2VsZjsK\nICAgICAgfQogICAgICBzZWxmLmRvY3VtZW50LmZvcm1zLmRvd25sb2FkZm9y\nbTNELnRhcmdldCA9ICdwb3B1cFdpbic7CiAgICAgIGlmIChzdWJtaXRwb3B1\ncFdpbiA9PSAxKSB7CiAgICAgICAgc2VsZi5kb2N1bWVudC5mb3Jtcy5kb3du\nbG9hZGZvcm0zRC5zdWJtaXQoKTsKICAgICAgfQogICAgICBwb3B1cFdpbi5m\nb2N1cygpOwogICAgICByZXR1cm4gMDsKICAgIH0KICB9IGVsc2UgewogICAg\ncmV0dXJuIDE7CiAgfQp9CnNlbGYuZG9jdW1lbnQuZm9ybXMuZG93bmxvYWRm\nb3JtM0Quc3VibWl0KCk7Ci8vLS0+CjwvU0NSSVBUPgo=\n</HTML_ANSWER>
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