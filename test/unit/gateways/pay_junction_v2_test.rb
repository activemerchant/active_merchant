require 'test_helper'

class PayJunctionV2Test < Test::Unit::TestCase
  def setup
    @gateway = PayJunctionV2Gateway.new(api_login: 'api_login', api_password: 'api_password', api_key: 'api_key')

    @amount = 99
    @credit_card = credit_card('4444333322221111', month: 01, year: 2022, verification_value: 999)
    @options = {
      order_id: generate_unique_id,
      billing_address: address
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Approved', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    amount = 5
    response = @gateway.purchase(amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined (do not honor)', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Approved', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    amount = 10
    response = @gateway.authorize(amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined (restricted)', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_failed_capture
    raw_response = mock
    raw_response.expects(:body).returns(failed_capture_response)
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_request).raises(exception)

    response = @gateway.capture(@amount, 'invalid_authorization')
    assert_failure response
    assert_equal '404 Not Found|', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_failed_refund
    raw_response = mock
    raw_response.expects(:body).returns(failed_refund_response)
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_request).raises(exception)

    response = @gateway.refund(@amount, 'invalid_authorization')
    assert_failure response
    assert_equal '404 Not Found|', response.message
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_credit
    raw_response = mock
    raw_response.expects(:body).returns(failed_credit_response)
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_post).raises(exception)

    amount = 0
    response = @gateway.credit(amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Amount Base must be greater than 0.|', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_failed_void
    raw_response = mock
    raw_response.expects(:body).returns(failed_void_response)
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_request).raises(exception)

    response = @gateway.void('invalid_authorization')
    assert_failure response
    assert_equal '404 Not Found|', response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_void_response)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_verify_with_failed_void
    raw_response = mock
    raw_response.expects(:body).returns(failed_void_response)
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_request).raises(exception)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_verify
    raw_response = mock
    raw_response.expects(:body).returns(failed_verify_response)
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_post).raises(exception)

    credit_card = credit_card('444433332222111')
    response = @gateway.verify(credit_card, @options)
    assert_failure response
    assert_match %r{Card Number is not a valid card number}, response.message
  end

  def test_successful_store_and_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    @gateway.expects(:ssl_request).returns(successful_void_response)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.authorization
    assert_equal 'Approved', response.message

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_store
    raw_response = mock
    raw_response.expects(:body).returns(failed_store_response)
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_post).raises(exception)

    credit_card = credit_card('444433332222111')
    response = @gateway.store(credit_card, @options)
    assert_failure response
    assert_match %r{Card Number is not a valid card number}, response.message
  end

  def test_add_address
    post = {card: {billingAddress: {}}}
    @gateway.send(:add_address, post, @options)
    assert_equal @options[:billing_address][:first_name], post[:billingFirstName]
    assert_equal @options[:billing_address][:last_name], post[:billingLastName]
    assert_equal @options[:billing_address][:company], post[:billingCompanyName]
    assert_equal @options[:billing_address][:phone_number], post[:billingPhone]
    assert_equal @options[:billing_address][:address1], post[:billingAddress]
    assert_equal @options[:billing_address][:city], post[:billingCity]
    assert_equal @options[:billing_address][:state], post[:billingState]
    assert_equal @options[:billing_address][:country], post[:billingCountry]
    assert_equal @options[:billing_address][:zip], post[:billingZip]
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q{
      opening connection to api.payjunctionlabs.com:443...
      opened
      starting SSL for api.payjunctionlabs.com:443...
      SSL established
      <- "POST /transactions/ HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded;charset=UTF-8\r\nAuthorization: Basic cGotcWwtMDE6cGotcWwtMDFw\r\nAccept: application/json\r\nX-Pj-Application-Key: c43e89f9-525c-4968-b299-37f7cb1bb1a2\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.payjunctionlabs.com\r\nContent-Length: 135\r\n\r\n"
      <- "amountBase=0.99&invoiceNumber=b585872cc9cff42dd46b9ba8d31cc90f&cardNumber=4444333322221111&cardExpMonth=01&cardExpYear=2020&cardCvv=999"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Fri, 19 Aug 2016 17:59:29 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: __cfduid=dc9cabfd2f0cbbf76295f47b8aff448601471629567; expires=Sat, 19-Aug-17 17:59:27 GMT; path=/; domain=.payjunctionlabs.com; HttpOnly\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Pj-Request-Id: 30af86ae-75fb-4ec0-a704-393df6a11fed\r\n"
      -> "Vary: User-Agent\r\n"
      -> "Server: cloudflare-nginx\r\n"
      -> "CF-RAY: 2d4f7fdbf7262fff-MAA\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "19e\r\n"
      reading 414 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\x94R[O\x830\x14~\xDF\xAF <\xEBF\x99s\xB07tx\x8D:'\x9A\xE8\x8B9\x94\xE2j\x80\x92\xF6\x94D\x97\xFDwC\v\x13M|\xF0\xA5I\xBF[\xCF\xA5\xDB\x91\xE3\xB8(\xA1R@\x91\x8B\xEA2s\x9D\x85\x13\xCC\xE7\xD3\x83\x96\xD1\x92\xB7ww\x83X\xAB\xC5d\x025\x1F\xD7\xF0\xF1\xAE+\xA3. Uc*\xCA\xC9 AMZ\xB7k\xEC\xC8d\xC9+(l*1\x98U\x99\xD4\xD3\x8Bh)\x1E[)\x94BWx\x02\x8A\x19\xCA\e\x87\xE1\x90H\x04B\xF1\x8B\xE1U#8e\xB7\xBAL\x994\\:\vf\xC1\xDC\xA74\xA4y~\xE4g\xD9\xD1q\x1A\xA6\x10dSBi\xE8\xE5\xD6W2\xDC\bS\x91(\x1D?\xC7K\x8B*\x04\xD4\xCA\xD6\x15\xAD\x92\xC7uW\x18\x95\f\x90Y\xB9\xEF\x91\xE3C/8$aB\xE6\x8BY\xB8\x98z/VU\x80\xC2\e\x91\xF1\x9C\xFF%\xF5\xC3N*\x99\xAAEe\xFB\xDC\x8E\x1C\xA7\xED\xB1\xAE\xA5h\xAC\x13\xA5f\a\x16\xA6\"\xEB\xA6\xE1\xB9\x1DT2\xA5\xE0\xCD\xA2Q\xEF\xEA\xB8Z\n\xCA\x94\x12\xF2;\xB9\xCD\xD6\xB8\x11\x92\x7F\xFEN\xDF?\v\xC5i\xFF\xCE\xEA\xCA\xF7\xA2\x95\xFB-h\xD40\xEB\xE7\x94n\xEF\x92\xD7u|\xFF\x18?$\xF1\xD2\xED$\xBB\xBD\x976\xCD\x7F\xBD\xA3\xFE\xDC\xD9\x8D0\xC4\x82\x95\xAC\xC2\xC1\xA8,hz\xC9\xA1Pl\xAFn@\x17C!~\xD4\xAC\xDB\xE6z\xD9\x8F\b(5\xBF\xA9\xE7\x9E.\x1F\xA2\x9EkWx&\xB4\xFDI\x84\x10\xD2\xD6\xB5\e\xED\xBE\x00\x00\x00\xFF\xFF\x03\x00\xD2NT\x17#\x03\x00\x00"
      read 414 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    }
  end

  def post_scrubbed
    %q{
      opening connection to api.payjunctionlabs.com:443...
      opened
      starting SSL for api.payjunctionlabs.com:443...
      SSL established
      <- "POST /transactions/ HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded;charset=UTF-8\r\nAuthorization: Basic [FILTERED]\r\nAccept: application/json\r\nX-Pj-Application-Key: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.payjunctionlabs.com\r\nContent-Length: 135\r\n\r\n"
      <- "amountBase=0.99&invoiceNumber=b585872cc9cff42dd46b9ba8d31cc90f&cardNumber=[FILTERED]&cardExpMonth=01&cardExpYear=2020&cardCvv=[FILTERED]"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Fri, 19 Aug 2016 17:59:29 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: __cfduid=dc9cabfd2f0cbbf76295f47b8aff448601471629567; expires=Sat, 19-Aug-17 17:59:27 GMT; path=/; domain=.payjunctionlabs.com; HttpOnly\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Pj-Request-Id: 30af86ae-75fb-4ec0-a704-393df6a11fed\r\n"
      -> "Vary: User-Agent\r\n"
      -> "Server: cloudflare-nginx\r\n"
      -> "CF-RAY: 2d4f7fdbf7262fff-MAA\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "19e\r\n"
      reading 414 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\x94R[O\x830\x14~\xDF\xAF <\xEBF\x99s\xB07tx\x8D:'\x9A\xE8\x8B9\x94\xE2j\x80\x92\xF6\x94D\x97\xFDwC\v\x13M|\xF0\xA5I\xBF[\xCF\xA5\xDB\x91\xE3\xB8(\xA1R@\x91\x8B\xEA2s\x9D\x85\x13\xCC\xE7\xD3\x83\x96\xD1\x92\xB7ww\x83X\xAB\xC5d\x025\x1F\xD7\xF0\xF1\xAE+\xA3. Uc*\xCA\xC9 AMZ\xB7k\xEC\xC8d\xC9+(l*1\x98U\x99\xD4\xD3\x8Bh)\x1E[)\x94BWx\x02\x8A\x19\xCA\e\x87\xE1\x90H\x04B\xF1\x8B\xE1U#8e\xB7\xBAL\x994\\:\vf\xC1\xDC\xA74\xA4y~\xE4g\xD9\xD1q\x1A\xA6\x10dSBi\xE8\xE5\xD6W2\xDC\bS\x91(\x1D?\xC7K\x8B*\x04\xD4\xCA\xD6\x15\xAD\x92\xC7uW\x18\x95\f\x90Y\xB9\xEF\x91\xE3C/8$aB\xE6\x8BY\xB8\x98z/VU\x80\xC2\e\x91\xF1\x9C\xFF%\xF5\xC3N*\x99\xAAEe\xFB\xDC\x8E\x1C\xA7\xED\xB1\xAE\xA5h\xAC\x13\xA5f\a\x16\xA6\"\xEB\xA6\xE1\xB9\x1DT2\xA5\xE0\xCD\xA2Q\xEF\xEA\xB8Z\n\xCA\x94\x12\xF2;\xB9\xCD\xD6\xB8\x11\x92\x7F\xFEN\xDF?\v\xC5i\xFF\xCE\xEA\xCA\xF7\xA2\x95\xFB-h\xD40\xEB\xE7\x94n\xEF\x92\xD7u|\xFF\x18?$\xF1\xD2\xED$\xBB\xBD\x976\xCD\x7F\xBD\xA3\xFE\xDC\xD9\x8D0\xC4\x82\x95\xAC\xC2\xC1\xA8,hz\xC9\xA1Pl\xAFn@\x17C!~\xD4\xAC\xDB\xE6z\xD9\x8F\b(5\xBF\xA9\xE7\x9E.\x1F\xA2\x9EkWx&\xB4\xFDI\x84\x10\xD2\xD6\xB5\e\xED\xBE\x00\x00\x00\xFF\xFF\x03\x00\xD2NT\x17#\x03\x00\x00"
      read 414 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    }
  end

  def successful_purchase_response
    %(
      {
        "transactionId" : 9275,
        "uri" : "https://api.payjunctionlabs.com/transactions/9275",
        "terminalId" : 1,
        "action" : "CHARGE",
        "amountBase" : "0.99",
        "amountTotal" : "0.99",
        "invoiceNumber" : "6ee793bd25121812ab7a230c5845983f",
        "method" : "KEYED",
        "status" : "CAPTURE",
        "created" : "2016-08-22T18:12:10Z",
        "lastModified" : "2016-08-22T18:12:09Z",
        "response" : {
          "approved" : true,
          "code" : "00",
          "message" : "Approved",
          "processor" : {
            "authorized" : true,
            "approvalCode" : "PJ20AP",
            "avs" : {
              "status" : "NOT_REQUESTED"
            },
            "cvv" : {
              "status" : "NOT_REQUESTED"
            }
          }
        },
        "settlement" : {
          "settled" : false
        },
        "vault" : {
          "type" : "CARD",
          "accountType" : "VISA",
          "lastFour" : "1111"
        }
      }
    )
  end

  def failed_purchase_response
    %(
      {
        "transactionId" : 9277,
        "uri" : "https://api.payjunctionlabs.com/transactions/9277",
        "terminalId" : 1,
        "action" : "CHARGE",
        "amountBase" : "0.05",
        "amountTotal" : "0.05",
        "invoiceNumber" : "99de11a3873042a8e75ba8b35ab71d84",
        "method" : "KEYED",
        "status" : "DECLINED",
        "created" : "2016-08-22T18:15:24Z",
        "lastModified" : "2016-08-22T18:15:24Z",
        "response" : {
          "approved" : false,
          "code" : "05",
          "message" : "Declined (do not honor)",
          "processor" : {
            "authorized" : false,
            "avs" : {
              "status" : "NOT_REQUESTED"
            },
            "cvv" : {
              "status" : "NOT_REQUESTED"
            }
          }
        },
        "settlement" : {
          "settled" : false
        },
        "vault" : {
          "type" : "CARD",
          "accountType" : "VISA",
          "lastFour" : "1111"
        }
      }
    )
  end

  def successful_authorize_response
    %(
      {
        "transactionId" : 9275,
        "uri" : "https://api.payjunctionlabs.com/transactions/9275",
        "terminalId" : 1,
        "action" : "CHARGE",
        "amountBase" : "0.99",
        "amountTotal" : "0.99",
        "invoiceNumber" : "6ee793bd25121812ab7a230c5845983f",
        "method" : "KEYED",
        "status" : "HOLD",
        "created" : "2016-08-22T18:12:10Z",
        "lastModified" : "2016-08-22T18:12:09Z",
        "response" : {
          "approved" : true,
          "code" : "00",
          "message" : "Approved",
          "processor" : {
            "authorized" : true,
            "approvalCode" : "PJ20AP",
            "avs" : {
              "status" : "NOT_REQUESTED"
            },
            "cvv" : {
              "status" : "NOT_REQUESTED"
            }
          }
        },
        "settlement" : {
          "settled" : false
        },
        "vault" : {
          "type" : "CARD",
          "accountType" : "VISA",
          "lastFour" : "1111"
        }
      }
    )
  end

  def failed_authorize_response
    %(
      {
        "transactionId" : 9277,
        "uri" : "https://api.payjunctionlabs.com/transactions/9277",
        "terminalId" : 1,
        "action" : "CHARGE",
        "amountBase" : "0.10",
        "amountTotal" : "0.10",
        "invoiceNumber" : "99de11a3873042a8e75ba8b35ab71d84",
        "method" : "KEYED",
        "status" : "DECLINED",
        "created" : "2016-08-22T18:15:24Z",
        "lastModified" : "2016-08-22T18:15:24Z",
        "response" : {
          "approved" : false,
          "code" : "05",
          "message" : "Declined (restricted)",
          "processor" : {
            "authorized" : false,
            "avs" : {
              "status" : "NOT_REQUESTED"
            },
            "cvv" : {
              "status" : "NOT_REQUESTED"
            }
          }
        },
        "settlement" : {
          "settled" : false
        },
        "vault" : {
          "type" : "CARD",
          "accountType" : "VISA",
          "lastFour" : "1111"
        }
      }
    )
  end

  def successful_capture_response
    %(
      {
        "transactionId" : 9281,
        "uri" : "https://api.payjunctionlabs.com/transactions/9281",
        "terminalId" : 1,
        "action" : "CHARGE",
        "amountBase" : "0.99",
        "amountTotal" : "0.99",
        "invoiceNumber" : "d3924cd19b50f5b5f10ae37f6b794dc4",
        "method" : "KEYED",
        "status" : "CAPTURE",
        "created" : "2016-08-22T18:29:23Z",
        "lastModified" : "2016-08-22T18:29:24Z",
        "response" : {
          "approved" : true,
          "code" : "00",
          "message" : "Approved",
          "processor" : {
            "authorized" : true,
            "approvalCode" : "PJ20AP",
            "avs" : {
              "status" : "NOT_REQUESTED"
            },
            "cvv" : {
              "status" : "NOT_REQUESTED"
            }
          }
        },
        "settlement" : {
          "settled" : false
        },
        "vault" : {
          "type" : "CARD",
          "accountType" : "VISA",
          "lastFour" : "1111"
        }
      }
    )
  end

  def failed_capture_response
    %(
      {
        "errors" : [ {
          "message" : "404 Not Found"
        } ]
      }
    )
  end

  def successful_refund_response
    %(
      {
        "transactionId" : 9283,
        "uri" : "https://api.payjunctionlabs.com/transactions/9283",
        "terminalId" : 1,
        "action" : "CHARGE",
        "amountBase" : "0.99",
        "amountTotal" : "0.99",
        "invoiceNumber" : "1d13a750593375c7dc4e8c03987f4990",
        "method" : "KEYED",
        "status" : "VOID",
        "created" : "2016-08-22T18:37:25Z",
        "lastModified" : "2016-08-22T18:37:27Z",
        "response" : {
          "approved" : true,
          "code" : "00",
          "message" : "Approved",
          "processor" : {
            "authorized" : true,
            "approvalCode" : "PJ20AP",
            "avs" : {
              "status" : "NOT_REQUESTED"
            },
            "cvv" : {
              "status" : "NOT_REQUESTED"
            }
          }
        },
        "settlement" : {
          "settled" : false
        },
        "vault" : {
          "type" : "CARD",
          "accountType" : "VISA",
          "lastFour" : "1111"
        }
      }
    )
  end

  def failed_refund_response
    %(
      {
        "errors" : [ {
          "message" : "404 Not Found"
        } ]
      }
    )
  end

  def successful_credit_response
    %(
      {
        "transactionId" : 9285,
        "uri" : "https://api.payjunctionlabs.com/transactions/9285",
        "terminalId" : 1,
        "action" : "REFUND",
        "amountBase" : "0.99",
        "amountTotal" : "0.99",
        "invoiceNumber" : "9f1cec3b0b4375ef866a9ba90b277dcb",
        "method" : "KEYED",
        "status" : "CAPTURE",
        "created" : "2016-08-22T18:42:30Z",
        "lastModified" : "2016-08-22T18:42:29Z",
        "response" : {
          "approved" : true,
          "code" : "00",
          "message" : "Approved",
          "processor" : {
            "authorized" : false,
            "avs" : {
              "status" : "NOT_REQUESTED"
            },
            "cvv" : {
              "status" : "NOT_REQUESTED"
            }
          }
        },
        "settlement" : {
          "settled" : false
        },
        "vault" : {
          "type" : "CARD",
          "accountType" : "VISA",
          "lastFour" : "1111"
        }
      }
    )
  end

  def failed_credit_response
    %(
      {
        "errors" : [ {
          "message" : "Amount Base must be greater than 0.",
          "parameter" : "amountBase",
          "type" : "invalid"
        } ]
      }
    )
  end

  def successful_void_response
    %(
      {
        "transactionId" : 9287,
        "uri" : "https://api.payjunctionlabs.com/transactions/9287",
        "terminalId" : 1,
        "action" : "CHARGE",
        "amountBase" : "0.99",
        "amountTotal" : "0.99",
        "invoiceNumber" : "d28be42ad1c89b0d75b1164cc6a0a12d",
        "method" : "KEYED",
        "status" : "VOID",
        "created" : "2016-08-22T18:47:33Z",
        "lastModified" : "2016-08-22T18:47:34Z",
        "response" : {
          "approved" : true,
          "code" : "00",
          "message" : "Approved",
          "processor" : {
            "authorized" : true,
            "approvalCode" : "PJ20AP",
            "avs" : {
              "status" : "NOT_REQUESTED"
            },
            "cvv" : {
              "status" : "NOT_REQUESTED"
            }
          }
        },
        "settlement" : {
          "settled" : false
        },
        "vault" : {
          "type" : "CARD",
          "accountType" : "VISA",
          "lastFour" : "1111"
        }
      }
    )
  end

  def failed_void_response
    %(
      {
        "errors" : [ {
          "message" : "404 Not Found"
        } ]
      }
    )
  end

  def failed_verify_response
    %(
      {
        "errors" : [ {
          "message" : "Card Number is not a valid card number.",
          "parameter" : "cardNumber",
          "type" : "invalid"
        } ]
      }
    )
  end

  def failed_store_response
    %(
      {
        "errors" : [ {
          "message" : "Card Number is not a valid card number.",
          "parameter" : "cardNumber",
          "type" : "invalid"
        } ]
      }
    )
  end
end
