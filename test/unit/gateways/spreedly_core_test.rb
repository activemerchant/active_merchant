require 'test_helper'

class SpreedlyCoreTest < Test::Unit::TestCase

  def setup
    @gateway = SpreedlyCoreGateway.new(:login => 'api_login', :password => 'api_secret', :gateway_token => 'token')
    @payment_method_token = 'E3eQGR3E0xiosj7FOJRtIKbF8Ch'

    @credit_card = credit_card
    @amount = 103
  end

  def test_successful_purchase_with_payment_method_token
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @payment_method_token)

    assert_success response
    assert !response.test?

    assert_equal "K1CRcdN0jK32UyrnZGPOXLRjqJl", response.authorization
    assert_equal "Succeeded!", response.message
    assert_equal "Non-U.S. issuing bank does not support AVS.", response.avs_result["message"]
    assert_equal "CVV failed data validation check", response.cvv_result["message"]
  end

  def test_failed_purchase_with_payment_method_token
    @gateway.expects(:raw_ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @payment_method_token)

    assert_failure response
    assert !response.test?

    assert_equal "Xh0T15CfYQeUqYV9Ixm8YV283Ds", response.authorization
    assert_equal "This transaction cannot be processed.", response.message
    assert_equal '10762', response.params['response_error_code']
    assert_nil response.avs_result['message']
    assert_nil response.cvv_result['message']
  end

  def test_successful_purchase_with_credit_card
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)

    assert_success response
    assert !response.test?

    assert_equal "K1CRcdN0jK32UyrnZGPOXLRjqJl", response.authorization
    assert_equal "Succeeded!", response.message
    assert_equal "Non-U.S. issuing bank does not support AVS.", response.avs_result["message"]
    assert_equal "CVV failed data validation check", response.cvv_result["message"]
    assert_equal 'Purchase', response.params['transaction_type']
    assert_equal '5WxC03VQ0LmmkYvIHl7XsPKIpUb', response.params['payment_method_token']
    assert_equal '6644', response.params['payment_method_last_four_digits']
    assert_equal 'used', response.params['payment_method_storage_state']
  end

  def test_failed_purchase_with_invalid_credit_card
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal "First name can't be blank", response.message
  end

  def test_failed_purchase_with_credit_card
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response

    assert_equal "Xh0T15CfYQeUqYV9Ixm8YV283Ds", response.authorization
    assert_equal "This transaction cannot be processed.", response.message
    assert_equal '10762', response.params['response_error_code']
    assert_nil response.avs_result['message']
    assert_nil response.cvv_result['message']
    assert_equal '0957', response.params['payment_method_last_four_digits']
  end

  def test_purchase_without_gateway_token_option
    @gateway.expects(:commit).with("gateways/token/purchase.xml", anything)
    @gateway.purchase(@amount, @payment_method_token)
  end

  def test_purchase_with_gateway_token_option
    @gateway.expects(:commit).with("gateways/mynewtoken/purchase.xml", anything)
    @gateway.purchase(@amount, @payment_method_token, gateway_token: 'mynewtoken')
  end

  def test_successful_authorize_with_token_and_capture
    @gateway.expects(:raw_ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)

    assert_success response
    assert !response.test?

    assert_equal "NKz5SO6jrsRDc0UyaujwayXJZ1a", response.authorization
    assert_equal "Succeeded!", response.message
    assert_equal "Non-U.S. issuing bank does not support AVS.", response.avs_result["message"]
    assert_equal "CVV failed data validation check", response.cvv_result["message"]

    @gateway.expects(:raw_ssl_request).returns(successful_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
    assert !response.test?

    assert_equal "Bd1ZeztpPyjfXzfUa14BQGfaLmg", response.authorization
    assert_equal "Succeeded!", response.message
    assert_nil response.avs_result['message']
    assert_nil response.cvv_result['message']
  end

  def test_failed_authorize_with_token
    @gateway.expects(:raw_ssl_request).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)
    assert_failure response
    assert_equal "This transaction cannot be processed.", response.message
    assert_equal '10762', response.params['response_error_code']
    assert_nil response.avs_result['message']
    assert_nil response.cvv_result['message']
  end

  def test_successful_authorize_with_credit_card_and_capture
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card)

    assert_success response
    assert !response.test?

    assert_equal "NKz5SO6jrsRDc0UyaujwayXJZ1a", response.authorization
    assert_equal "Succeeded!", response.message
    assert_equal "Non-U.S. issuing bank does not support AVS.", response.avs_result["message"]
    assert_equal "CVV failed data validation check", response.cvv_result["message"]
    assert_equal 'Authorization', response.params['transaction_type']
    assert_equal '5WxC03VQ0LmmkYvIHl7XsPKIpUb', response.params['payment_method_token']
    assert_equal '6644', response.params['payment_method_last_four_digits']
    assert_equal 'used', response.params['payment_method_storage_state']

    @gateway.expects(:raw_ssl_request).returns(successful_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
    assert_equal "Bd1ZeztpPyjfXzfUa14BQGfaLmg", response.authorization
    assert_equal "Succeeded!", response.message
  end

  def test_failed_authorize_with_credit_card
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card)
    assert_failure response
    assert_equal "This transaction cannot be processed.", response.message
    assert_equal '10762', response.params['response_error_code']
  end

  def test_failed_authorize_with_invalid_credit_card
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)
    response = @gateway.authorize(@amount, @credit_card)
    assert_failure response
    assert_equal "First name can't be blank", response.message
  end

  def test_failed_capture
    @gateway.expects(:raw_ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(failed_capture_response)
    response = @gateway.capture(@amount + 20, response.authorization)
    assert_failure response
    assert_equal "Amount specified exceeds allowable limit.", response.message
  end

  def test_successful_refund
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_refund_response)
    response = @gateway.refund(@amount, response.authorization)
    assert_success response
    assert_equal "Succeeded!", response.message
    assert_equal "Credit", response.params["transaction_type"]
  end

  def test_failed_refund
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(failed_refund_response)
    response = @gateway.refund(@amount + 20, response.authorization)
    assert_failure response
    assert_equal "The partial refund amount must be less than or equal to the original transaction amount", response.message
    assert_equal '10009', response.params['response_error_code']
  end

  def test_successful_void
    @gateway.expects(:raw_ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_void_response)
    response = @gateway.void(response.authorization)
    assert_success response
    assert_equal "Succeeded!", response.message
  end

  def test_failed_void
    @gateway.expects(:raw_ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(failed_void_response)
    response = @gateway.void(response.authorization)
    assert_failure response
    assert_equal "Authorization is voided.", response.message
    assert_equal '10600', response.params['response_error_code']
  end

  def test_successful_store
    @gateway.expects(:raw_ssl_request).returns(successful_store_response)
    response = @gateway.store(@credit_card)
    assert_success response
    assert_equal "Succeeded!", response.message
    assert_equal "Bml92ojQgsTf7bQ7z7WlwQVIdjr", response.authorization
    assert_equal "true", response.params["retained"]
  end

  def test_failed_store
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)
    response = @gateway.store(@credit_card)
    assert_failure response
    assert_equal "First name can't be blank", response.message
  end

  def test_successful_unstore
    @gateway.expects(:raw_ssl_request).returns(successful_store_response)
    response = @gateway.store(@credit_card)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_unstore_response)
    response = @gateway.unstore(response.authorization)
    assert_success response
    assert_equal "Succeeded!", response.message
  end


  private
  def successful_purchase_response
    MockResponse.succeeded <<-XML
      <transaction>
        <amount type="integer">103</amount>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-06T20:28:05Z</created_at>
        <updated_at type="datetime">2012-12-06T20:28:14Z</updated_at>
        <currency_code>USD</currency_code>
        <succeeded type="boolean">true</succeeded>
        <state>succeeded</state>
        <token>K1CRcdN0jK32UyrnZGPOXLRjqJl</token>
        <transaction_type>Purchase</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <response>
          <success type="boolean">true</success>
          <message>Success</message>
          <avs_code>G</avs_code>
          <avs_message>Non-U.S. issuing bank does not support AVS.</avs_message>
          <cvv_code>I</cvv_code>
          <cvv_message>CVV failed data validation check</cvv_message>
          <error_code nil="true"/>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-06T20:28:14Z</created_at>
          <updated_at type="datetime">2012-12-06T20:28:14Z</updated_at>
        </response>
        <payment_method>
          <token>5WxC03VQ0LmmkYvIHl7XsPKIpUb</token>
          <created_at type="datetime">2012-12-06T20:20:29Z</created_at>
          <updated_at type="datetime">2012-12-06T20:28:14Z</updated_at>
          <last_four_digits>6644</last_four_digits>
          <card_type>master</card_type>
          <first_name>Hello</first_name>
          <last_name>There</last_name>
          <month type="integer">3</month>
          <year type="integer">2015</year>
          <email nil="true"/>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <data>
            <how_many>2</how_many>
          </data>
          <storage_state>used</storage_state>
          <payment_method_type>credit_card</payment_method_type>
          <verification_value/>
          <number>XXXX-XXXX-XXXX-6644</number>
          <errors>
          </errors>
        </payment_method>
        <api_urls>
        </api_urls>
      </transaction>
    XML
  end

  def failed_purchase_response
    MockResponse.failed <<-XML
      <transaction>
        <amount type="integer">103</amount>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-07T16:02:58Z</created_at>
        <updated_at type="datetime">2012-12-07T16:02:59Z</updated_at>
        <currency_code>USD</currency_code>
        <succeeded type="boolean">false</succeeded>
        <state>gateway_processing_failed</state>
        <token>Xh0T15CfYQeUqYV9Ixm8YV283Ds</token>
        <transaction_type>Purchase</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <message>This transaction cannot be processed.</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <response>
          <success type="boolean">false</success>
          <message>This transaction cannot be processed.</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <error_code>10762</error_code>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-07T16:02:59Z</created_at>
          <updated_at type="datetime">2012-12-07T16:02:59Z</updated_at>
        </response>
        <payment_method>
          <token>U37T1uWPaRTqRnRnj8hJaNefiSL</token>
          <created_at type="datetime">2012-12-06T23:19:13Z</created_at>
          <updated_at type="datetime">2012-12-06T23:19:13Z</updated_at>
          <last_four_digits>0957</last_four_digits>
          <card_type>visa</card_type>
          <first_name>John</first_name>
          <last_name>Jones</last_name>
          <month type="integer">4</month>
          <year type="integer">2018</year>
          <email nil="true"/>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <data>
            <how_many>3</how_many>
          </data>
          <payment_method_type>credit_card</payment_method_type>
          <verification_value>XXX</verification_value>
          <number>XXXX-XXXX-XXXX-0957</number>
          <errors>
          </errors>
        </payment_method>
        <api_urls>
        </api_urls>
      </transaction>
    XML
  end

  def successful_authorize_response
    MockResponse.succeeded <<-XML
      <transaction>
        <amount type="integer">103</amount>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-08T04:13:39Z</created_at>
        <updated_at type="datetime">2012-12-08T04:13:48Z</updated_at>
        <currency_code>USD</currency_code>
        <succeeded type="boolean">true</succeeded>
        <state>succeeded</state>
        <token>NKz5SO6jrsRDc0UyaujwayXJZ1a</token>
        <transaction_type>Authorization</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <response>
          <success type="boolean">true</success>
          <message>Success</message>
          <avs_code>G</avs_code>
          <avs_message>Non-U.S. issuing bank does not support AVS.</avs_message>
          <cvv_code>I</cvv_code>
          <cvv_message>CVV failed data validation check</cvv_message>
          <error_code nil="true"/>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-08T04:13:48Z</created_at>
          <updated_at type="datetime">2012-12-08T04:13:48Z</updated_at>
        </response>
        <payment_method>
          <token>5WxC03VQ0LmmkYvIHl7XsPKIpUb</token>
          <created_at type="datetime">2012-12-06T20:20:29Z</created_at>
          <updated_at type="datetime">2012-12-08T04:13:48Z</updated_at>
          <last_four_digits>6644</last_four_digits>
          <card_type>master</card_type>
          <first_name>Hello</first_name>
          <last_name>There</last_name>
          <month type="integer">3</month>
          <year type="integer">2015</year>
          <email nil="true"/>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <data>
            <how_many>2</how_many>
          </data>
          <storage_state>used</storage_state>
          <payment_method_type>credit_card</payment_method_type>
          <verification_value/>
          <number>XXXX-XXXX-XXXX-6644</number>
          <errors>
          </errors>
        </payment_method>
        <api_urls>
        </api_urls>
      </transaction>
    XML
  end

  def successful_capture_response
    MockResponse.succeeded <<-XML
      <transaction>
        <amount type="integer">103</amount>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-08T04:16:21Z</created_at>
        <updated_at type="datetime">2012-12-08T04:16:24Z</updated_at>
        <currency_code>USD</currency_code>
        <succeeded type="boolean">true</succeeded>
        <state>succeeded</state>
        <token>Bd1ZeztpPyjfXzfUa14BQGfaLmg</token>
        <transaction_type>Capture</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <response>
          <success type="boolean">true</success>
          <message>Success</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <error_code nil="true"/>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-08T04:16:24Z</created_at>
          <updated_at type="datetime">2012-12-08T04:16:24Z</updated_at>
        </response>
        <reference_token>EHgw47v7B5XyhKuDlUtYtFnA4d0</reference_token>
        <api_urls>
        </api_urls>
      </transaction>
    XML
  end

  def failed_authorize_response
    MockResponse.failed <<-XML
      <transaction>
        <amount type="integer">103</amount>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-08T18:22:55Z</created_at>
        <updated_at type="datetime">2012-12-08T18:23:03Z</updated_at>
        <currency_code>USD</currency_code>
        <succeeded type="boolean">false</succeeded>
        <state>gateway_processing_failed</state>
        <token>HAzuUKTgohKN1jgyUOExSPYaE53</token>
        <transaction_type>Authorization</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <message>This transaction cannot be processed.</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <response>
          <success type="boolean">false</success>
          <message>This transaction cannot be processed.</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <error_code>10762</error_code>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-08T18:23:03Z</created_at>
          <updated_at type="datetime">2012-12-08T18:23:03Z</updated_at>
        </response>
        <payment_method>
          <token>U37T1uWPaRTqRnRnj8hJaNefiSL</token>
          <created_at type="datetime">2012-12-06T23:19:13Z</created_at>
          <updated_at type="datetime">2012-12-06T23:19:13Z</updated_at>
          <last_four_digits>0957</last_four_digits>
          <card_type>visa</card_type>
          <first_name>John</first_name>
          <last_name>Jones</last_name>
          <month type="integer">4</month>
          <year type="integer">2018</year>
          <email nil="true"/>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <data>
            <how_many>3</how_many>
          </data>
          <payment_method_type>credit_card</payment_method_type>
          <verification_value>XXX</verification_value>
          <number>XXXX-XXXX-XXXX-0957</number>
          <errors>
          </errors>
        </payment_method>
        <api_urls>
        </api_urls>
      </transaction>
    XML
  end

  def failed_capture_response
    MockResponse.failed <<-XML
      <transaction>
        <amount type="integer">123</amount>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-08T18:16:41Z</created_at>
        <updated_at type="datetime">2012-12-08T18:16:42Z</updated_at>
        <currency_code>USD</currency_code>
        <succeeded type="boolean">false</succeeded>
        <state>gateway_processing_failed</state>
        <token>BnxDs8ORBj6n9wh3JCjgsUnP0sG</token>
        <transaction_type>Capture</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <message>Amount specified exceeds allowable limit.</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <response>
          <success type="boolean">false</success>
          <message>Amount specified exceeds allowable limit.</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <error_code>10610</error_code>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-08T18:16:42Z</created_at>
          <updated_at type="datetime">2012-12-08T18:16:42Z</updated_at>
        </response>
        <reference_token>A9TkKYoFDaGXKJqsxFVlbhmwAls</reference_token>
        <api_urls>
        </api_urls>
      </transaction>
    XML
  end

  def failed_refund_response
    MockResponse.failed <<-XML
      <transaction>
        <amount type="integer">123</amount>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-10T17:30:25Z</created_at>
        <updated_at type="datetime">2012-12-10T17:30:26Z</updated_at>
        <currency_code>USD</currency_code>
        <succeeded type="boolean">false</succeeded>
        <state>gateway_processing_failed</state>
        <token>CsWm4kyfG9DkUQuldDVCqqIjqjN</token>
        <transaction_type>Credit</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <message>The partial refund amount must be less than or equal to the original transaction amount</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <response>
          <success type="boolean">false</success>
          <message>The partial refund amount must be less than or equal to the original transaction amount</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <error_code>10009</error_code>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-10T17:30:26Z</created_at>
          <updated_at type="datetime">2012-12-10T17:30:26Z</updated_at>
        </response>
        <reference_token>K1CRcdN0jK32UyrnZGPOXLRjqJl</reference_token>
        <api_urls>
        </api_urls>
      </transaction>
    XML
  end

  def successful_refund_response
    MockResponse.succeeded <<-XML
      <transaction>
        <amount type="integer">103</amount>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-10T17:35:22Z</created_at>
        <updated_at type="datetime">2012-12-10T17:35:24Z</updated_at>
        <currency_code>USD</currency_code>
        <succeeded type="boolean">true</succeeded>
        <state>succeeded</state>
        <token>YLGwgC6C54jAkoKxXCpPXHfYqFy</token>
        <transaction_type>Credit</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <response>
          <success type="boolean">true</success>
          <message>Success</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <error_code nil="true"/>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-10T17:35:24Z</created_at>
          <updated_at type="datetime">2012-12-10T17:35:24Z</updated_at>
        </response>
        <reference_token>K1CRcdN0jK32UyrnZGPOXLRjqJl</reference_token>
        <api_urls>
        </api_urls>
      </transaction>
    XML
  end

  def successful_void_response
    MockResponse.succeeded <<-XML
      <transaction>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-10T17:54:10Z</created_at>
        <updated_at type="datetime">2012-12-10T17:54:12Z</updated_at>
        <succeeded type="boolean">true</succeeded>
        <token>ZWBfwp53YtUszj0t1DqhFyikc4K</token>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <reference_token>NKz5SO6jrsRDc0UyaujwayXJZ1a</reference_token>
        <transaction_type>Void</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <response>
          <success type="boolean">true</success>
          <message>Success</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <error_code nil="true"/>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-10T17:54:12Z</created_at>
          <updated_at type="datetime">2012-12-10T17:54:12Z</updated_at>
        </response>
      </transaction>
    XML
  end

  def failed_void_response
    MockResponse.failed <<-XML
      <transaction>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="datetime">2012-12-10T19:14:43Z</created_at>
        <updated_at type="datetime">2012-12-10T19:14:50Z</updated_at>
        <succeeded type="boolean">false</succeeded>
        <token>3G2Va6PS0jsNlCJdYWZWcfhPFjh</token>
        <state>gateway_processing_failed</state>
        <message>Authorization is voided.</message>
        <gateway_token>6DgBCmHrNAPOgtYSjBsgT3R61mr</gateway_token>
        <reference_token>NKz5SO6jrsRDc0UyaujwayXJZ1a</reference_token>
        <transaction_type>Void</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <response>
          <success type="boolean">false</success>
          <message>Authorization is voided.</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <error_code>10600</error_code>
          <error_detail nil="true"/>
          <created_at type="datetime">2012-12-10T19:14:50Z</created_at>
          <updated_at type="datetime">2012-12-10T19:14:50Z</updated_at>
        </response>
      </transaction>
    XML
  end

  def successful_store_response
    MockResponse.succeeded <<-XML
      <transaction>
        <token>PgXuZ5YzLbPHewpYcXexDDvOpK2</token>
        <created_at type="datetime">2012-12-11T15:11:46Z</created_at>
        <updated_at type="datetime">2012-12-11T15:11:46Z</updated_at>
        <succeeded type="boolean">true</succeeded>
        <retained type="boolean">true</retained>
        <transaction_type>AddPaymentMethod</transaction_type>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <payment_method>
          <token>Bml92ojQgsTf7bQ7z7WlwQVIdjr</token>
          <created_at type="datetime">2012-12-11T15:11:46Z</created_at>
          <updated_at type="datetime">2012-12-11T15:11:46Z</updated_at>
          <last_four_digits>4444</last_four_digits>
          <card_type>master</card_type>
          <first_name>Longbob</first_name>
          <last_name>Longsen</last_name>
          <month type="integer">9</month>
          <year type="integer">2013</year>
          <email nil="true"/>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <data nil="true"/>
          <payment_method_type>credit_card</payment_method_type>
          <verification_value/>
          <number>XXXX-XXXX-XXXX-4444</number>
          <errors>
          </errors>
        </payment_method>
      </transaction>
    XML
  end

  def failed_store_response
    MockResponse.failed <<-XML
      <errors>
        <error attribute="first_name" key="errors.blank">First name can't be blank</error>
      </errors>
    XML
  end

  def successful_unstore_response
    MockResponse.failed <<-XML
      <transaction>
        <token>Ydpteng4vTNG37eulEbUvYIbuJC</token>
        <created_at type="datetime">2012-12-11T22:02:50Z</created_at>
        <updated_at type="datetime">2012-12-11T22:02:51Z</updated_at>
        <succeeded type="boolean">true</succeeded>
        <transaction_type>RedactPaymentMethod</transaction_type>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <payment_method>
          <token>LDtXpn3HmxpEZ3ZQI4bdw3wYreK</token>
          <created_at type="datetime">2012-12-11T22:02:50Z</created_at>
          <updated_at type="datetime">2012-12-11T22:02:51Z</updated_at>
          <last_four_digits>4444</last_four_digits>
          <card_type>master</card_type>
          <first_name>Longbob</first_name>
          <last_name>Longsen</last_name>
          <month type="integer">9</month>
          <year type="integer">2013</year>
          <email nil="true"/>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <data nil="true"/>
          <payment_method_type>credit_card</payment_method_type>
          <verification_value/>
          <number>XXXX-XXXX-XXXX-4444</number>
          <errors>
          </errors>
        </payment_method>
      </transaction>
    XML
  end

end
