require 'test_helper'

class AuthorizenetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizenetGateway.new(
        login: 'login',
        password: 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
        order_id: '1',
        billing_address: address,
        description: 'Store Purchase'
    }
  end

  def build_xml
    payload = Nokogiri::XML::Builder.new do |xml|
      xml.test {
        yield(xml)
      }
    end
    payload
  end

  def test_avs_response_mapping
    response = {:transactionresponse_avsresultcode => 'Y'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'Y', avs_result.code
    assert avs_result.street_match
    assert avs_result.postal_match
    assert_equal 'Street address and 5-digit postal code match.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'A'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'A', avs_result.code
    assert_equal 'Y', avs_result.street_match
    assert_equal 'N', avs_result.postal_match
    assert_equal 'Street address matches, but 5-digit and 9-digit postal code do not match.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'B'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'U', avs_result.code
    assert_nil avs_result.street_match
    assert_nil avs_result.postal_match
    assert_equal 'Address information unavailable.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'E'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'E', avs_result.code
    assert_nil avs_result.street_match
    assert_nil avs_result.postal_match
    assert_equal 'AVS data is invalid or AVS is not allowed for this card type.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'G'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'G', avs_result.code
    assert_equal 'X', avs_result.street_match
    assert_equal 'X', avs_result.postal_match
    assert_equal 'Non-U.S. issuing bank does not support AVS.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'N'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'C', avs_result.code
    assert_equal 'N', avs_result.street_match
    assert_equal 'N', avs_result.postal_match
    assert_equal 'Street address and postal code do not match.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'P'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'E', avs_result.code
    assert_nil avs_result.street_match
    assert_nil avs_result.postal_match
    assert_equal 'AVS data is invalid or AVS is not allowed for this card type.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'R'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'R', avs_result.code
    assert_nil avs_result.street_match
    assert_nil avs_result.postal_match
    assert_equal 'System unavailable.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'S'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'S', avs_result.code
    assert_equal 'X', avs_result.street_match
    assert_equal 'X', avs_result.postal_match
    assert_equal 'U.S.-issuing bank does not support AVS.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'U'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'U', avs_result.code
    assert_nil avs_result.street_match
    assert_nil avs_result.postal_match
    assert_equal 'Address information unavailable.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'W'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'W', avs_result.code
    assert_equal 'N', avs_result.street_match
    assert_equal 'Y', avs_result.postal_match
    assert_equal 'Street address does not match, but 9-digit postal code matches.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'X'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'X', avs_result.code
    assert_equal 'Y', avs_result.street_match
    assert_equal 'Y', avs_result.postal_match
    assert_equal 'Street address and 9-digit postal code match.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'Y'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'Y', avs_result.code
    assert_equal 'Y', avs_result.street_match
    assert_equal 'Y', avs_result.postal_match
    assert_equal 'Street address and 5-digit postal code match.', avs_result.message

    response = {:transactionresponse_avsresultcode => 'Z'}
    active_merchant_response = Response.new(true, 'test.')
    avs_result = @gateway.send(:build_avs_result, response)
    assert_equal 'Z', avs_result.code
    assert_equal 'N', avs_result.street_match
    assert_equal 'Y', avs_result.postal_match
    assert_equal 'Street address does not match, but 5-digit postal code matches.', avs_result.message
  end

  def test_cvv_response_mapping
    response = {:transactionresponse_cvvresultcode => 'M'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_result = @gateway.send(:build_cvv_result, response)
    assert_equal 'M', cvv_result.code
    assert_equal 'Match', cvv_result.message

    response = {:transactionresponse_cvvresultcode => 'N'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_result = @gateway.send(:build_cvv_result, response)
    assert_equal 'N', cvv_result.code
    assert_equal 'No Match', cvv_result.message

    response = {:transactionresponse_cvvresultcode => 'P'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_result = @gateway.send(:build_cvv_result, response)
    assert_equal 'P', cvv_result.code
    assert_equal 'Not Processed', cvv_result.message

    response = {:transactionresponse_cvvresultcode => 'S'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_result = @gateway.send(:build_cvv_result, response)
    assert_equal 'S', cvv_result.code
    assert_equal 'Should have been present', cvv_result.message

    response = {:transactionresponse_cvvresultcode => 'U'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_result = @gateway.send(:build_cvv_result, response)
    assert_equal 'U', cvv_result.code
    assert_equal 'Issuer unable to process request', cvv_result.message
  end

  def test_add_swipe_data_with_bad_data
    @credit_card.track_data = '%B378282246310005LONGSONLONGBOB1705101130504392?'
    swipe_xml = @gateway.send(:add_swipe_data, @xml, @credit_card)

    assert_equal nil, swipe_xml
  end

  def test_add_swipe_data_with_track_1
    @credit_card.track_data = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
    swipe_xml = build_xml do |xml|
      @gateway.send(:add_swipe_data, xml, @credit_card)
    end

    assert_equal '%B378282246310005^LONGSON/LONGBOB^1705101130504392?', swipe_xml.doc.xpath('//track1').text
    assert_equal '', swipe_xml.doc.xpath('//track2').text
  end

  def test_add_swipe_data_with_track_2
    @credit_card.track_data = ';4111111111111111=1803101000020000831?'
    swipe_xml = build_xml do |xml|
      @gateway.send(:add_swipe_data, xml, @credit_card)
    end

    assert_equal ';4111111111111111=1803101000020000831?', swipe_xml.doc.xpath('//track2').text
    assert_equal '', swipe_xml.doc.xpath('//track1').text
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '2213698343', response.authorization
    assert response.test?
    assert_equal 'Y', response.avs_result['code']
    assert response.avs_result['street_match']
    assert response.avs_result['postal_match']
    assert_equal 'Street address and 5-digit postal code match.', response.avs_result['message']
    assert_equal 'P', response.cvv_result['code']
    assert_equal 'Not Processed', response.cvv_result['message']
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'Match', response.cvv_result['message']

    assert_equal '2213759427', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    capture = @gateway.capture(@amount, 2214269051, @options)
    assert_success capture
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert capture = @gateway.capture(@amount, 1)
    assert_failure capture
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(36.40, @credit_card, 2214269051)
    assert_success refund
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(nil, nil, '')
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void(1)
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
  end

  private

  def successful_purchase_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId>1</refId>
      <messages>
        <resultCode>Ok</resultCode>
          <message>
          <code>I00001</code>
          <text>Successful.</text>
          </message>
      </messages>
      <transactionResponse>
        <responseCode>1</responseCode>
        <authCode>GSOFTZ</authCode>
        <avsResultCode>Y</avsResultCode>
        <cvvResultCode>P</cvvResultCode>
        <cavvResultCode>2</cavvResultCode>
        <transId>2213698343</transId>
          <refTransID/>
          <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>This transaction has been approved.</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_purchase_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>1234567</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The transaction was unsuccessful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>3</responseCode>
          <authCode/>
          <avsResultCode>P</avsResultCode>
          <cvvResultCode/>
          <cavvResultCode/>
          <transId>0</transId>
          <refTransID/>
          <transHash>7F9A0CB845632DCA5833D2F30ED02677</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0001</accountNumber>
          <accountType/>
          <errors>
            <error>
              <errorCode>6</errorCode>
              <errorText>The credit card number is invalid.</errorText>
            </error>
          </errors>
          <userFields>
            <userField>
              <name>MerchantDefinedFieldName1</name>
              <value>MerchantDefinedFieldValue1</value>
            </userField>
            <userField>
              <name>favorite_color</name>
              <value>blue</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_authorize_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>123456</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>1</responseCode>
          <authCode>A88MS0</authCode>
          <avsResultCode>Y</avsResultCode>
          <cvvResultCode>M</cvvResultCode>
          <cavvResultCode>2</cavvResultCode>
          <transId>2213759427</transId>
          <refTransID/>
          <transHash>D0EFF3F32E5ABD14A7CE6ADF32736D57</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0015</accountNumber>
          <accountType>MasterCard</accountType>
          <messages>
            <message>
              <code>1</code>
              <description>This transaction has been approved.</description>
            </message>
          </messages>
          <userFields>
            <userField>
              <name>MerchantDefinedFieldName1</name>
              <value>MerchantDefinedFieldValue1</value>
            </userField>
            <userField>
              <name>favorite_color</name>
              <value>blue</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_authorize_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>123456</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The transaction was unsuccessful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>3</responseCode>
          <authCode/>
          <avsResultCode>P</avsResultCode>
          <cvvResultCode/>
          <cavvResultCode/>
          <transId>0</transId>
          <refTransID/>
          <transHash>DA56E64108957174C5AE9BE466914741</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0001</accountNumber>
          <accountType/>
          <errors>
            <error>
              <errorCode>6</errorCode>
              <errorText>The credit card number is invalid.</errorText>
            </error>
          </errors>
          <userFields>
            <userField>
              <name>MerchantDefinedFieldName1</name>
              <value>MerchantDefinedFieldValue1</value>
            </userField>
            <userField>
              <name>favorite_color</name>
              <value>blue</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_capture_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema xmlns=AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId/>
      <messages>
        <resultCode>Ok</resultCode>
        <message>
          <code>I00001</code>
          <text>Successful.</text>
        </message>
      </messages>
      <transactionResponse>
      <responseCode>1</responseCode>
      <authCode>UTDVHP</authCode>
      <avsResultCode>P</avsResultCode>
      <cvvResultCode/>
      <cavvResultCode/>
      <transId>2214675515</transId>
      <refTransID>2214675515</refTransID>
      <transHash>6D739029E129D87F6CEFE3B3864F6D61</transHash>
      <testRequest>0</testRequest>
      <accountNumber>XXXX2224</accountNumber>
      <accountType>Visa</accountType>
      <messages>
        <message>
          <code>1</code>
          <description>This transaction has been approved.</description>
        </message>
      </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_capture_response
    <<-eos
      <createTransactionResponse xmlns:xsi=
                                 http://www.w3.org/2001/XMLSchema-instance xmlns:xsd=http://www.w3.org/2001/XMLSchema xmlns=AnetApi/xml/v1/schema/AnetApiSchema.xsd><refId/><messages>
      <resultCode>Error</resultCode>
      <message>
        <code>E00027</code>
        <text>The transaction was unsuccessful.</text>
      </message>
      </messages><transactionResponse>
      <responseCode>3</responseCode>
      <authCode/>
      <avsResultCode>P</avsResultCode>
      <cvvResultCode/>
      <cavvResultCode/>
      <transId>0</transId>
      <refTransID>23124</refTransID>
      <transHash>D99CC43D1B34F0DAB7F430F8F8B3249A</transHash>
      <testRequest>0</testRequest>
      <accountNumber/>
      <accountType/>
      <errors>
        <error>
          <errorCode>16</errorCode>
          <errorText>The transaction cannot be found.</errorText>
        </error>
      </errors>
      <shipTo/>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_refund_response
    <<-eos
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <messages>
        <resultCode>Ok</resultCode>
        <message>
          <code>I00001</code>
          <text>Successful.</text>
        </message>
      </messages>
      <transactionResponse>
        <responseCode>1</responseCode>
        <authCode/>
        <avsResultCode>P</avsResultCode>
        <cvvResultCode/>
        <cavvResultCode/>
        <transId>2214602071</transId>
        <refTransID>2214269051</refTransID>
        <transHash>A3E5982FB6789092985F2D618196A268</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>This transaction has been approved.</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_refund_response
    <<-eos
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <messages>
        <resultCode>Error</resultCode>
        <message>
          <code>E00027</code>
          <text>The transaction was unsuccessful.</text>
        </message>
      </messages>
      <transactionResponse>
        <responseCode>3</responseCode>
        <authCode/>
        <avsResultCode>P</avsResultCode>
        <cvvResultCode/>
        <cavvResultCode/>
        <transId>0</transId>
        <refTransID>2214269051</refTransID>
        <transHash>63E03F4968F0874E1B41FCD79DD54717</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <errors>
          <error>
            <errorCode>55</errorCode>
            <errorText>The sum of credits against the referenced transaction would exceed original debit amount.</errorText>
          </error>
        </errors>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_void_response
    <<-eos
    <?xml version="1.0" encoding="utf-8"?>
    <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                               xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
    <messages>
      <resultCode>Ok</resultCode>
      <message>
        <code>I00001</code>
        <text>Successful.</text>
      </message>
    </messages>
    <transactionResponse>
      <responseCode>1</responseCode>
      <authCode>GYEB3</authCode>
      <avsResultCode>P</avsResultCode>
      <cvvResultCode/>
      <cavvResultCode/>
      <transId>2213755822</transId>
      <refTransID>2213755822</refTransID>
      <transHash>3383BBB85FF98057D61B2D9B9A2DA79F</transHash>
      <testRequest>0</testRequest>
      <accountNumber>XXXX0015</accountNumber>
      <accountType>MasterCard</accountType>
      <messages>
        <message>
          <code>1</code>
          <description>This transaction has been approved.</description>
        </message>
      </messages>
    </transactionResponse>
    </createTransactionResponse>
    eos
  end

  def failed_void_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <messages>
        <resultCode>Error</resultCode>
        <message>
          <code>E00027</code>
          <text>The transaction was unsuccessful.</text>
        </message>
      </messages>
      <transactionResponse>
        <responseCode>3</responseCode>
        <authCode/>
        <avsResultCode>P</avsResultCode>
        <cvvResultCode/>
        <cavvResultCode/>
        <transId>0</transId>
        <refTransID>2213755821</refTransID>
        <transHash>39DC95085A313FEF7278C40EA8A66B16</transHash>
        <testRequest>0</testRequest>
        <accountNumber/>
        <accountType/>
        <errors>
          <error>
            <errorCode>16</errorCode>
            <errorText>The transaction cannot be found.</errorText>
          </error>
        </errors>
        <shipTo/>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end
end
