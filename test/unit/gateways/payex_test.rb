require 'test_helper'

class PayexTest < Test::Unit::TestCase
  def setup
    @gateway = PayexGateway.new(
                 :account => 'account',
                 :encryption_key => 'encryption_key'
               )

    @credit_card = credit_card
    @amount = 1000

    @options = {
      :order_id => '1234',
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_initialize_response, successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal '2623681', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_initialize_response, failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).times(2).returns(successful_initialize_response, successful_authorize_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert_equal 'OK', response.message
    assert_equal '2624653', response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, 'fakeauth')
    assert_success response
    assert_equal '2624655', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    assert response = @gateway.capture(@amount, '1')
    assert_failure response
    assert_not_equal 'OK', response.message
    assert_not_equal 'RecordNotFound', response.params[:status_errorcode]
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('fakeauth')
    assert_success response
    assert_equal '2624825', response.authorization
    assert response.test?
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(unsuccessful_void_response)
    assert response = @gateway.void("1")
    assert_failure response
    assert_not_equal 'OK', response.message
    assert_match /1/, response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(@amount - 200, 'fakeauth', order_id: '123')
    assert_success response
    assert_equal '2624828', response.authorization
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(unsuccessful_refund_response)
    assert response = @gateway.refund(@amount, "1", order_id: '123')
    assert_failure response
    assert_not_equal 'OK', response.message
    assert_match /1/, response.message
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_post).times(3).returns(successful_store_response, successful_initialize_response, successful_purchase_response)
    assert response = @gateway.store(@credit_card, @options.merge({merchant_ref: '9876'}))
    assert_success response
    assert_equal 'OK', response.message
    assert_equal 'bcea4ac8d1f44640bff7a8c93caa249c', response.authorization
    assert response.test?
  end

  def test_successful_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)
    assert response = @gateway.unstore('fakeauth')
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
  end

  def test_successful_purchase_with_stored_card
    @gateway.expects(:ssl_post).returns(successful_autopay_response)
    assert response = @gateway.purchase(@amount, 'fakeauth', @options.merge({order_id: '5678'}))
    assert_success response
    assert_equal 'OK', response.message
    assert_equal '2624657', response.authorization
    assert response.test?
  end

  private

  def successful_initialize_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <Initialize8Response xmlns="http://external.payex.com/PxOrder/">
            <Initialize8Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;09ef982cf2584d58bf4363dacd2ef127&lt;/id&gt;&lt;date&gt;2013-11-06 14:19:23&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;orderRef&gt;53681e74064a4621b93a6fcceba20c00&lt;/orderRef&gt;&lt;sessionRef&gt;7424a69d355c4cafa853ff49553b786f&lt;/sessionRef&gt;&lt;redirectUrl&gt;https://test-confined.payex.com/PxOrderCC.aspx?orderRef=53681e74064a4621b93a6fcceba20c00&lt;/redirectUrl&gt;&lt;/payex&gt;</Initialize8Result>
          </Initialize8Response>
        </soap:Body>
      </soap:Envelope>
    }
  end

  # Place raw successful response from gateway here
  def successful_purchase_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <PurchaseCCResponse xmlns="http://confined.payex.com/PxOrder/">
            <PurchaseCCResult>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;45eca449c8b54b54ac8811d4c26f638d&lt;/id&gt;&lt;date&gt;2013-11-06 14:19:35&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;/status&gt;&lt;transactionStatus&gt;0&lt;/transactionStatus&gt;&lt;transactionRef&gt;750dc1438350481086abd0438bde0c23&lt;/transactionRef&gt;&lt;transactionNumber&gt;2623681&lt;/transactionNumber&gt;&lt;orderId&gt;1234&lt;/orderId&gt;&lt;productId&gt;4321&lt;/productId&gt;&lt;paymentMethod&gt;VISA&lt;/paymentMethod&gt;&lt;productNumber&gt;4321&lt;/productNumber&gt;&lt;BankHash&gt;00000001-4581-0903-5682-000000000000&lt;/BankHash&gt;&lt;AuthenticatedStatus&gt;None&lt;/AuthenticatedStatus&gt;&lt;AuthenticatedWith&gt;N&lt;/AuthenticatedWith&gt;&lt;/payex&gt;</PurchaseCCResult>
          </PurchaseCCResponse>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def failed_purchase_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <PurchaseCCResponse xmlns="http://confined.payex.com/PxOrder/">
            <PurchaseCCResult>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;131faa4301f74e91bf29e9749ad8f2a6&lt;/id&gt;&lt;date&gt;2013-11-06 14:40:18&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;ValidationError_InvalidParameter&lt;/code&gt;&lt;errorCode&gt;ValidationError_InvalidParameter&lt;/errorCode&gt;&lt;description&gt;Invalid parameter:expireDate
      Parameter name: expireDate&lt;/description&gt;&lt;paramName&gt;expireDate&lt;/paramName&gt;&lt;thirdPartyError /&gt;&lt;/status&gt;&lt;/payex&gt;</PurchaseCCResult>
          </PurchaseCCResponse>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def successful_authorize_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <PurchaseCCResponse xmlns="http://confined.payex.com/PxOrder/">
            <PurchaseCCResult>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;41ebf6488fdb42a79baf49d2ef9e7dc6&lt;/id&gt;&lt;date&gt;2013-11-06 14:43:01&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;/status&gt;&lt;transactionStatus&gt;3&lt;/transactionStatus&gt;&lt;transactionRef&gt;89cbf30161f442228cbca16ff7f886d4&lt;/transactionRef&gt;&lt;transactionNumber&gt;2624653&lt;/transactionNumber&gt;&lt;orderId&gt;1234&lt;/orderId&gt;&lt;productId&gt;4321&lt;/productId&gt;&lt;paymentMethod&gt;VISA&lt;/paymentMethod&gt;&lt;productNumber&gt;4321&lt;/productNumber&gt;&lt;BankHash&gt;00000001-4581-0903-5682-000000000000&lt;/BankHash&gt;&lt;AuthenticatedStatus&gt;None&lt;/AuthenticatedStatus&gt;&lt;AuthenticatedWith&gt;N&lt;/AuthenticatedWith&gt;&lt;/payex&gt;</PurchaseCCResult>
          </PurchaseCCResponse>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def successful_capture_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <Capture5Response xmlns="http://external.payex.com/PxOrder/">
            <Capture5Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;efe1a4572c9b4ed5a656d648bf7f9207&lt;/id&gt;&lt;date&gt;2013-11-06 14:43:03&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;transactionStatus&gt;6&lt;/transactionStatus&gt;&lt;transactionNumber&gt;2624655&lt;/transactionNumber&gt;&lt;originalTransactionNumber&gt;2624653&lt;/originalTransactionNumber&gt;&lt;/payex&gt;</Capture5Result>
          </Capture5Response>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def failed_capture_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <Capture5Response xmlns="http://external.payex.com/PxOrder/">
            <Capture5Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;19706b063aad458aa9783563a4e5bbff&lt;/id&gt;&lt;date&gt;2013-11-06 14:53:34&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;ValidationError_Generic&lt;/code&gt;&lt;description&gt;1&lt;/description&gt;&lt;errorCode&gt;NoRecordFound&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;/payex&gt;</Capture5Result>
          </Capture5Response>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def successful_void_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <Cancel2Response xmlns="http://external.payex.com/PxOrder/">
            <Cancel2Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;219b3a4b4ae0478482c75eba06d5a0dd&lt;/id&gt;&lt;date&gt;2013-11-06 14:56:48&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;transactionStatus&gt;4&lt;/transactionStatus&gt;&lt;transactionNumber&gt;2624825&lt;/transactionNumber&gt;&lt;originalTransactionNumber&gt;2624824&lt;/originalTransactionNumber&gt;&lt;/payex&gt;</Cancel2Result>
          </Cancel2Response>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def unsuccessful_void_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <Cancel2Response xmlns="http://external.payex.com/PxOrder/">
            <Cancel2Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;220b395b966a43eb9d0c70109f6dadd3&lt;/id&gt;&lt;date&gt;2013-11-06 15:02:24&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;ValidationError_Generic&lt;/code&gt;&lt;description&gt;1&lt;/description&gt;&lt;errorCode&gt;Error_Generic&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;/payex&gt;</Cancel2Result>
          </Cancel2Response>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def successful_refund_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <Credit5Response xmlns="http://external.payex.com/PxOrder/">
            <Credit5Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;a1e70daf3ed842ddb72e58a28f5cbc11&lt;/id&gt;&lt;date&gt;2013-11-06 14:57:54&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;transactionStatus&gt;2&lt;/transactionStatus&gt;&lt;transactionNumber&gt;2624828&lt;/transactionNumber&gt;&lt;originalTransactionNumber&gt;2624827&lt;/originalTransactionNumber&gt;&lt;/payex&gt;</Credit5Result>
          </Credit5Response>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def unsuccessful_refund_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <Credit5Response xmlns="http://external.payex.com/PxOrder/">
            <Credit5Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;e82613f6c59d4e08a7163cd91c2b3ce5&lt;/id&gt;&lt;date&gt;2013-11-06 15:02:23&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;ValidationError_Generic&lt;/code&gt;&lt;description&gt;1&lt;/description&gt;&lt;errorCode&gt;Error_Generic&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;/payex&gt;</Credit5Result>
          </Credit5Response>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def successful_store_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <CreateAgreement3Response xmlns="http://external.payex.com/PxAgreement/">
            <CreateAgreement3Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;3c8063b7fcb64a449b715fe711f0a03f&lt;/id&gt;&lt;date&gt;2013-11-06 14:43:04&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;agreementRef&gt;bcea4ac8d1f44640bff7a8c93caa249c&lt;/agreementRef&gt;&lt;/payex&gt;</CreateAgreement3Result>
          </CreateAgreement3Response>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def successful_unstore_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <DeleteAgreementResponse xmlns="http://external.payex.com/PxAgreement/">
            <DeleteAgreementResult>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;7935ca4c24c3467cb36c48a270557194&lt;/id&gt;&lt;date&gt;2013-11-06 15:06:54&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;agreementRef&gt;7e9c6342dc20459691d1abb027a3c8c0&lt;/agreementRef&gt;&lt;/payex&gt;</DeleteAgreementResult>
          </DeleteAgreementResponse>
        </soap:Body>
      </soap:Envelope>
    }
  end

  def successful_autopay_response
    %q{<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <AutoPay3Response xmlns="http://external.payex.com/PxAgreement/">
            <AutoPay3Result>&lt;?xml version="1.0" encoding="utf-8" ?&gt;&lt;payex&gt;&lt;header name="Payex Header v1.0"&gt;&lt;id&gt;37a7164c16804af199b7d6aade0aa580&lt;/id&gt;&lt;date&gt;2013-11-06 14:43:09&lt;/date&gt;&lt;/header&gt;&lt;status&gt;&lt;code&gt;OK&lt;/code&gt;&lt;description&gt;OK&lt;/description&gt;&lt;errorCode&gt;OK&lt;/errorCode&gt;&lt;paramName /&gt;&lt;thirdPartyError /&gt;&lt;thirdPartySubError /&gt;&lt;/status&gt;&lt;transactionStatus&gt;3&lt;/transactionStatus&gt;&lt;transactionRef&gt;de2984e302da40b498afe5aced8cea7e&lt;/transactionRef&gt;&lt;transactionNumber&gt;2624657&lt;/transactionNumber&gt;&lt;paymentMethod&gt;VISA&lt;/paymentMethod&gt;&lt;captureTokens&gt;&lt;stan&gt;1337&lt;/stan&gt;&lt;terminalId&gt;666&lt;/terminalId&gt;&lt;transactionTime&gt;11/6/2013 2:43:09 PM&lt;/transactionTime&gt;&lt;/captureTokens&gt;&lt;pending&gt;false&lt;/pending&gt;&lt;/payex&gt;</AutoPay3Result>
          </AutoPay3Response>
        </soap:Body>
      </soap:Envelope>
    }
  end
end
