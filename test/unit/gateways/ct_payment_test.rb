require 'test_helper'

class CtPaymentTest < Test::Unit::TestCase
  def setup
    @gateway = CtPaymentGateway.new(api_key: 'api_key', company_number: 'company number', merchant_number: 'merchant_number')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).twice.returns(successful_purchase_response, successful_ack_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '000007708972;443752  ;021efc336262;;', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response, successful_ack_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '000007708990;448572  ;0e7ebe0a804f;;', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).twice.returns(successful_capture_response, successful_ack_response)

    response = @gateway.capture(@amount, '000007708990;448572  ;0e7ebe0a804f;', @options)
    assert_success response

    assert_equal '000007708991;        ;0636aca3dd8e;;', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '0123456789asd;0123456789asdf;12345678', @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).twice.returns(successful_refund_response, successful_ack_response)

    response = @gateway.refund(@amount, '000007708990;448572  ;0e7ebe0a804f;', @options)
    assert_success response

    assert_equal '000007709004;        ;0a08f144b6ea;;', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.capture(@amount, '0123456789asd;0123456789asdf;12345678', @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('000007708990;448572  ;0e7ebe0a804f;', @options)
    assert_success response

    assert_equal '000007709013;        ;0de38871ce96;;', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('0123456789asd;0123456789asdf;12345678')
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).twice.returns(successful_verify_response, successful_ack_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal '000007709025;        ;0b882fe35f69;;', response.authorization
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).twice.returns(successful_credit_response, successful_ack_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response

    assert_equal '000007709063;        ;054902f2ded0;;', response.authorization
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to test.ctpaiement.ca:443...
      opened
      starting SSL for test.ctpaiement.ca:443...
      SSL established
      <- "POST /v1/purchase HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test.ctpaiement.ca\r\nContent-Length: 528\r\n\r\n"
      <- "auth-api-key=R46SNTJ42UCJ3264182Y0T087YHBA50RTK&payload=TWVyY2hhbnRUZXJtaW5hbE51bWJlcj0gICAgICZBbW91bnQ9MDAwMDAwMDAxMDAmT3BlcmF0b3JJRD0wMDAwMDAwMCZDdXJyZW5jeUNvZGU9VVNEJkludm9pY2VOdW1iZXI9MDYzZmI1MmMyOTc2JklucHV0VHlwZT1JJkxhbmd1YWdlQ29kZT1FJkNhcmRUeXBlPVYmQ2FyZE51bWJlcj00NTAxMTYxMTA3MjE3MjE0JkV4cGlyYXRpb25EYXRlPTA3MjAmQ2FyZEhvbGRlckFkZHJlc3M9NDU2IE15IFN0cmVldE90dGF3YSAgICAgICAgICAgICAgICAgIE9OJkNhcmRIb2xkZXJQb3N0YWxDb2RlPSAgIEsxQzJONiZDdXN0b21lck51bWJlcj0wMDAwMDAwMCZDb21wYW55TnVtYmVyPTAwNTg5Jk1lcmNoYW50TnVtYmVyPTUzNDAwMDMw"
      -> "HTTP/1.1 200 200\r\n"
      -> "Date: Fri, 29 Jun 2018 18:21:07 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=ISO-8859-1\r\n"
      -> "\r\n"
      -> "480\r\n"
      reading 1152 bytes...
      -> "{\"returnCode\":\"  00\",\"errorDescription\":null,\"authorizationNumber\":\"448186  \",\"referenceNumber\":\"          \",\"transactionNumber\":\"000007709037\",\"batchNumber\":\"0001\",\"terminalNumber\":\"13366\",\"serverNumber\":\"0001\",\"timeStamp\":\"20180629-14210749\",\"trxCode\":\"00\",\"merchantNumber\":\"53400030\",\"amount\":\"00000000100\",\"invoiceNumber\":\"063fb52c2976\",\"trxType\":\"C\",\"cardType\":\"V\",\"cardNumber\":\"450116XXXXXX7214                        \",\"expirationDate\":\"0720\",\"bankTerminalNumber\":\"53400188\",\"trxDate\":\"06292018\",\"trxTime\":\"142107\",\"accountType\":\"0\",\"trxMethod\":\"T@1\",\"languageCode\":\"E\",\"sequenceNumber\":\"000000000028\",\"receiptDisp\":\"       APPROVED-THANK YOU       \",\"terminalDisp\":\"APPROVED                \",\"operatorId\":\"00000000\",\"surchargeAmount\":\"\",\"companyNumber\":\"00589\",\"secureID\":\"\",\"cvv2Cvc2Status\":\" \",\"iopIssuerConfirmationNumber\":null,\"iopIssuerName\":null,\"avsStatus\":null,\"holderName\":null,\"threeDSStatus\":null,\"emvLabel\":null,\"emvAID\":null,\"emvTVR\":null,\"emvTSI\":null,\"emvTC\":null,\"demoMode\":null,\"terminalInvoiceNumber\":null,\"cashbackAmount\":null,\"tipAmount\":null,\"taxAmount\":null,\"cvmResults\":null,\"token\":null,\"customerNumber\":null,\"email\":\"\"}"
      read 1152 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to test.ctpaiement.ca:443...
      opened
      starting SSL for test.ctpaiement.ca:443...
      SSL established
      <- "POST /v1/ack HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test.ctpaiement.ca\r\nContent-Length: 156\r\n\r\n"
      <- "auth-api-key=R46SNTJ42UCJ3264182Y0T087YHBA50RTK&payload=VHJhbnNhY3Rpb25OdW1iZXI9MDAwMDA3NzA5MDM3JkNvbXBhbnlOdW1iZXI9MDA1ODkmTWVyY2hhbnROdW1iZXI9NTM0MDAwMzA="
      -> "HTTP/1.1 200 200\r\n"
      -> "Date: Fri, 29 Jun 2018 18:21:08 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=ISO-8859-1\r\n"
      -> "\r\n"
      -> "15\r\n"
      reading 21 bytes...
      -> "{\"returnCode\":\"true\"}"
      read 21 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to test.ctpaiement.ca:443...
      opened
      starting SSL for test.ctpaiement.ca:443...
      SSL established
      <- "POST /v1/purchase HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test.ctpaiement.ca\r\nContent-Length: 528\r\n\r\n"
      <- "auth-api-key=[FILTERED]&payload=[FILTERED]"
      -> "HTTP/1.1 200 200\r\n"
      -> "Date: Fri, 29 Jun 2018 18:21:07 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=ISO-8859-1\r\n"
      -> "\r\n"
      -> "480\r\n"
      reading 1152 bytes...
      -> "{\"returnCode\":\"  00\",\"errorDescription\":null,\"authorizationNumber\":\"448186  \",\"referenceNumber\":\"          \",\"transactionNumber\":\"000007709037\",\"batchNumber\":\"0001\",\"terminalNumber\":\"13366\",\"serverNumber\":\"0001\",\"timeStamp\":\"20180629-14210749\",\"trxCode\":\"00\",\"merchantNumber\":\"53400030\",\"amount\":\"00000000100\",\"invoiceNumber\":\"063fb52c2976\",\"trxType\":\"C\",\"cardType\":\"V\",\"cardNumber\":\"450116XXXXXX7214                        \",\"expirationDate\":\"0720\",\"bankTerminalNumber\":\"53400188\",\"trxDate\":\"06292018\",\"trxTime\":\"142107\",\"accountType\":\"0\",\"trxMethod\":\"T@1\",\"languageCode\":\"E\",\"sequenceNumber\":\"000000000028\",\"receiptDisp\":\"       APPROVED-THANK YOU       \",\"terminalDisp\":\"APPROVED                \",\"operatorId\":\"00000000\",\"surchargeAmount\":\"\",\"companyNumber\":\"00589\",\"secureID\":\"\",\"cvv2Cvc2Status\":\" \",\"iopIssuerConfirmationNumber\":null,\"iopIssuerName\":null,\"avsStatus\":null,\"holderName\":null,\"threeDSStatus\":null,\"emvLabel\":null,\"emvAID\":null,\"emvTVR\":null,\"emvTSI\":null,\"emvTC\":null,\"demoMode\":null,\"terminalInvoiceNumber\":null,\"cashbackAmount\":null,\"tipAmount\":null,\"taxAmount\":null,\"cvmResults\":null,\"token\":null,\"customerNumber\":null,\"email\":\"\"}"
      read 1152 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to test.ctpaiement.ca:443...
      opened
      starting SSL for test.ctpaiement.ca:443...
      SSL established
      <- "POST /v1/ack HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test.ctpaiement.ca\r\nContent-Length: 156\r\n\r\n"
      <- "auth-api-key=[FILTERED]&payload=[FILTERED]"
      -> "HTTP/1.1 200 200\r\n"
      -> "Date: Fri, 29 Jun 2018 18:21:08 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=ISO-8859-1\r\n"
      -> "\r\n"
      -> "15\r\n"
      reading 21 bytes...
      -> "{\"returnCode\":\"true\"}"
      read 21 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def successful_purchase_response
    '{"returnCode":"  00","errorDescription":null,"authorizationNumber":"443752  ","referenceNumber":"          ","transactionNumber":"000007708972","batchNumber":"0001","terminalNumber":"13366","serverNumber":"0001","timeStamp":"20180629-12110905","trxCode":"00","merchantNumber":"53400030","amount":"00000000100","invoiceNumber":"021efc336262","trxType":"C","cardType":"V","cardNumber":"450116XXXXXX7214                        ","expirationDate":"0720","bankTerminalNumber":"53400188","trxDate":"06292018","trxTime":"121109","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000008","receiptDisp":"       APPROVED-THANK YOU       ","terminalDisp":"APPROVED                ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def successful_ack_response
    '{"returnCode":"true"}'
  end

  def failed_purchase_response
    '{"returnCode":"  05","errorDescription":"Transaction declined","authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007708975","batchNumber":"0000","terminalNumber":"13366","serverNumber":"0001","timeStamp":"20180629-12272768","trxCode":"00","merchantNumber":"53400030","amount":"00000000100","invoiceNumber":"098096b31937","trxType":"C","cardType":"V","cardNumber":"450224XXXXXX1718                        ","expirationDate":"0919","bankTerminalNumber":"53400188","trxDate":"06292018","trxTime":"122727","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000009","receiptDisp":"    TRANSACTION NOT APPROVED    ","terminalDisp":"05-DECLINE              ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def successful_authorize_response
    '{"returnCode":"  00","errorDescription":null,"authorizationNumber":"448572  ","referenceNumber":"          ","transactionNumber":"000007708990","batchNumber":"0001","terminalNumber":"13367","serverNumber":"0001","timeStamp":"20180629-12501747","trxCode":"01","merchantNumber":"53400030","amount":"00000000100","invoiceNumber":"0e7ebe0a804f","trxType":"C","cardType":"V","cardNumber":"450116XXXXXX7214                        ","expirationDate":"0720","bankTerminalNumber":"53400189","trxDate":"06292018","trxTime":"125017","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000014","receiptDisp":"       APPROVED-THANK YOU       ","terminalDisp":"APPROVED                ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def failed_authorize_response
    '{"returnCode":"  05","errorDescription":"Transaction declined","authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007708993","batchNumber":"0000","terminalNumber":"13367","serverNumber":"0001","timeStamp":"20180629-13072751","trxCode":"01","merchantNumber":"53400030","amount":"00000000100","invoiceNumber":"02ec22cbb5db","trxType":"C","cardType":"V","cardNumber":"450224XXXXXX1718                        ","expirationDate":"0919","bankTerminalNumber":"53400189","trxDate":"06292018","trxTime":"130727","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000015","receiptDisp":"    TRANSACTION NOT APPROVED    ","terminalDisp":"05-DECLINE              ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def successful_capture_response
    '{"returnCode":"  00","errorDescription":null,"authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007708991","batchNumber":"0001","terminalNumber":"13366","serverNumber":"0001","timeStamp":"20180629-12501869","trxCode":"02","merchantNumber":"53400030","amount":"00000000100","invoiceNumber":"0636aca3dd8e","trxType":"C","cardType":"V","cardNumber":"450116XXXXXX7214                        ","expirationDate":"0720","bankTerminalNumber":"53400188","trxDate":"06292018","trxTime":"125018","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000015","receiptDisp":"       APPROVED-THANK YOU       ","terminalDisp":"APPROVED                ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def failed_capture_response
    '{"returnCode":"9068","errorDescription":"The original transaction number does not match any actual transaction","authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007708999","batchNumber":"    ","terminalNumber":"     ","serverNumber":"    ","timeStamp":"20180629-13224441","trxCode":"  ","merchantNumber":"        ","amount":"00000000000","invoiceNumber":"            ","trxType":" ","cardType":" ","cardNumber":"                                        ","expirationDate":"    ","bankTerminalNumber":"        ","trxDate":"        ","trxTime":"      ","accountType":" ","trxMethod":"   ","languageCode":" ","sequenceNumber":"               ","receiptDisp":"    OPERATION NON COMPLETEE     ","terminalDisp":"9068: Contactez support.","operatorId":"        ","surchargeAmount":"           ","companyNumber":"     ","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def successful_refund_response
    ' {"returnCode":"  00","errorDescription":null,"authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007709004","batchNumber":"0001","terminalNumber":"13367","serverNumber":"0001","timeStamp":"20180629-13294388","trxCode":"03","merchantNumber":"53400030","amount":"00000000100","invoiceNumber":"0a08f144b6ea","trxType":"C","cardType":"V","cardNumber":"450116XXXXXX7214                        ","expirationDate":"0720","bankTerminalNumber":"53400189","trxDate":"06292018","trxTime":"132944","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000019","receiptDisp":"       APPROVED-THANK YOU       ","terminalDisp":"APPROVED                ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def failed_refund_response
    '{"returnCode":"9068","errorDescription":"The original transaction number does not match any actual transaction","authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007709009","batchNumber":"    ","terminalNumber":"     ","serverNumber":"    ","timeStamp":"20180629-13402119","trxCode":"  ","merchantNumber":"        ","amount":"00000000000","invoiceNumber":"            ","trxType":" ","cardType":" ","cardNumber":"                                        ","expirationDate":"    ","bankTerminalNumber":"        ","trxDate":"        ","trxTime":"      ","accountType":" ","trxMethod":"   ","languageCode":" ","sequenceNumber":"               ","receiptDisp":"    OPERATION NON COMPLETEE     ","terminalDisp":"9068: Contactez support.","operatorId":"        ","surchargeAmount":"           ","companyNumber":"     ","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def successful_void_response
    '{"returnCode":"  00","errorDescription":null,"authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007709013","batchNumber":"0001","terminalNumber":"13367","serverNumber":"0001","timeStamp":"20180629-13451840","trxCode":"04","merchantNumber":"53400030","amount":"00000000100","invoiceNumber":"0de38871ce96","trxType":"C","cardType":"V","cardNumber":"450116XXXXXX7214","expirationDate":"0720","bankTerminalNumber":"53400189","trxDate":"06292018","trxTime":"134518","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000023","receiptDisp":"       APPROVED-THANK YOU       ","terminalDisp":"APPROVED                ","operatorId":"00000000","surchargeAmount":"           ","companyNumber":"     ","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def failed_void_response
    '{"returnCode":"9068","errorDescription":"The original transaction number does not match any actual transaction","authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"0000000000-1","batchNumber":"    ","terminalNumber":"     ","serverNumber":"    ","timeStamp":"20180629-13520693","trxCode":"  ","merchantNumber":"        ","amount":"00000000000","invoiceNumber":"            ","trxType":" ","cardType":" ","cardNumber":"                                        ","expirationDate":"    ","bankTerminalNumber":"        ","trxDate":"        ","trxTime":"      ","accountType":" ","trxMethod":"   ","languageCode":" ","sequenceNumber":"               ","receiptDisp":"    OPERATION NOT COMPLETED     ","terminalDisp":"9068: Contact support.  ","operatorId":"        ","surchargeAmount":"           ","companyNumber":"     ","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def successful_verify_response
    '{"returnCode":"  00","errorDescription":null,"authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007709025","batchNumber":"0001","terminalNumber":"13367","serverNumber":"0001","timeStamp":"20180629-14023575","trxCode":"08","merchantNumber":"53400030","amount":"00000000000","invoiceNumber":"0b882fe35f69","trxType":"C","cardType":"V","cardNumber":"450116XXXXXX7214                        ","expirationDate":"0720","bankTerminalNumber":"53400189","trxDate":"06292018","trxTime":"140236","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000025","receiptDisp":"       APPROVED-THANK YOU       ","terminalDisp":"APPROVED                ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def failed_verify_response
    '{"returnCode":"  05","errorDescription":"Transaction declined","authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007709029","batchNumber":"0000","terminalNumber":"13367","serverNumber":"0001","timeStamp":"20180629-14104707","trxCode":"08","merchantNumber":"53400030","amount":"00000000000","invoiceNumber":"0c0054d2bb7a","trxType":"C","cardType":"V","cardNumber":"450224XXXXXX1718                        ","expirationDate":"0919","bankTerminalNumber":"53400189","trxDate":"06292018","trxTime":"141047","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000026","receiptDisp":"    TRANSACTION NOT APPROVED    ","terminalDisp":"05-DECLINE              ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end

  def successful_credit_response
    '{"returnCode":"  00","errorDescription":null,"authorizationNumber":"        ","referenceNumber":"          ","transactionNumber":"000007709063","batchNumber":"0001","terminalNumber":"13366","serverNumber":"0001","timeStamp":"20180629-14420931","trxCode":"03","merchantNumber":"53400030","amount":"00000000100","invoiceNumber":"054902f2ded0","trxType":"C","cardType":"V","cardNumber":"450116XXXXXX7214                        ","expirationDate":"0720","bankTerminalNumber":"53400188","trxDate":"06292018","trxTime":"144209","accountType":"0","trxMethod":"T@1","languageCode":"E","sequenceNumber":"000000000032","receiptDisp":"       APPROVED-THANK YOU       ","terminalDisp":"APPROVED                ","operatorId":"00000000","surchargeAmount":"","companyNumber":"00589","secureID":"","cvv2Cvc2Status":" ","iopIssuerConfirmationNumber":null,"iopIssuerName":null,"avsStatus":null,"holderName":null,"threeDSStatus":null,"emvLabel":null,"emvAID":null,"emvTVR":null,"emvTSI":null,"emvTC":null,"demoMode":null,"terminalInvoiceNumber":null,"cashbackAmount":null,"tipAmount":null,"taxAmount":null,"cvmResults":null,"token":null,"customerNumber":null,"email":""}'
  end
end
