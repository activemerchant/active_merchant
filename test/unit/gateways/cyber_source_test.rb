require 'test_helper'

class CyberSourceTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = CyberSourceGateway.new(
      :login => 'l',
      :password => 'p'
    )

    @amount = 100
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

  def test_successful_reference_purchase
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_purchase_response)

    assert_success(response = @gateway.store(@credit_card, @subscription_options))
    assert_success(response_reference_purchase = @gateway.purchase(@amount, response.authorization, @options))
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

    assert_success(response_refund = @gateway.refund(@amount, response.authorization))
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

  private

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
