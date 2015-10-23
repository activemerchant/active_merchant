require 'test_helper'

class CyberSourceTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.gateway_mode = :test

    @gateway = CyberSourceGateway.new(
      :login => 'l',
      :password => 'p'
    )

    @amount = 100
    @customer_ip = '127.0.0.1'
    @credit_card = credit_card('4111111111111111', :brand => 'visa')
    @declined_card = credit_card('801111111111111', :brand => 'visa')
    @check = check()

    @options = { :billing_address => {
                  :address1 => '1234 My Street',
                  :address2 => 'Apt 1',
                  :company => 'Widgets Inc',
                  :city => 'Ottawa',
                  :state => 'ON',
                  :zip => 'K1C2N6',
                  :country => 'Canada',
                  :phone => '(555)555-5555'
               },

               :email => 'someguy1232@fakeemail.net',
               :ip => @customer_ip,
               :order_id => '1000',
               :line_items => [
                   {
                      :declared_value => @amount,
                      :quantity => 2,
                      :code => 'default',
                      :description => 'Giant Walrus',
                      :sku => 'WA323232323232323'
                   },
                   {
                      :declared_value => @amount,
                      :quantity => 2,
                      :description => 'Marble Snowcone',
                      :sku => 'FAKE1232132113123'
                   }
                 ],
          :currency => 'USD'
    }

    @subscription_options = {
      :order_id => generate_unique_id,
      :email => 'someguy1232@fakeemail.net',
      :credit_card => @credit_card,
      :setup_fee => 100,
      :billing_address => address,
      :subscription => {
        :frequency => "weekly",
        :start_date => Date.today.next_week,
        :occurrences => 4,
        :automatic_renew => true,
        :amount => 100
      }
    }
  end

  def test_successful_credit_card_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['requestID']};#{response.params['requestToken']}", response.authorization
    assert response.test?
  end

  def test_purchase_includes_customer_ip
    customer_ip_regexp = /<ipAddress>#{@customer_ip}<\//
    @gateway.expects(:ssl_post).
      with(anything, regexp_matches(customer_ip_regexp), anything).
      returns("")
    @gateway.expects(:parse).returns({})
    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_check_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @check, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['requestID']};#{response.params['requestToken']}", response.authorization
    assert response.test?
  end

  def test_successful_pinless_debit_card_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:pinless_debit_card => true))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['requestID']};#{response.params['requestToken']}", response.authorization
    assert response.test?
  end

  def test_successful_credit_cart_purchase_single_request_ignore_avs
    @gateway.expects(:ssl_post).with do |host, request_body|
      assert_match %r'<ignoreAVSResult>true</ignoreAVSResult>', request_body
      assert_not_match %r'<ignoreCVResult>', request_body
      true
    end.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(
      ignore_avs: true
    ))
    assert_success response
  end

  def test_successful_credit_cart_purchase_single_request_without_ignore_avs
    @gateway.expects(:ssl_post).with do |host, request_body|
      assert_not_match %r'<ignoreAVSResult>', request_body
      assert_not_match %r'<ignoreCVResult>', request_body
      true
    end.returns(successful_purchase_response)

    # globally ignored AVS for gateway instance:
    @gateway.options[:ignore_avs] = true

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(
      ignore_avs: false
    ))
    assert_success response
  end

  def test_successful_credit_cart_purchase_single_request_ignore_ccv
    @gateway.expects(:ssl_post).with do |host, request_body|
      assert_not_match %r'<ignoreAVSResult>', request_body
      assert_match %r'<ignoreCVResult>true</ignoreCVResult>', request_body
      true
    end.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(
      ignore_cvv: true
    ))
    assert_success response
  end

  def test_successful_credit_cart_purchase_single_request_without_ignore_ccv
    @gateway.expects(:ssl_post).with do |host, request_body|
      assert_not_match %r'<ignoreAVSResult>', request_body
      assert_not_match %r'<ignoreCVResult>', request_body
      true
    end.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(
      ignore_cvv: false
    ))
    assert_success response
  end

  def test_successful_reference_purchase
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_purchase_response)

    assert_success(response = @gateway.store(@credit_card, @subscription_options))
    assert_success(@gateway.purchase(@amount, response.authorization, @options))
    assert response.test?
  end

  def test_unsuccessful_authorization
    @gateway.expects(:ssl_post).returns(unsuccessful_authorization_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_auth_request
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal Response, response.class
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_tax_request
    @gateway.stubs(:ssl_post).returns(successful_tax_response)
    assert response = @gateway.calculate_tax(@credit_card, @options)
    assert_equal Response, response.class
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_capture_request
    @gateway.stubs(:ssl_post).returns(successful_authorization_response, successful_capture_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.success?
    assert response.test?
    assert response_capture = @gateway.capture(@amount, response.authorization)
    assert response_capture.success?
    assert response_capture.test?
  end

  def test_successful_credit_card_purchase_request
    @gateway.stubs(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.success?
    assert response.test?
  end

  def test_successful_check_purchase_request
    @gateway.stubs(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.purchase(@amount, @check, @options)
    assert response.success?
    assert response.test?
  end

  def test_requires_error_on_purchase_without_order_id
    assert_raise(ArgumentError){ @gateway.purchase(@amount, @credit_card, @options.delete_if{|key, val| key == :order_id}) }
  end

  def test_requires_error_on_authorization_without_order_id
    assert_raise(ArgumentError){ @gateway.purchase(@amount, @credit_card, @options.delete_if{|key, val| key == :order_id}) }
  end

  def test_requires_error_on_tax_calculation_without_line_items
    assert_raise(ArgumentError){ @gateway.calculate_tax(@credit_card, @options.delete_if{|key, val| key == :line_items})}
  end

  def test_default_currency
    assert_equal 'USD', CyberSourceGateway.default_currency
  end

  def test_successful_credit_card_store_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response)
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_update_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_update_subscription_response)
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
    assert response = @gateway.update(response.authorization, @credit_card, @subscription_options)
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_unstore_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_delete_subscription_response)
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
    assert response = @gateway.unstore(response.authorization, :order_id => generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_retrieve_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_retrieve_subscription_response)
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
    assert response = @gateway.retrieve(response.authorization, :order_id => generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_successful_refund_request
    @gateway.stubs(:ssl_post).returns(successful_capture_response, successful_refund_response)
    assert_success(response = @gateway.purchase(@amount, @credit_card, @options))

    assert_success(@gateway.refund(@amount, response.authorization))
  end

  def test_successful_credit_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_credit_response)

    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
    assert_success(@gateway.credit(@amount, response.authorization, @options))
  end

  def test_successful_auth_reversal_request
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.success?
    assert_success(@gateway.auth_reversal(@amount, response.authorization, @options))
  end

  def test_validate_pinless_debit_card_request
    @gateway.stubs(:ssl_post).returns(successful_validate_pinless_debit_card)
    assert response = @gateway.validate_pinless_debit_card(@credit_card, @options)
    assert response.success?
    assert_success(@gateway.auth_reversal(@amount, response.authorization, @options))
  end

  def test_validate_add_subscription_amount
    stub_comms do
      @gateway.store(@credit_card, @subscription_options)
    end.check_request do |endpoint, data, headers|
      assert_match %r(<grandTotalAmount>1.00<\/grandTotalAmount>), data
      assert_match %r(<amount>1.00<\/amount>), data
    end.respond_with(successful_update_subscription_response)
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response)
    assert_success response
  end

  def test_unsuccessful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(unsuccessful_authorization_response)
    assert_failure response
    assert_equal "Invalid account number", response.message
  end

  def test_successful_auth_with_network_tokenization_for_visa
    @gateway.expects(:ssl_post).with do |host, request_body|
      assert_match %r'<ccAuthService run=\"true\">\n  <cavv>111111111100cryptogram</cavv>\n  <commerceIndicator>vbv</commerceIndicator>\n  <xid>111111111100cryptogram</xid>\n</ccAuthService>\n<paymentNetworkToken>\n  <transactionType>1</transactionType>\n</paymentNetworkToken>', request_body
      true
    end.returns(successful_purchase_response)

    credit_card = network_tokenization_credit_card('4111111111111111',
      :brand              => 'visa',
      :transaction_id     => "123",
      :eci                => "05",
      :payment_cryptogram => "111111111100cryptogram"
    )

    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
  end

  def test_successful_auth_with_network_tokenization_for_mastercard
    @gateway.expects(:ssl_post).with do |host, request_body|
      assert_match %r'<ucaf>\n  <authenticationData>111111111100cryptogram</authenticationData>\n  <collectionIndicator>2</collectionIndicator>\n</ucaf>\n<ccAuthService run=\"true\">\n  <commerceIndicator>spa</commerceIndicator>\n</ccAuthService>\n<paymentNetworkToken>\n  <transactionType>1</transactionType>\n</paymentNetworkToken>', request_body
      true
    end.returns(successful_purchase_response)

    credit_card = network_tokenization_credit_card('5555555555554444',
      :brand              => 'mastercard',
      :transaction_id     => "123",
      :eci                => "05",
      :payment_cryptogram => "111111111100cryptogram"
    )

    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
  end

  def test_successful_auth_with_network_tokenization_for_amex
    @gateway.expects(:ssl_post).with do |host, request_body|
      assert_match %r'<ccAuthService run=\"true\">\n  <cavv>MTExMTExMTExMTAwY3J5cHRvZ3I=\n</cavv>\n  <commerceIndicator>aesk</commerceIndicator>\n  <xid>YW0=\n</xid>\n</ccAuthService>\n<paymentNetworkToken>\n  <transactionType>1</transactionType>\n</paymentNetworkToken>', request_body
      true
    end.returns(successful_purchase_response)

    credit_card = network_tokenization_credit_card('378282246310005',
      :brand              => 'american_express',
      :transaction_id     => "123",
      :eci                => "05",
      :payment_cryptogram => Base64.encode64("111111111100cryptogram")
    )

    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  def test_supports_network_tokenization
    assert_instance_of TrueClass, @gateway.supports_network_tokenization?
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
    opening connection to ics2wstest.ic3.com:443...
    opened
    starting SSL for ics2wstest.ic3.com:443...
    SSL established
    <- "POST /commerce/1.x/transactionProcessor HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ics2wstest.ic3.com\r\nContent-Length: 2459\r\n\r\n"
    <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <s:Header>\n    <wsse:Security s:mustUnderstand=\"1\" xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\">\n      <wsse:UsernameToken>\n        <wsse:Username>test</wsse:Username>\n        <wsse:Password Type=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText\">DT3MZm8t8BsDZC9ZoKl592lvlRbQCcEXmEcYlh3gZObo6zTLQdf2m5klbqXlTq31iTJ5/Ctl/Z5LFE60GFnWGR8Cn5GeXuToZNbMHAvZKZ3sw9tC3Hf4U3Dj8XS2EI4OBvA1jcw38hd3VEm0ZZCAQEDZCC+AnM2ya9417zqynYjwgSyPOfh6CfMlSJKTgxQJLot7jFxYNvM/s9yBZoh37wJZUXdZ9Bf/CH6O3tKzafbyfn5rK25+GeYN9koih4O8c+PLQepzj5miiR7bikFzgEnsVs6LaZdLM8Sx/XVXk+60h02lg/a6KdS3kmUvnTGOihg5JUnl2JucBpH/P4aQYZ==</wsse:Password>\n      </wsse:UsernameToken>\n    </wsse:Security>\n  </s:Header>\n  <s:Body xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n    <requestMessage xmlns=\"urn:schemas-cybersource-com:transaction-data-1.109\">\n      <merchantID>test</merchantID>\n      <merchantReferenceCode>734dda9bb6446f2f2638ab7faf34682f</merchantReferenceCode>\n      <clientLibrary>Ruby Active Merchant</clientLibrary>\n      <clientLibraryVersion>1.50.0</clientLibraryVersion>\n      <clientEnvironment>x86_64-darwin14.0</clientEnvironment>\n<billTo>\n  <firstName>Longbob</firstName>\n  <lastName>Longsen</lastName>\n  <street1>456 My Street</street1>\n  <street2>Apt 1</street2>\n  <city>Ottawa</city>\n  <state>NC</state>\n  <postalCode>K1C2N6</postalCode>\n  <country>US</country>\n  <company>Widgets Inc</company>\n  <phoneNumber>(555)555-5555</phoneNumber>\n  <email>someguy1232@fakeemail.net</email>\n</billTo>\n<shipTo>\n  <firstName>Longbob</firstName>\n  <lastName>Longsen</lastName>\n  <street1/>\n  <city/>\n  <state/>\n  <postalCode/>\n  <country/>\n  <email>someguy1232@fakeemail.net</email>\n</shipTo>\n<purchaseTotals>\n  <currency>USD</currency>\n  <grandTotalAmount>1.00</grandTotalAmount>\n</purchaseTotals>\n<card>\n  <accountNumber>4111111111111111</accountNumber>\n  <expirationMonth>09</expirationMonth>\n  <expirationYear>2016</expirationYear>\n  <cvNumber>123</cvNumber>\n  <cardType>001</cardType>\n</card>\n<ccAuthService run=\"true\"/>\n<ccCaptureService run=\"true\"/>\n<businessRules>\n  <ignoreAVSResult>true</ignoreAVSResult>\n  <ignoreCVResult>true</ignoreCVResult>\n</businessRules>\n    </requestMessage>\n  </s:Body>\n</s:Envelope>\n"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: Apache-Coyote/1.1\r\n"
    -> "X-OPNET-Transaction-Trace: pid=18901,requestid=08985faa-d84a-4200-af8a-1d0a4d50f391\r\n"
    -> "Set-Cookie: _op_aixPageId=a_233cede6-657e-481e-977d-a4a886dafd37; Path=/\r\n"
    -> "Content-Type: text/xml\r\n"
    -> "Content-Length: 1572\r\n"
    -> "Date: Fri, 05 Jun 2015 13:01:57 GMT\r\n"
    -> "Connection: close\r\n"
    -> "\r\n"
    reading 1572 bytes...
    -> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<soap:Header>\n<wsse:Security xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"><wsu:Timestamp xmlns:wsu=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\" wsu:Id=\"Timestamp-513448318\"><wsu:Created>2015-06-05T13:01:57.974Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c=\"urn:schemas-cybersource-com:transaction-data-1.109\"><c:merchantReferenceCode>734dda9bb6446f2f2638ab7faf34682f</c:merchantReferenceCode><c:requestID>4335093172165000001515</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSR1gMBn41YRu/WIkGLlo3asGzCbBky4VOjHT9/xXHSYBT9/xXHSbSA+RQkhk0ky3SA3+mwMCcjrAYDPxqwjd+sKWXL</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>888888</c:authorizationCode><c:avsCode>X</c:avsCode><c:avsCodeRaw>I1</c:avsCodeRaw><c:cvCode/><c:authorizedDateTime>2015-06-05T13:01:57Z</c:authorizedDateTime><c:processorResponse>100</c:processorResponse><c:reconciliationID>19475060MAIKBSQG</c:reconciliationID></c:ccAuthReply><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2015-06-05T13:01:57Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>19475060MAIKBSQG</c:reconciliationID></c:ccCaptureReply></c:replyMessage></soap:Body></soap:Envelope>"
    read 1572 bytes
    Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
    opening connection to ics2wstest.ic3.com:443...
    opened
    starting SSL for ics2wstest.ic3.com:443...
    SSL established
    <- "POST /commerce/1.x/transactionProcessor HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ics2wstest.ic3.com\r\nContent-Length: 2459\r\n\r\n"
    <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <s:Header>\n    <wsse:Security s:mustUnderstand=\"1\" xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\">\n      <wsse:UsernameToken>\n        <wsse:Username>test</wsse:Username>\n        <wsse:Password Type=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText\">[FILTERED]</wsse:Password>\n      </wsse:UsernameToken>\n    </wsse:Security>\n  </s:Header>\n  <s:Body xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n    <requestMessage xmlns=\"urn:schemas-cybersource-com:transaction-data-1.109\">\n      <merchantID>test</merchantID>\n      <merchantReferenceCode>734dda9bb6446f2f2638ab7faf34682f</merchantReferenceCode>\n      <clientLibrary>Ruby Active Merchant</clientLibrary>\n      <clientLibraryVersion>1.50.0</clientLibraryVersion>\n      <clientEnvironment>x86_64-darwin14.0</clientEnvironment>\n<billTo>\n  <firstName>Longbob</firstName>\n  <lastName>Longsen</lastName>\n  <street1>456 My Street</street1>\n  <street2>Apt 1</street2>\n  <city>Ottawa</city>\n  <state>NC</state>\n  <postalCode>K1C2N6</postalCode>\n  <country>US</country>\n  <company>Widgets Inc</company>\n  <phoneNumber>(555)555-5555</phoneNumber>\n  <email>someguy1232@fakeemail.net</email>\n</billTo>\n<shipTo>\n  <firstName>Longbob</firstName>\n  <lastName>Longsen</lastName>\n  <street1/>\n  <city/>\n  <state/>\n  <postalCode/>\n  <country/>\n  <email>someguy1232@fakeemail.net</email>\n</shipTo>\n<purchaseTotals>\n  <currency>USD</currency>\n  <grandTotalAmount>1.00</grandTotalAmount>\n</purchaseTotals>\n<card>\n  <accountNumber>[FILTERED]</accountNumber>\n  <expirationMonth>09</expirationMonth>\n  <expirationYear>2016</expirationYear>\n  <cvNumber>[FILTERED]</cvNumber>\n  <cardType>001</cardType>\n</card>\n<ccAuthService run=\"true\"/>\n<ccCaptureService run=\"true\"/>\n<businessRules>\n  <ignoreAVSResult>true</ignoreAVSResult>\n  <ignoreCVResult>true</ignoreCVResult>\n</businessRules>\n    </requestMessage>\n  </s:Body>\n</s:Envelope>\n"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: Apache-Coyote/1.1\r\n"
    -> "X-OPNET-Transaction-Trace: pid=18901,requestid=08985faa-d84a-4200-af8a-1d0a4d50f391\r\n"
    -> "Set-Cookie: _op_aixPageId=a_233cede6-657e-481e-977d-a4a886dafd37; Path=/\r\n"
    -> "Content-Type: text/xml\r\n"
    -> "Content-Length: 1572\r\n"
    -> "Date: Fri, 05 Jun 2015 13:01:57 GMT\r\n"
    -> "Connection: close\r\n"
    -> "\r\n"
    reading 1572 bytes...
    -> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<soap:Header>\n<wsse:Security xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"><wsu:Timestamp xmlns:wsu=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\" wsu:Id=\"Timestamp-513448318\"><wsu:Created>2015-06-05T13:01:57.974Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c=\"urn:schemas-cybersource-com:transaction-data-1.109\"><c:merchantReferenceCode>734dda9bb6446f2f2638ab7faf34682f</c:merchantReferenceCode><c:requestID>4335093172165000001515</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSR1gMBn41YRu/WIkGLlo3asGzCbBky4VOjHT9/xXHSYBT9/xXHSbSA+RQkhk0ky3SA3+mwMCcjrAYDPxqwjd+sKWXL</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>888888</c:authorizationCode><c:avsCode>X</c:avsCode><c:avsCodeRaw>I1</c:avsCodeRaw><c:cvCode/><c:authorizedDateTime>2015-06-05T13:01:57Z</c:authorizedDateTime><c:processorResponse>100</c:processorResponse><c:reconciliationID>19475060MAIKBSQG</c:reconciliationID></c:ccAuthReply><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2015-06-05T13:01:57Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>19475060MAIKBSQG</c:reconciliationID></c:ccCaptureReply></c:replyMessage></soap:Body></soap:Envelope>"
    read 1572 bytes
    Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Header>
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-2636690"><wsu:Created>2008-01-15T21:42:03.343Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>b0a6cf9aa07f1a8495f89c364bbd6a9a</c:merchantReferenceCode><c:requestID>2004333231260008401927</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Afvvj7Ke2Fmsbq0wHFE2sM6R4GAptYZ0jwPSA+R9PhkyhFTb0KRjoE4+ynthZrG6tMBwjAtT</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>123456</c:authorizationCode><c:avsCode>Y</c:avsCode><c:avsCodeRaw>Y</c:avsCodeRaw><c:cvCode>M</c:cvCode><c:cvCodeRaw>M</c:cvCodeRaw><c:authorizedDateTime>2008-01-15T21:42:03Z</c:authorizedDateTime><c:processorResponse>00</c:processorResponse><c:authFactorCode>U</c:authFactorCode></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Header>
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-32551101"><wsu:Created>2007-07-12T18:31:53.838Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>1842651133440156177166</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>004542</c:authorizationCode><c:avsCode>A</c:avsCode><c:avsCodeRaw>I7</c:avsCodeRaw><c:authorizedDateTime>2007-07-12T18:31:53Z</c:authorizedDateTime><c:processorResponse>100</c:processorResponse><c:reconciliationID>23439130C40VZ2FB</c:reconciliationID></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def unsuccessful_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Header>
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-28121162"><wsu:Created>2008-01-15T21:50:41.580Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>a1efca956703a2a5037178a8a28f7357</c:merchantReferenceCode><c:requestID>2004338415330008402434</c:requestID><c:decision>REJECT</c:decision><c:reasonCode>231</c:reasonCode><c:requestToken>Afvvj7KfIgU12gooCFE2/DanQIApt+G1OgTSA+R9PTnyhFTb0KRjgFY+ynyIFNdoKKAghwgx</c:requestToken><c:ccAuthReply><c:reasonCode>231</c:reasonCode></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_tax_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Header>
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-21248497"><wsu:Created>2007-07-11T18:27:56.314Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>1841784762620176127166</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AMYJY9fl62i+vx2OEQYAx9zv/9UBZAAA5h5D</c:requestToken><c:taxReply><c:reasonCode>100</c:reasonCode><c:grandTotalAmount>1.00</c:grandTotalAmount><c:totalCityTaxAmount>0</c:totalCityTaxAmount><c:city>Madison</c:city><c:totalCountyTaxAmount>0</c:totalCountyTaxAmount><c:totalDistrictTaxAmount>0</c:totalDistrictTaxAmount><c:totalStateTaxAmount>0</c:totalStateTaxAmount><c:state>WI</c:state><c:totalTaxAmount>0</c:totalTaxAmount><c:postalCode>53717</c:postalCode><c:item id="0"><c:totalTaxAmount>0</c:totalTaxAmount></c:item></c:taxReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_create_subscription_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-8747786"><wsu:Created>2008-10-14T20:36:38.467Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.32"><c:merchantReferenceCode>949c7098db10a846595ade653f7d259e</c:merchantReferenceCode><c:requestID>2240165983980008402433</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AhjzbwSP5cIxVhZHObgEUAU2LoPM+TpAfJAwQyXRR8hAdjiAmAAA6QCH</c:requestToken><c:paySubscriptionCreateReply><c:reasonCode>100</c:reasonCode><c:subscriptionID>2240165983980008402433</c:subscriptionID></c:paySubscriptionCreateReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_update_subscription_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-16655014"><wsu:Created>2008-10-15T19:56:27.676Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.32"><c:merchantReferenceCode>3050b9caff6f393730eebe9ccc450230</c:merchantReferenceCode><c:requestID>2241005875510008402434</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSP5fDQ6axlQ0gIUKsGLNo0at27OvXbxa82EwpWZLlNw4I85tgKbhwR5zb0gPkgYYZLoo+QgOxxDAnH8vhodNYyoaQEAAAA+QPT</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>123456</c:authorizationCode><c:avsCode>Y</c:avsCode><c:avsCodeRaw>Y</c:avsCodeRaw><c:cvCode>M</c:cvCode><c:cvCodeRaw>M</c:cvCodeRaw><c:authorizedDateTime>2008-10-15T19:56:27Z</c:authorizedDateTime><c:processorResponse>00</c:processorResponse><c:authFactorCode>U</c:authFactorCode></c:ccAuthReply><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2008-10-15T19:56:27Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>013445773WW7EWMB0RYI9</c:reconciliationID></c:ccCaptureReply><c:paySubscriptionCreateReply><c:reasonCode>100</c:reasonCode><c:subscriptionID>2241005875510008402434</c:subscriptionID></c:paySubscriptionCreateReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_delete_subscription_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-13372098"><wsu:Created>2012-03-24T02:53:45.725Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.63"><c:merchantReferenceCode>12345</c:merchantReferenceCode><c:requestID>3325576256890176056428</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AhijLwSRaI9Ig/eISVjYKJvvCSakcAQRwyaSZV0SpjMuAAAA+Al1</c:requestToken><c:paySubscriptionDeleteReply><c:reasonCode>100</c:reasonCode><c:subscriptionID>3325576252130176056442</c:subscriptionID></c:paySubscriptionDeleteReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_capture_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"> <soap:Header> <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-6000655"><wsu:Created>2007-07-17T17:15:32.642Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>test1111111111111111</c:merchantReferenceCode><c:requestID>1846925324700976124593</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AP4JZB883WKS/34BEZAzMTE1OTI5MVQzWE0wQjEzBTUt3wbOAQUy3D7oDgMMmvQAnQgl</c:requestToken><c:purchaseTotals><c:currency>GBP</c:currency></c:purchaseTotals><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2007-07-17T17:15:32Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>31159291T3XM2B13</c:reconciliationID></c:ccCaptureReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_refund_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Header>
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-5589339"><wsu:Created>2008-01-21T16:00:38.927Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.32"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>2009312387810008401927</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Af/vj7OzPmut/eogHFCrBiwYsWTJy1r127CpCn0KdOgyTZnzKwVYCmzPmVgr9ID5H1WGTSTKuj0i30IE4+zsz2d/QNzwBwAACCPA</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccCreditReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2008-01-21T16:00:38Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>010112295WW70TBOPSSP2</c:reconciliationID></c:ccCreditReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_credit_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Header>
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-5589339"><wsu:Created>2008-01-21T16:00:38.927Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.69"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>2009312387810008401927</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Af/vj7OzPmut/eogHFCrBiwYsWTJy1r127CpCn0KdOgyTZnzKwVYCmzPmVgr9ID5H1WGTSTKuj0i30IE4+zsz2d/QNzwBwAACCPA</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccCreditReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2012-09-28T16:59:25Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>010112295WW70TBOPSSP2</c:reconciliationID></c:ccCreditReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_retrieve_subscription_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-21454119"><wsu:Created>2012-05-15T14:29:52.833Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.69"><c:merchantReferenceCode>0da9f4799515bfbfb85cbf6ab8839cde</c:merchantReferenceCode><c:requestID>3370921927710176056428</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AhjzbwSRbXng4q9oFCjYIAKb7zXE/n0gAQsQyaSZV0ekrf+AaAAA+Q2H</c:requestToken><c:paySubscriptionRetrieveReply><c:reasonCode>100</c:reasonCode><c:approvalRequired>false</c:approvalRequired><c:automaticRenew>false</c:automaticRenew><c:cardAccountNumber>411111XXXXXX1111</c:cardAccountNumber><c:cardExpirationMonth>09</c:cardExpirationMonth><c:cardExpirationYear>2013</c:cardExpirationYear><c:cardType>001</c:cardType><c:city>Ottawa</c:city><c:companyName>Widgets Inc</c:companyName><c:country>CA</c:country><c:currency>USD</c:currency><c:email>someguy1232@fakeemail.net</c:email><c:endDate>99991231</c:endDate><c:firstName>JIM</c:firstName><c:frequency>on-demand</c:frequency><c:lastName>SMITH</c:lastName><c:paymentMethod>credit card</c:paymentMethod><c:paymentsRemaining>0</c:paymentsRemaining><c:postalCode>K1C2N6</c:postalCode><c:startDate>20120521</c:startDate><c:state>ON</c:state><c:status>CURRENT</c:status><c:street1>1234 My Street</c:street1><c:street2>Apt 1</c:street2><c:subscriptionID>3370921906250176056428</c:subscriptionID><c:totalPayments>0</c:totalPayments></c:paySubscriptionRetrieveReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_validate_pinless_debit_card
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Header>
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-190204278"><wsu:Created>2013-05-13T13:52:57.159Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.69"><c:merchantReferenceCode>6427013</c:merchantReferenceCode><c:requestID>3684531771310176056442</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AhijbwSRj3pM2QqPs2j0Ip+xoJXIsAMPYZNJMq6PSbs5ATAA6z42</c:requestToken><c:pinlessDebitValidateReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2013-05-13T13:52:57Z</c:requestDateTime><c:status>Y</c:status></c:pinlessDebitValidateReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end
end
