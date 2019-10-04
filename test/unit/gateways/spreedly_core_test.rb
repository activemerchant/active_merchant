require 'test_helper'

class SpreedlyCoreTest < Test::Unit::TestCase

  def setup
    @gateway = SpreedlyCoreGateway.new(:login => 'api_login', :password => 'api_secret', :gateway_token => 'token')
    @payment_method_token = 'E3eQGR3E0xiosj7FOJRtIKbF8Ch'

    @credit_card = credit_card
    @check = check
    @amount = 103
    @existing_transaction  = 'LKA3RchoqYO0njAfhHVw60ohjrC'
    @not_found_transaction = 'AdyQXaG0SVpSoMPdmFlvd3aA3uz'
  end

  def test_successful_purchase_with_payment_method_token
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @payment_method_token)

    assert_success response
    assert !response.test?

    assert_equal 'K1CRcdN0jK32UyrnZGPOXLRjqJl', response.authorization
    assert_equal 'Succeeded!', response.message
    assert_equal 'Non-U.S. issuing bank does not support AVS.', response.avs_result['message']
    assert_equal 'CVV failed data validation check', response.cvv_result['message']
  end

  def test_failed_purchase_with_payment_method_token
    @gateway.expects(:raw_ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @payment_method_token)

    assert_failure response
    assert !response.test?

    assert_equal 'Xh0T15CfYQeUqYV9Ixm8YV283Ds', response.authorization
    assert_equal 'This transaction cannot be processed.', response.message
    assert_equal '10762', response.params['response_error_code']
    assert_nil response.avs_result['message']
    assert_nil response.cvv_result['message']
  end

  def test_successful_purchase_with_credit_card
    @gateway.stubs(:raw_ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)

    assert_success response
    assert !response.test?

    assert_equal 'K1CRcdN0jK32UyrnZGPOXLRjqJl', response.authorization
    assert_equal 'Succeeded!', response.message
    assert_equal 'Non-U.S. issuing bank does not support AVS.', response.avs_result['message']
    assert_equal 'CVV failed data validation check', response.cvv_result['message']
    assert_equal 'Purchase', response.params['transaction_type']
    assert_equal '5WxC03VQ0LmmkYvIHl7XsPKIpUb', response.params['payment_method_token']
    assert_equal '6644', response.params['payment_method_last_four_digits']
    assert_equal 'used', response.params['payment_method_storage_state']
  end

  def test_successful_purchase_with_check
    @gateway.stubs(:raw_ssl_request).returns(successful_check_purchase_response)
    response = @gateway.purchase(@amount, @check)

    assert_success response
    assert !response.test?

    assert_equal 'ZwnfZs3Qy4gRDPWXHopamNuarCJ', response.authorization
    assert_equal 'Succeeded!', response.message
    assert_equal 'Purchase', response.params['transaction_type']
    assert_equal 'HtCrYfW17wEzWWfrMbwDX4TwPVW', response.params['payment_method_token']
    assert_equal '021*', response.params['payment_method_routing_number']
    assert_equal '*3210', response.params['payment_method_account_number']
  end

  def test_failed_purchase_with_invalid_credit_card
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal "First name can't be blank", response.message
  end

  def test_failed_purchase_with_credit_card
    @gateway.stubs(:raw_ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response

    assert_equal 'Xh0T15CfYQeUqYV9Ixm8YV283Ds', response.authorization
    assert_equal 'This transaction cannot be processed.', response.message
    assert_equal '10762', response.params['response_error_code']
    assert_nil response.avs_result['message']
    assert_nil response.cvv_result['message']
    assert_equal '0957', response.params['payment_method_last_four_digits']
  end

  def test_purchase_without_gateway_token_option
    @gateway.expects(:commit).with('gateways/token/purchase.xml', anything)
    @gateway.purchase(@amount, @payment_method_token)
  end

  def test_purchase_with_gateway_token_option
    @gateway.expects(:commit).with('gateways/mynewtoken/purchase.xml', anything)
    @gateway.purchase(@amount, @payment_method_token, gateway_token: 'mynewtoken')
  end

  def test_successful_authorize_with_token_and_capture
    @gateway.expects(:raw_ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)

    assert_success response
    assert !response.test?

    assert_equal 'NKz5SO6jrsRDc0UyaujwayXJZ1a', response.authorization
    assert_equal 'Succeeded!', response.message
    assert_equal 'Non-U.S. issuing bank does not support AVS.', response.avs_result['message']
    assert_equal 'CVV failed data validation check', response.cvv_result['message']

    @gateway.expects(:raw_ssl_request).returns(successful_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
    assert !response.test?

    assert_equal 'Bd1ZeztpPyjfXzfUa14BQGfaLmg', response.authorization
    assert_equal 'Succeeded!', response.message
    assert_nil response.avs_result['message']
    assert_nil response.cvv_result['message']
  end

  def test_failed_authorize_with_token
    @gateway.expects(:raw_ssl_request).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)
    assert_failure response
    assert_equal 'This transaction cannot be processed.', response.message
    assert_equal '10762', response.params['response_error_code']
    assert_nil response.avs_result['message']
    assert_nil response.cvv_result['message']
  end

  def test_successful_authorize_with_credit_card_and_capture
    @gateway.stubs(:raw_ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card)

    assert_success response
    assert !response.test?

    assert_equal 'NKz5SO6jrsRDc0UyaujwayXJZ1a', response.authorization
    assert_equal 'Succeeded!', response.message
    assert_equal 'Non-U.S. issuing bank does not support AVS.', response.avs_result['message']
    assert_equal 'CVV failed data validation check', response.cvv_result['message']
    assert_equal 'Authorization', response.params['transaction_type']
    assert_equal '5WxC03VQ0LmmkYvIHl7XsPKIpUb', response.params['payment_method_token']
    assert_equal '6644', response.params['payment_method_last_four_digits']
    assert_equal 'used', response.params['payment_method_storage_state']

    @gateway.expects(:raw_ssl_request).returns(successful_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
    assert_equal 'Bd1ZeztpPyjfXzfUa14BQGfaLmg', response.authorization
    assert_equal 'Succeeded!', response.message
  end

  def test_failed_authorize_with_credit_card
    @gateway.stubs(:raw_ssl_request).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card)
    assert_failure response
    assert_equal 'This transaction cannot be processed.', response.message
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
    assert_equal 'Amount specified exceeds allowable limit.', response.message
  end

  def test_successful_refund
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_refund_response)
    response = @gateway.refund(@amount, response.authorization)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal 'Credit', response.params['transaction_type']
  end

  def test_failed_refund
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(failed_refund_response)
    response = @gateway.refund(@amount + 20, response.authorization)
    assert_failure response
    assert_equal 'The partial refund amount must be less than or equal to the original transaction amount', response.message
    assert_equal '10009', response.params['response_error_code']
  end

  def test_successful_void
    @gateway.expects(:raw_ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_void_response)
    response = @gateway.void(response.authorization)
    assert_success response
    assert_equal 'Succeeded!', response.message
  end

  def test_failed_void
    @gateway.expects(:raw_ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @payment_method_token)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(failed_void_response)
    response = @gateway.void(response.authorization)
    assert_failure response
    assert_equal 'Authorization is voided.', response.message
    assert_equal '10600', response.params['response_error_code']
  end

  def test_successful_verify
    @gateway.expects(:raw_ssl_request).returns(successful_verify_response)
    response = @gateway.verify(@payment_method_token)
    assert_success response

    assert_equal 'Succeeded!', response.message
    assert_equal 'Verification', response.params['transaction_type']
  end

  def test_failed_verify
    @gateway.expects(:raw_ssl_request).returns(failed_verify_response)
    response = @gateway.verify(@payment_method_token)
    assert_failure response

    assert_equal 'Unable to process the verify transaction.', response.message
    assert_empty response.params['response_error_code']
  end

  def test_successful_store
    @gateway.expects(:raw_ssl_request).returns(successful_store_response)
    response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal 'Bml92ojQgsTf7bQ7z7WlwQVIdjr', response.authorization
    assert_equal 'true', response.params['retained']
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
    assert_equal 'Succeeded!', response.message
  end

  def test_successful_find
    @gateway.expects(:raw_ssl_request).returns(successful_find_response)
    response = @gateway.find(@existing_transaction)
    assert_success response

    assert_equal 'Succeeded!', response.message
    assert_equal 'LKA3RchoqYO0njAfhHVw60ohjrC', response.authorization
  end

  def test_failed_find
    @gateway.expects(:raw_ssl_request).returns(failed_find_response)
    response = @gateway.find(@not_found_transaction)
    assert_failure response

    assert_match %r(Unable to find the transaction), response.message
    assert_match %r(#{@not_found_transaction}), response.message
  end

  def test_scrubbing
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
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

  def successful_check_purchase_response
    MockResponse.succeeded <<-XML
      <transaction>
        <on_test_gateway type="boolean">false</on_test_gateway>
        <created_at type="dateTime">2019-01-06T18:24:33Z</created_at>
        <updated_at type="dateTime">2019-01-06T18:24:33Z</updated_at>
        <succeeded type="boolean">true</succeeded>
        <state>succeeded</state>
        <token>ZwnfZs3Qy4gRDPWXHopamNuarCJ</token>
        <transaction_type>Purchase</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <email nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <gateway_specific_fields nil="true"/>
        <gateway_specific_response_fields>
        </gateway_specific_response_fields>
        <gateway_transaction_id>49</gateway_transaction_id>
        <gateway_latency_ms type="integer">0</gateway_latency_ms>
        <amount type="integer">100</amount>
        <currency_code>USD</currency_code>
        <retain_on_success type="boolean">false</retain_on_success>
        <payment_method_added type="boolean">true</payment_method_added>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <gateway_token>3gLeg4726V5P0HK7cq7QzHsL0a6</gateway_token>
        <gateway_type>test</gateway_type>
        <shipping_address>
          <name nil="true"/>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
        </shipping_address>
        <response>
          <success type="boolean">true</success>
          <message>Successful purchase</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <pending type="boolean">false</pending>
          <result_unknown type="boolean">false</result_unknown>
          <error_code nil="true"/>
          <error_detail nil="true"/>
          <cancelled type="boolean">false</cancelled>
          <fraud_review nil="true"/>
          <created_at type="dateTime">2019-01-06T18:24:33Z</created_at>
          <updated_at type="dateTime">2019-01-06T18:24:33Z</updated_at>
        </response>
        <api_urls>
        </api_urls>
        <payment_method>
          <token>HtCrYfW17wEzWWfrMbwDX4TwPVW</token>
          <created_at type="dateTime">2019-01-06T18:24:33Z</created_at>
          <updated_at type="dateTime">2019-01-06T18:24:33Z</updated_at>
          <email nil="true"/>
          <data nil="true"/>
          <storage_state>cached</storage_state>
          <test type="boolean">true</test>
          <metadata nil="true"/>
          <full_name>Jim Smith</full_name>
          <bank_name nil="true"/>
          <account_type>checking</account_type>
          <account_holder_type>personal</account_holder_type>
          <routing_number_display_digits>021</routing_number_display_digits>
          <account_number_display_digits>3210</account_number_display_digits>
          <first_name>Jim</first_name>
          <last_name>Smith</last_name>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <company nil="true"/>
          <payment_method_type>bank_account</payment_method_type>
          <errors>
          </errors>
          <routing_number>021*</routing_number>
          <account_number>*3210</account_number>
        </payment_method>
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

  def pre_scrubbed
    <<-EOS
      opening connection to core.spreedly.com:443...
      opened
      starting SSL for core.spreedly.com:443...
      SSL established
      <- "POST /v1/payment_methods.xml HTTP/1.1\r\nContent-Type: text/xml\r\nAuthorization: Basic NFk5YlZrT0NwWWVzUFFPZkRpN1RYUXlVdzUwOlkyaTdBamdVMDNTVWp3WTR4bk9QcXpkc3Y0ZE1iUERDUXpvckFrOEJjb3kwVThFSVZFNGlubkdqdW9NUXY3TU4=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: core.spreedly.com\r\nContent-Length: 404\r\n\r\n"
      <- "<?xml version=\"1.0\"?>\n<payment_method>\n  <credit_card>\n    <number>5555555555554444</number>\n    <verification_value>123</verification_value>\n    <first_name>Longbob</first_name>\n    <last_name>Longsen</last_name>\n    <month>9</month>\n    <year>2019</year>\n    <email/>\n    <address1/>\n    <address2/>\n    <city/>\n    <state/>\n    <zip/>\n    <country/>\n  </credit_card>\n  <data></data>\n</payment_method>\n"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Sat, 10 Mar 2018 22:04:06 GMT\r\n"
      -> "Content-Type: application/xml; charset=utf-8\r\n"
      -> "Content-Length: 1875\r\n"
      -> "Connection: close\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "ETag: W/\"c4ef6dfc389a5514d6b6ffd8bac8786c\"\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "X-Request-Id: b227ok4du2hrj7mrtt10.core_dcaa82760687b3ef\r\n"
      -> "Server: nginx\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubdomains;\r\n"
      -> "\r\n"
      reading 1875 bytes...
      -> "<transaction>\n  <token>NRBpydUCWn658GHV8h2kVlUzB0i</token>\n  <created_at type=\"dateTime\">2018-03-10T22:04:06Z</created_at>\n  <updated_at type=\"dateTime\">2018-03-10T22:04:06Z</updated_at>\n  <succeeded type=\"boolean\">true</succeeded>\n  <transaction_type>AddPaymentMethod</transaction_type>\n  <retained type=\"boolean\">false</retained>\n  <state>succeeded</state>\n  <message key=\"messages.transaction_succeeded\">Succeeded!</message>\n  <payment_method>\n    <token>Wd25UIrH1uopTkZZ4UDdb5XmSDd</token>\n    <created_at type=\"dateTime\">2018-03-10T22:04:06Z</created_at>\n    <updated_at type=\"dateTime\">2018-03-10T22:04:06Z</updated_at>\n    <email nil=\"true\"/>\n    <data nil=\"true\"/>\n    <storage_state>cached</storage_state>\n    <test type=\"boolean\">true</test>\n    <last_four_digits>4444</last_four_digits>\n    <first_six_digits>555555</first_six_digits>\n    <card_type>master</card_type>\n    <first_name>Longbob</first_name>\n    <last_name>Longsen</last_name>\n    <month type=\"integer\">9</month>\n    <year type=\"integer\">2019</year>\n    <address1 nil=\"true\"/>\n    <address2 nil=\"true\"/>\n    <city nil=\"true\"/>\n    <state nil=\"true\"/>\n    <zip nil=\"true\"/>\n    <country nil=\"true\"/>\n    <phone_number nil=\"true\"/>\n    <company nil=\"true\"/>\n    <full_name>Longbob Longsen</full_name>\n    <eligible_for_card_updater type=\"boolean\">true</eligible_for_card_updater>\n    <shipping_address1 nil=\"true\"/>\n    <shipping_address2 nil=\"true\"/>\n    <shipping_city nil=\"true\"/>\n    <shipping_state nil=\"true\"/>\n    <shipping_zip nil=\"true\"/>\n    <shipping_country nil=\"true\"/>\n    <shipping_phone_number nil=\"true\"/>\n    <payment_method_type>credit_card</payment_method_type>\n    <errors>\n    </errors>\n    <verification_value>XXX</verification_value>\n    <number>XXXX-XXXX-XXXX-4444</number>\n    <fingerprint>125370bb396dff6fed4f581f85a91a9e5317</fingerprint>\n  </payment_method>\n</transaction>\n"
      read 1875 bytes
      Conn close
    EOS
  end

  def post_scrubbed
    <<-EOS
      opening connection to core.spreedly.com:443...
      opened
      starting SSL for core.spreedly.com:443...
      SSL established
      <- "POST /v1/payment_methods.xml HTTP/1.1\r\nContent-Type: text/xml\r\nAuthorization: Basic [FILTERED]=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: core.spreedly.com\r\nContent-Length: 404\r\n\r\n"
      <- "<?xml version=\"1.0\"?>\n<payment_method>\n  <credit_card>\n    <number>[FILTERED]</number>\n    <verification_value>[FILTERED]</verification_value>\n    <first_name>Longbob</first_name>\n    <last_name>Longsen</last_name>\n    <month>9</month>\n    <year>2019</year>\n    <email/>\n    <address1/>\n    <address2/>\n    <city/>\n    <state/>\n    <zip/>\n    <country/>\n  </credit_card>\n  <data></data>\n</payment_method>\n"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Sat, 10 Mar 2018 22:04:06 GMT\r\n"
      -> "Content-Type: application/xml; charset=utf-8\r\n"
      -> "Content-Length: 1875\r\n"
      -> "Connection: close\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "ETag: W/\"c4ef6dfc389a5514d6b6ffd8bac8786c\"\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "X-Request-Id: b227ok4du2hrj7mrtt10.core_dcaa82760687b3ef\r\n"
      -> "Server: nginx\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubdomains;\r\n"
      -> "\r\n"
      reading 1875 bytes...
      -> "<transaction>\n  <token>NRBpydUCWn658GHV8h2kVlUzB0i</token>\n  <created_at type=\"dateTime\">2018-03-10T22:04:06Z</created_at>\n  <updated_at type=\"dateTime\">2018-03-10T22:04:06Z</updated_at>\n  <succeeded type=\"boolean\">true</succeeded>\n  <transaction_type>AddPaymentMethod</transaction_type>\n  <retained type=\"boolean\">false</retained>\n  <state>succeeded</state>\n  <message key=\"messages.transaction_succeeded\">Succeeded!</message>\n  <payment_method>\n    <token>Wd25UIrH1uopTkZZ4UDdb5XmSDd</token>\n    <created_at type=\"dateTime\">2018-03-10T22:04:06Z</created_at>\n    <updated_at type=\"dateTime\">2018-03-10T22:04:06Z</updated_at>\n    <email nil=\"true\"/>\n    <data nil=\"true\"/>\n    <storage_state>cached</storage_state>\n    <test type=\"boolean\">true</test>\n    <last_four_digits>4444</last_four_digits>\n    <first_six_digits>555555</first_six_digits>\n    <card_type>master</card_type>\n    <first_name>Longbob</first_name>\n    <last_name>Longsen</last_name>\n    <month type=\"integer\">9</month>\n    <year type=\"integer\">2019</year>\n    <address1 nil=\"true\"/>\n    <address2 nil=\"true\"/>\n    <city nil=\"true\"/>\n    <state nil=\"true\"/>\n    <zip nil=\"true\"/>\n    <country nil=\"true\"/>\n    <phone_number nil=\"true\"/>\n    <company nil=\"true\"/>\n    <full_name>Longbob Longsen</full_name>\n    <eligible_for_card_updater type=\"boolean\">true</eligible_for_card_updater>\n    <shipping_address1 nil=\"true\"/>\n    <shipping_address2 nil=\"true\"/>\n    <shipping_city nil=\"true\"/>\n    <shipping_state nil=\"true\"/>\n    <shipping_zip nil=\"true\"/>\n    <shipping_country nil=\"true\"/>\n    <shipping_phone_number nil=\"true\"/>\n    <payment_method_type>credit_card</payment_method_type>\n    <errors>\n    </errors>\n    <verification_value>[FILTERED]</verification_value>\n    <number>[FILTERED]</number>\n    <fingerprint>125370bb396dff6fed4f581f85a91a9e5317</fingerprint>\n  </payment_method>\n</transaction>\n"
      read 1875 bytes
      Conn close
    EOS
  end

  def successful_verify_response
    MockResponse.succeeded <<-XML
      <transaction>
        <on_test_gateway type="boolean">true</on_test_gateway>
        <created_at type="dateTime">2018-02-24T00:47:56Z</created_at>
        <updated_at type="dateTime">2018-02-24T00:47:56Z</updated_at>
        <succeeded type="boolean">true</succeeded>
        <state>succeeded</state>
        <token>891hWyHKmfCggQQ7Q35sGVcEC01</token>
        <transaction_type>Verification</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <email nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <gateway_specific_fields nil="true"/>
        <gateway_specific_response_fields>
        </gateway_specific_response_fields>
        <gateway_transaction_id>67</gateway_transaction_id>
        <gateway_latency_ms type="integer">27</gateway_latency_ms>
        <currency_code>USD</currency_code>
        <retain_on_success type="boolean">false</retain_on_success>
        <payment_method_added type="boolean">false</payment_method_added>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <gateway_token>3gLeg4726V5P0HK7cq7QzHsL0a6</gateway_token>
        <gateway_type>test</gateway_type>
        <shipping_address>
          <name>Jim TesterDude</name>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
        </shipping_address>
        <response>
          <success type="boolean">true</success>
          <message>Successful verify</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <pending type="boolean">false</pending>
          <result_unknown type="boolean">false</result_unknown>
          <error_code></error_code>
          <error_detail nil="true"/>
          <cancelled type="boolean">false</cancelled>
          <fraud_review nil="true"/>
          <created_at type="dateTime">2018-02-24T00:47:56Z</created_at>
          <updated_at type="dateTime">2018-02-24T00:47:56Z</updated_at>
        </response>
        <payment_method>
          <token>9AjLflWs7SOKuqJLveOZya9bixa</token>
          <created_at type="dateTime">2012-12-07T19:08:15Z</created_at>
          <updated_at type="dateTime">2018-02-24T00:35:45Z</updated_at>
          <email nil="true"/>
          <data>
            <how_many>2</how_many>
          </data>
          <storage_state>retained</storage_state>
          <test type="boolean">true</test>
          <last_four_digits>4444</last_four_digits>
          <first_six_digits>555555</first_six_digits>
          <card_type>master</card_type>
          <first_name>Jim</first_name>
          <last_name>TesterDude</last_name>
          <month type="integer">9</month>
          <year type="integer">2022</year>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <company nil="true"/>
          <full_name>Jim TesterDude</full_name>
          <eligible_for_card_updater nil="true"/>
          <shipping_address1 nil="true"/>
          <shipping_address2 nil="true"/>
          <shipping_city nil="true"/>
          <shipping_state nil="true"/>
          <shipping_zip nil="true"/>
          <shipping_country nil="true"/>
          <shipping_phone_number nil="true"/>
          <payment_method_type>credit_card</payment_method_type>
          <errors>
          </errors>
          <verification_value></verification_value>
          <number>XXXX-XXXX-XXXX-4444</number>
          <fingerprint>125370bb396dff6fed4f581f85a91a9e5317</fingerprint>
        </payment_method>
      </transaction>
    XML
  end

  def failed_verify_response
    MockResponse.failed <<-XML
      <transaction>
        <on_test_gateway type="boolean">true</on_test_gateway>
        <created_at type="dateTime">2018-02-24T00:53:58Z</created_at>
        <updated_at type="dateTime">2018-02-24T00:53:58Z</updated_at>
        <succeeded type="boolean">false</succeeded>
        <state>gateway_processing_failed</state>
        <token>RwmpyTCRmCpji1YtSD5f5fQDpkS</token>
        <transaction_type>Verification</transaction_type>
        <order_id nil="true"/>
        <ip nil="true"/>
        <description nil="true"/>
        <email nil="true"/>
        <merchant_name_descriptor nil="true"/>
        <merchant_location_descriptor nil="true"/>
        <gateway_specific_fields nil="true"/>
        <gateway_specific_response_fields>
        </gateway_specific_response_fields>
        <gateway_transaction_id nil="true"/>
        <gateway_latency_ms type="integer">24</gateway_latency_ms>
        <currency_code>USD</currency_code>
        <retain_on_success type="boolean">false</retain_on_success>
        <payment_method_added type="boolean">false</payment_method_added>
        <message>Unable to process the verify transaction.</message>
        <gateway_token>3gLeg4726V5P0HK7cq7QzHsL0a6</gateway_token>
        <gateway_type>test</gateway_type>
        <shipping_address>
          <name>Longbob Longsen</name>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
        </shipping_address>
        <response>
          <success type="boolean">false</success>
          <message>Unable to process the verify transaction.</message>
          <avs_code nil="true"/>
          <avs_message nil="true"/>
          <cvv_code nil="true"/>
          <cvv_message nil="true"/>
          <pending type="boolean">false</pending>
          <result_unknown type="boolean">false</result_unknown>
          <error_code></error_code>
          <error_detail nil="true"/>
          <cancelled type="boolean">false</cancelled>
          <fraud_review nil="true"/>
          <created_at type="dateTime">2018-02-24T00:53:58Z</created_at>
          <updated_at type="dateTime">2018-02-24T00:53:58Z</updated_at>
        </response>
        <payment_method>
          <token>UzUKWHwI7GtZe3gz1UU5FiZ6DxH</token>
          <created_at type="dateTime">2018-02-24T00:53:56Z</created_at>
          <updated_at type="dateTime">2018-02-24T00:53:56Z</updated_at>
          <email nil="true"/>
          <data nil="true"/>
          <storage_state>cached</storage_state>
          <test type="boolean">true</test>
          <last_four_digits>1881</last_four_digits>
          <first_six_digits>401288</first_six_digits>
          <card_type>visa</card_type>
          <first_name>Longbob</first_name>
          <last_name>Longsen</last_name>
          <month type="integer">9</month>
          <year type="integer">2019</year>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <company nil="true"/>
          <full_name>Longbob Longsen</full_name>
          <eligible_for_card_updater nil="true"/>
          <shipping_address1 nil="true"/>
          <shipping_address2 nil="true"/>
          <shipping_city nil="true"/>
          <shipping_state nil="true"/>
          <shipping_zip nil="true"/>
          <shipping_country nil="true"/>
          <shipping_phone_number nil="true"/>
          <payment_method_type>credit_card</payment_method_type>
          <errors>
          </errors>
          <verification_value>XXX</verification_value>
          <number>XXXX-XXXX-XXXX-1881</number>
          <fingerprint>db33a42fcf2908a3795bd4ea881de2e0f015</fingerprint>
        </payment_method>
      </transaction>
    XML
  end

  def successful_find_response
    MockResponse.succeeded <<-XML
      <transaction>
        <token>LKA3RchoqYO0njAfhHVw60ohjrC</token>
        <created_at type="dateTime">2012-12-07T19:03:50Z</created_at>
        <updated_at type="dateTime">2012-12-07T19:03:50Z</updated_at>
        <succeeded type="boolean">true</succeeded>
        <transaction_type>AddPaymentMethod</transaction_type>
        <retained type="boolean">false</retained>
        <state>succeeded</state>
        <message key="messages.transaction_succeeded">Succeeded!</message>
        <payment_method>
          <token>67KlSyyvBAt9VUMJg3lUeWbBaWX</token>
          <created_at type="dateTime">2012-12-07T19:03:50Z</created_at>
          <updated_at type="dateTime">2017-07-29T23:25:21Z</updated_at>
          <email nil="true"/>
          <data>
            <how_many>2</how_many>
          </data>
          <storage_state>redacted</storage_state>
          <test type="boolean">false</test>
          <last_four_digits>4444</last_four_digits>
          <first_six_digits nil="true"/>
          <card_type>master</card_type>
          <first_name>Jim</first_name>
          <last_name>TesterDude</last_name>
          <month type="integer">9</month>
          <year type="integer">2022</year>
          <address1 nil="true"/>
          <address2 nil="true"/>
          <city nil="true"/>
          <state nil="true"/>
          <zip nil="true"/>
          <country nil="true"/>
          <phone_number nil="true"/>
          <company nil="true"/>
          <full_name>Jim TesterDude</full_name>
          <eligible_for_card_updater type="boolean">true</eligible_for_card_updater>
          <shipping_address1 nil="true"/>
          <shipping_address2 nil="true"/>
          <shipping_city nil="true"/>
          <shipping_state nil="true"/>
          <shipping_zip nil="true"/>
          <shipping_country nil="true"/>
          <shipping_phone_number nil="true"/>
          <payment_method_type>credit_card</payment_method_type>
          <errors>
          </errors>
          <verification_value></verification_value>
          <number></number>
          <fingerprint nil="true"/>
        </payment_method>
      </transaction>
    XML
  end

  def failed_find_response
    MockResponse.failed <<-XML
      <errors>
        <error key="errors.transaction_not_found">Unable to find the transaction AdyQXaG0SVpSoMPdmFlvd3aA3uz.</error>
      </errors>
    XML
  end
end
