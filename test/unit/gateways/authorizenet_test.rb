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
    #payload.to_xml(:ident => 0)
    payload
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
  end

  def test_avs_response_mapping
    response = {:transactionresponse_avsresultcode => 'Y'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'Y', avs_response.avs_result['code']
    assert avs_response.avs_result['street_match']
    assert avs_response.avs_result['postal_match']
    assert_equal 'Address (Street) and 5 digit ZIP match', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'A'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'A', avs_response.avs_result['code']
    assert avs_response.avs_result['street_match']
    assert !avs_response.avs_result['postal_match']
    assert_equal 'Address (Street) matches, ZIP does not', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'B'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'B', avs_response.avs_result['code']
    assert_nil avs_response.avs_result['street_match']
    assert_nil avs_response.avs_result['postal_match']
    assert_equal 'Address information not provided for AVS check', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'E'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'E', avs_response.avs_result['code']
    assert_nil avs_response.avs_result['street_match']
    assert_nil avs_response.avs_result['postal_match']
    assert_equal 'AVS error', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'G'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'G', avs_response.avs_result['code']
    assert_nil avs_response.avs_result['street_match']
    assert_nil avs_response.avs_result['postal_match']
    assert_equal 'Non-U.S. Card Issuing Bank', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'N'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'N', avs_response.avs_result['code']
    assert !avs_response.avs_result['street_match']
    assert !avs_response.avs_result['postal_match']
    assert_equal 'No Match on Address (Street) or ZIP', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'P'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'P', avs_response.avs_result['code']
    assert_nil avs_response.avs_result['street_match']
    assert_nil avs_response.avs_result['postal_match']
    assert_equal 'AVS not applicable for this transaction', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'R'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'R', avs_response.avs_result['code']
    assert_nil avs_response.avs_result['street_match']
    assert_nil avs_response.avs_result['postal_match']
    assert_equal 'Retry – System unavailable or timed out', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'S'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'S', avs_response.avs_result['code']
    assert_nil avs_response.avs_result['street_match']
    assert_nil avs_response.avs_result['postal_match']
    assert_equal 'Service not supported by issuer', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'U'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'U', avs_response.avs_result['code']
    assert_nil avs_response.avs_result['street_match']
    assert_nil avs_response.avs_result['postal_match']
    assert_equal 'Address information is unavailable', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'W'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'W', avs_response.avs_result['code']
    assert !avs_response.avs_result['street_match']
    assert avs_response.avs_result['postal_match']
    assert_equal '9 digit ZIP matches, Address (Street) does not', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'X'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'X', avs_response.avs_result['code']
    assert avs_response.avs_result['street_match']
    assert avs_response.avs_result['postal_match']
    assert_equal 'Address (Street) and 9 digit ZIP match', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'Y'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'Y', avs_response.avs_result['code']
    assert avs_response.avs_result['street_match']
    assert avs_response.avs_result['postal_match']
    assert_equal 'Address (Street) and 5 digit ZIP match', avs_response.avs_result['message']

    response = {:transactionresponse_avsresultcode => 'Z'}
    active_merchant_response = Response.new(true, 'test.')
    avs_response = @gateway.send(:build_avs_response, response, active_merchant_response)
    assert_equal 'Z', avs_response.avs_result['code']
    assert !avs_response.avs_result['street_match']
    assert avs_response.avs_result['postal_match']
    assert_equal '5 digit ZIP matches, Address (Street) does not', avs_response.avs_result['message']
  end

  def test_cvv_response_mapping
    response = {:transactionresponse_cvvresultcode => 'M'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_response = @gateway.send(:build_cvv_response, response, active_merchant_response)
    assert_equal 'M', cvv_response.cvv_result['code']
    assert_equal 'Match', cvv_response.cvv_result['message']

    response = {:transactionresponse_cvvresultcode => 'N'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_response = @gateway.send(:build_cvv_response, response, active_merchant_response)
    assert_equal 'N', cvv_response.cvv_result['code']
    assert_equal 'No Match', cvv_response.cvv_result['message']

    response = {:transactionresponse_cvvresultcode => 'P'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_response = @gateway.send(:build_cvv_response, response, active_merchant_response)
    assert_equal 'P', cvv_response.cvv_result['code']
    assert_equal 'Not Processed', cvv_response.cvv_result['message']

    response = {:transactionresponse_cvvresultcode => 'S'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_response = @gateway.send(:build_cvv_response, response, active_merchant_response)
    assert_equal 'S', cvv_response.cvv_result['code']
    assert_equal 'Should have been present', cvv_response.cvv_result['message']

    response = {:transactionresponse_cvvresultcode => 'U'}
    active_merchant_response = Response.new(true, 'test.')
    cvv_response = @gateway.send(:build_cvv_response, response, active_merchant_response)
    assert_equal 'U', cvv_response.cvv_result['code']
    assert_equal 'Issuer unable to process request', cvv_response.cvv_result['message']
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

    assert_equal  '%B378282246310005^LONGSON/LONGBOB^1705101130504392?', swipe_xml.doc.xpath('//track1').text
    assert_equal  '', swipe_xml.doc.xpath('//track2').text
  end

  def test_add_swipe_data_with_track_2
    @credit_card.track_data = ';4111111111111111=1803101000020000831?'
    swipe_xml = build_xml do |xml|
      @gateway.send(:add_swipe_data, xml, @credit_card)
    end

    assert_equal  ';4111111111111111=1803101000020000831?', swipe_xml.doc.xpath('//track2').text
    assert_equal  '', swipe_xml.doc.xpath('//track1').text
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

    assert_equal '2213759427', response.authorization
    assert response.test?
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  #TODO: these refund ones are particularly useful in that we can't get immediate turnaround on remote tests
  def test_successful_refund

  end

  def test_failed_refund
  end

  def test_successful_void
=begin
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.void(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'GSOFTZ', response.authorization
    assert response.test?


    assert void = @gateway.void(authorization.params['transaction_id'])
    assert_success void
    assert_equal 'This transaction has been approved.', void.message


    #taken from the generated remote test
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
=end
  end

  def test_failed_void
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
          <cvvResultCode>P</cvvResultCode>
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
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
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
