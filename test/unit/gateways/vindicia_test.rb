require 'test_helper'
require 'vindicia-api'

class VindiciaTest < Test::Unit::TestCase
  def setup
    unless Vindicia.config.is_configured?
      schema = File.read(File.dirname(__FILE__) + '/../../schema/vindicia/Vindicia.xsd')
      response = Net::HTTPResponse.new('1.1', '200', 'OK')
      response.expects(:body).once.returns(schema)
      Vindicia.expects(:get_vindicia_file).once.returns(response)
    end

    @gateway = VindiciaGateway.new(
                 :login => 'login',
                 :password => 'password',
                 :account_id => 1
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :line_items => {
        :name => 'Test Product',
        :sku => 'TEST_PRODUCT',
        :price => 5,
        :quantity => 1
      }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response, successful_capture_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert response.authorization.include?(@options[:order_id])
    assert response.test?
  end

  def test_unsuccessful_authorize_status
    @gateway.expects(:ssl_post).once.returns(unsuccessful_authorize_response(:status => "Cancelled"))

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_authorize_avs
    @gateway.expects(:ssl_post).twice.returns(unsuccessful_authorize_response(:avs => "T"), successful_void_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_authorize_cvn
    @gateway.expects(:ssl_post).twice.returns(unsuccessful_authorize_response(:cvn => "N"), successful_void_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response, unsuccessful_capture_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_recurring_setup
    @gateway.expects(:ssl_post).times(3).returns(successful_authorize_response,
                                                 successful_capture_response,
                                                 successful_update_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, @credit_card, @options.merge(:product_sku => "TEST_SKU"))
    end
    assert_instance_of Response, response
    assert_success response

    assert response.authorization.include?(@options[:order_id])
    assert response.test?
  end

  def test_unsuccessful_recurring_setup
    @gateway.expects(:ssl_post).times(4).returns(successful_authorize_response,
                                                 successful_capture_response,
                                                 unsuccessful_update_response,
                                                 successful_void_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, @credit_card, @options.merge(:product_sku => "TEST_SKU"))
    end
    assert_failure response
    assert response.test?
  end

  private

  def successful_authorize_response
    <<-END
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:vin="http://soap.vindicia.com/v3_6/Vindicia"
          xmlns:xsd="http://www.w3.org/2001/XMLSchema"
          soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <authResponse xmlns="http://soap.vindicia.com/v3_6/Transaction">
            <return xmlns="" xsi:type="vin:Return">
              <returnCode xsi:type="vin:ReturnCode">200</returnCode>
              <soapId xsi:type="xsd:string">0f3f650ca1882fc5f15d83c8dd3f69838662491d</soapId>
              <returnString xsi:type="xsd:string">OK</returnString>
            </return>

            <transaction xmlns="" xsi:type="vin:Transaction">
              <merchantTransactionId xmlns="" xsi:type="xsd:string">#{@options[:order_id]}</merchantTransactionId>

              <statusLog xmlns="" xsi:type="vin:TransactionStatus">
                <status xmlns="" xsi:type="vin:TransactionStatusType">Authorized</status>
                <creditCardStatus xmlns="" xsi:type="vin:TransactionStatusCreditCard">
                  <authCode xmlns="" xsi:type="xsd:string">100</authCode>
                  <avsCode xmlns="" xsi:type="xsd:string">X</avsCode>
                  <cvnCode xmlns="" xsi:type="xsd:string">M</cvnCode>
                </creditCardStatus>
              </statusLog>

              <statusLog xmlns="" xsi:type="vin:TransactionStatus">
                <status xmlns="" xsi:type="vin:TransactionStatusType">New</status>
              </statusLog>
            </transaction>
          </authResponse>
        </soap:Body>
      </soap:Envelope>
    END
  end

  def unsuccessful_authorize_response(options = {})
    <<-END
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:vin="http://soap.vindicia.com/v3_6/Vindicia"
          xmlns:xsd="http://www.w3.org/2001/XMLSchema"
          soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <authResponse xmlns="http://soap.vindicia.com/v3_6/Transaction">
            <return xmlns="" xsi:type="vin:Return">
              <returnCode xsi:type="vin:ReturnCode">200</returnCode>
              <soapId xsi:type="xsd:string">0f3f650ca1882fc5f15d83c8dd3f69838662491d</soapId>
              <returnString xsi:type="xsd:string">OK</returnString>
            </return>

            <transaction xmlns="" xsi:type="vin:Transaction">
              <merchantTransactionId xmlns="" xsi:type="xsd:string">#{@options[:order_id]}</merchantTransactionId>

              <statusLog xmlns="" xsi:type="vin:TransactionStatus">
                <status xmlns="" xsi:type="vin:TransactionStatusType">#{options[:status] || "Authorized"}</status>
                <creditCardStatus xmlns="" xsi:type="vin:TransactionStatusCreditCard">
                  <authCode xmlns="" xsi:type="xsd:string">100</authCode>
                  <avsCode xmlns="" xsi:type="xsd:string">#{options[:avs] || "X"}</avsCode>
                  <cvnCode xmlns="" xsi:type="xsd:string">#{options[:cvn] || "M"}</cvnCode>
                </creditCardStatus>
              </statusLog>

              <statusLog xmlns="" xsi:type="vin:TransactionStatus">
                <status xmlns="" xsi:type="vin:TransactionStatusType">New</status>
              </statusLog>
            </transaction>
          </authResponse>
        </soap:Body>
      </soap:Envelope>
    END
  end

  def unsuccessful_capture_response
    <<-END
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:vin="http://soap.vindicia.com/v3_6/Vindicia"
          xmlns:xsd="http://www.w3.org/2001/XMLSchema"
          soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <captureResponse xmlns="http://soap.vindicia.com/v3_6/Transaction">
            <return xmlns="" xsi:type="vin:Return">
              <returnCode xsi:type="vin:ReturnCode">200</returnCode>

              <soapId xsi:type="xsd:string">f500e87cc8941c90310f31ef1de9684a3171fed6</soapId>

              <returnString xsi:type="xsd:string">Ok</returnString>
            </return>

            <qtySuccess xmlns="" xsi:type="xsd:int">0</qtySuccess>

            <qtyFail xmlns="" xsi:type="xsd:int">1</qtyFail>

            <results xmlns="" xsi:type="vin:CaptureResult">
              <returnCode xmlns="" xsi:type="xsd:int">400</returnCode>
              <merchantTransactionId xmlns="" xsi:type="xsd:string">#{@options[:order_id]}</merchantTransactionId>
            </results>
          </captureResponse>
        </soap:Body>
      </soap:Envelope>
    END
  end

  def successful_capture_response
    <<-END
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:vin="http://soap.vindicia.com/v3_6/Vindicia"
          xmlns:xsd="http://www.w3.org/2001/XMLSchema"
          soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <captureResponse xmlns="http://soap.vindicia.com/v3_6/Transaction">
            <return xmlns="" xsi:type="vin:Return">
              <returnCode xsi:type="vin:ReturnCode">200</returnCode>

              <soapId xsi:type="xsd:string">f500e87cc8941c90310f31ef1de9684a3171fed6</soapId>

              <returnString xsi:type="xsd:string">Ok</returnString>
            </return>

            <qtySuccess xmlns="" xsi:type="xsd:int">1</qtySuccess>

            <qtyFail xmlns="" xsi:type="xsd:int">0</qtyFail>

            <results xmlns="" xsi:type="vin:CaptureResult">
              <returnCode xmlns="" xsi:type="xsd:int">200</returnCode>
              <merchantTransactionId xmlns="" xsi:type="xsd:string">#{@options[:order_id]}</merchantTransactionId>
            </results>
          </captureResponse>
        </soap:Body>
      </soap:Envelope>
    END
  end
  # Not exactly the same, but very similar
  alias :successful_void_response :successful_capture_response

  def failed_purchase_response
    <<-END
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:vin="http://soap.vindicia.com/v3_6/Vindicia"
          xmlns:xsd="http://www.w3.org/2001/XMLSchema"
          soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <authResponse xmlns="http://soap.vindicia.com/v3_6/Transaction">
            <return xmlns="" xsi:type="vin:Return">
              <returnCode xsi:type="vin:ReturnCode">400</returnCode>
              <soapId xsi:type="xsd:string">e91e2caacf88e5c912eae8dbf354db8af053d20e</soapId>
              <returnString xsi:type="xsd:string">OK</returnString>
            </return>

            <transaction xmlns="" xsi:type="vin:Transaction">
              <merchantTransactionId xmlns="" xsi:type="xsd:string">R557887665</merchantTransactionId>
            </transaction>
          </authResponse>
        </soap:Body>
      </soap:Envelope>
    END
  end

  # AutoBill responses
  def successful_update_response
    <<-END
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:vin="http://soap.vindicia.com/v3_6/Vindicia"
          xmlns:xsd="http://www.w3.org/2001/XMLSchema"
          soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <updateResponse xmlns="http://soap.vindicia.com/v3_6/AutoBill">
            <return xmlns="" xsi:type="vin:Return">
              <returnCode xsi:type="vin:ReturnCode">200</returnCode>
              <soapId xsi:type="xsd:string">398ee6483a4b27dda94064cd67cf27464f6394eb</soapId>
              <returnString xsi:type="xsd:string">OK</returnString>
            </return>

            <autobill xmlns="" xsi:type="vin:AutoBill">
              <VID xmlns="" xsi:type="xsd:string">5857cab01a01a05939d1db9a8c63e3119254b405</VID>
              <merchantAutoBillId xmlns="" xsi:type="xsd:string">A#{@options[:order_id]}</merchantAutoBillId>
              <status xmlns="" xsi:type="vin:AutoBillStatus">Active</status>
              <startTimestamp xmlns="" xsi:type="xsd:dateTime">2011-05-13T10:32:23-07:00</startTimestamp>
              <endTimestamp xmlns="" xsi:type="xsd:dateTime">2011-05-15T10:32:23-07:00</endTimestamp>
            </autobill>

            <created xmlns="" xsi:type="xsd:boolean">1</created>
          </updateResponse>
        </soap:Body>
      </soap:Envelope>
    END
  end

  def unsuccessful_update_response
    <<-END
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:vin="http://soap.vindicia.com/v3_6/Vindicia"
          xmlns:xsd="http://www.w3.org/2001/XMLSchema"
          soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <updateResponse xmlns="http://soap.vindicia.com/v3_6/AutoBill">
            <return xmlns="" xsi:type="vin:Return">
              <returnCode xsi:type="vin:ReturnCode">200</returnCode>
              <soapId xsi:type="xsd:string">398ee6483a4b27dda94064cd67cf27464f6394eb</soapId>
              <returnString xsi:type="xsd:string">OK</returnString>
            </return>

            <autobill xmlns="" xsi:type="vin:AutoBill">
              <VID xmlns="" xsi:type="xsd:string">5857cab01a01a05939d1db9a8c63e3119254b405</VID>
              <merchantAutoBillId xmlns="" xsi:type="xsd:string">A#{@options[:order_id]}</merchantAutoBillId>
              <status xmlns="" xsi:type="vin:AutoBillStatus">Cancelled</status>
              <startTimestamp xmlns="" xsi:type="xsd:dateTime">2011-05-13T10:32:23-07:00</startTimestamp>
              <endTimestamp xmlns="" xsi:type="xsd:dateTime">2011-05-15T10:32:23-07:00</endTimestamp>
            </autobill>

            <created xmlns="" xsi:type="xsd:boolean">0</created>
          </updateResponse>
        </soap:Body>
      </soap:Envelope>
    END
  end
end
