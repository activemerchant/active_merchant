require 'test_helper'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Shift4Gateway
      def setup_access_token
        '12345678'
      end
    end
  end
end

class Shift4Test < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = Shift4Gateway.new(client_guid: '123456', auth_token: 'abcder123')
    @credit_card = credit_card
    @amount = 5
    @options = {}
    @extra_options = {
      clerk_id: '1576',
      notes: 'test notes',
      tax: '2',
      customer_reference: 'D019D09309F2',
      destination_postal_code: '94719',
      product_descriptors: %w(Hamburger Fries Soda Cookie)
    }
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount, '1111g66gw3ryke06', @options)
    end.respond_with(successful_capture_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
    assert_equal @amount, response_result(response)['amount']['total']
    assert_equal response_result(response)['card']['token']['value'].present?, true
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
    assert_equal @amount, response_result(response)['amount']['total']
    assert_equal response_result(response)['card']['token']['value'].present?, true
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, '1111g66gw3ryke06', @options)
    end.respond_with(successful_purchase_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
    assert_equal @amount, response_result(response)['amount']['total']
    assert_equal response_result(response)['card']['token']['value'].present?, true
  end

  def test_successful_purchase_with_extra_fields
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(@extra_options))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['clerk']['numericId'], @extra_options[:clerk_id]
      assert_equal request['transaction']['notes'], @extra_options[:notes]
      assert_equal request['amount']['tax'], @extra_options[:tax].to_f
      assert_equal request['transaction']['purchaseCard']['customerReference'], @extra_options[:customer_reference]
      assert_equal request['transaction']['purchaseCard']['destinationPostalCode'], @extra_options[:destination_postal_code]
      assert_equal request['transaction']['purchaseCard']['productDescriptors'], @extra_options[:product_descriptors]
    end.respond_with(successful_purchase_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, '1111g66gw3ryke06', @options.merge!(invoice: '4666309473'))
    end.respond_with(successful_refund_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)
    response = @gateway.void('123')

    assert response.success?
    assert_equal response.message, 'Transaction successful'
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, 'abc', @options)
    assert_failure response
    assert_nil response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'abc', @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'abc', @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('', @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_support_scrub
    assert @gateway.supports_scrubbing?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def response_result(response)
    response.params['result'].first
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to utgapi.shift4test.com:443...
      opened
      starting SSL for utgapi.shift4test.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /api/rest/v1/transactions/authorization HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nCompanyname: Spreedly\r\nAccesstoken: 4902FAD2-E88F-4A8D-98C2-EED2A73DBBE2\r\nInvoice: 1\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: utgapi.shift4test.com\r\nContent-Length: 498\r\n\r\n"
      <- "{\"dateTime\":\"2022-06-09T14:03:36.413505000+14:03\",\"amount\":{\"total\":5.0,\"tax\":1.0},\"clerk\":{\"numericId\":24},\"transaction\":{\"invoice\":\"1\",\"purchaseCard\":{\"customerReference\":\"457\",\"destinationPostalCode\":\"89123\",\"productDescriptors\":[\"Potential\",\"Wrong\"]}},\"card\":{\"expirationDate\":\"0923\",\"number\":\"4000100011112224\",\"entryMode\":null,\"present\":null,\"securityCode\":{\"indicator\":\"1\",\"value\":\"4444\"}},\"customer\":{\"addressLine1\":\"89 Main Street\",\"firstName\":\"XYZ\",\"lastName\":\"RON\",\"postalCode\":\"89000\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/json; charset=ISO-8859-1\r\n"
      -> "Content-Length: 1074\r\n"
      -> "Date: Thu, 09 Jun 2022 09:03:40 GMT\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Frame-Options: deny\r\n"
      -> "Content-Security-Policy: default-src 'none';base-uri 'none';frame-ancestors 'none';object-src 'none';sandbox;\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "Referrer-Policy: no-referrer\r\n"
      -> "X-Powered-By: Electricity\r\n"
      -> "Expires: 0\r\n"
      -> "Cache-Control: private, no-cache, no-store, max-age=0, no-transform\r\n"
      -> "Server: DatasnapHTTPService/2011\r\n"
      -> "\r\n"
      reading 1074 bytes...
      -> ""
      -> "{\"result\":[{\"dateTime\":\"2022-06-09T14:03:36.000-07:00\",\"receiptColumns\":30,\"amount\":{\"tax\":1,\"total\":5},\"card\":{\"type\":\"VS\",\"entryMode\":\"M\",\"number\":\"XXXXXXXXXXXX2224\",\"present\":\"Y\",\"securityCode\":{\"result\":\"N\",\"valid\":\"N\"},\"token\":{\"value\":\"8042728003772224\"}},\"clerk\":{\"numericId\":24},\"customer\":{\"addressLine1\":\"89 Main Street\",\"firstName\":\"XYZ\",\"lastName\":\"RON\",\"postalCode\":\"89000\"},\"device\":{\"capability\":{\"magstripe\":\"Y\",\"manualEntry\":\"Y\"}},\"merchant\":{\"mid\":8504672,\"name\":\"Zippin - Retail\"},\"receipt\":[{\"key\":\"MaskedPAN\",\"printValue\":\"XXXXXXXXXXXX2224\"},{\"key\":\"CardEntryMode\",\"printName\":\"ENTRY METHOD\",\"printValue\":\"KEYED\"},{\"key\":\"SignatureRequired\",\"printValue\":\"N\"}],\"server\":{\"name\":\"UTGAPI05CE\"},\"transaction\":{\"authSource\":\"E\",\"avs\":{\"postalCodeVerified\":\"Y\",\"result\":\"Y\",\"streetVerified\":\"Y\",\"valid\":\"Y\"},\"invoice\":\"0000000001\",\"purchaseCard\":{\"customerReference\":\"457\",\"destinationPostalCode\":\"89123\",\"productDescriptors\":[\"Potential\",\"Wrong\"]},\"responseCode\":\"D\",\"saleFlag\":\"S\"},\"universalToken\":{\"value\":\"400010-2F1AA405-001AA4-000026B7-1766C44E9E8\"}}]}"
      read 1074 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to utgapi.shift4test.com:443...
      opened
      starting SSL for utgapi.shift4test.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /api/rest/v1/transactions/authorization HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nCompanyname: Spreedly\r\nAccesstoken: 4902FAD2-E88F-4A8D-98C2-EED2A73DBBE2\r\nInvoice: 1\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: utgapi.shift4test.com\r\nContent-Length: 498\r\n\r\n"
      <- "{\"dateTime\":\"2022-06-09T14:03:36.413505000+14:03\",\"amount\":{\"total\":5.0,\"tax\":1.0},\"clerk\":{\"numericId\":24},\"transaction\":{\"invoice\":\"1\",\"purchaseCard\":{\"customerReference\":\"457\",\"destinationPostalCode\":\"89123\",\"productDescriptors\":[\"Potential\",\"Wrong\"]}},\"card\":{\"expirationDate\":\"[FILTERED]",\"number\":\"[FILTERED]",\"entryMode\":null,\"present\":null,\"securityCode\":{\"indicator\":\"1\",\"value\":\"4444\"}},\"customer\":{\"addressLine1\":\"89 Main Street\",\"firstName\":\"[FILTERED]",\"lastName\":\"[FILTERED]",\"postalCode\":\"89000\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/json; charset=ISO-8859-1\r\n"
      -> "Content-Length: 1074\r\n"
      -> "Date: Thu, 09 Jun 2022 09:03:40 GMT\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Frame-Options: deny\r\n"
      -> "Content-Security-Policy: default-src 'none';base-uri 'none';frame-ancestors 'none';object-src 'none';sandbox;\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "Referrer-Policy: no-referrer\r\n"
      -> "X-Powered-By: Electricity\r\n"
      -> "Expires: 0\r\n"
      -> "Cache-Control: private, no-cache, no-store, max-age=0, no-transform\r\n"
      -> "Server: DatasnapHTTPService/2011\r\n"
      -> "\r\n"
      reading 1074 bytes...
      -> ""
      -> "{\"result\":[{\"dateTime\":\"2022-06-09T14:03:36.000-07:00\",\"receiptColumns\":30,\"amount\":{\"tax\":1,\"total\":5},\"card\":{\"type\":\"VS\",\"entryMode\":\"M\",\"number\":\"[FILTERED]",\"present\":\"Y\",\"securityCode\":{\"result\":\"N\",\"valid\":\"N\"},\"token\":{\"value\":\"8042728003772224\"}},\"clerk\":{\"numericId\":24},\"customer\":{\"addressLine1\":\"89 Main Street\",\"firstName\":\"[FILTERED]",\"lastName\":\"[FILTERED]",\"postalCode\":\"89000\"},\"device\":{\"capability\":{\"magstripe\":\"Y\",\"manualEntry\":\"Y\"}},\"merchant\":{\"mid\":8504672,\"name\":\"Zippin - Retail\"},\"receipt\":[{\"key\":\"MaskedPAN\",\"printValue\":\"XXXXXXXXXXXX2224\"},{\"key\":\"CardEntryMode\",\"printName\":\"ENTRY METHOD\",\"printValue\":\"KEYED\"},{\"key\":\"SignatureRequired\",\"printValue\":\"N\"}],\"server\":{\"name\":\"UTGAPI05CE\"},\"transaction\":{\"authSource\":\"E\",\"avs\":{\"postalCodeVerified\":\"Y\",\"result\":\"Y\",\"streetVerified\":\"Y\",\"valid\":\"Y\"},\"invoice\":\"0000000001\",\"purchaseCard\":{\"customerReference\":\"457\",\"destinationPostalCode\":\"89123\",\"productDescriptors\":[\"Potential\",\"Wrong\"]},\"responseCode\":\"D\",\"saleFlag\":\"S\"},\"universalToken\":{\"value\":\"400010-2F1AA405-001AA4-000026B7-1766C44E9E8\"}}]}"
      read 1074 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-RESPONSE
      {
          "result": [
              {
                  "dateTime": "2022-02-09T05:11:54.000-08:00",
                  "receiptColumns": 30,
                  "amount": {
                      "total": 5
                  },
                  "card": {
                      "type": "VS",
                      "entryMode": "M",
                      "number": "XXXXXXXXXXXX1111",
                      "present": "N",
                      "securityCode": {
                          "result": "N",
                          "valid": "N"
                      },
                      "token": {
                          "value": "8042714004661111"
                      }
                  },
                  "clerk": {
                      "numericId": 16
                  },
                  "device": {
                      "capability": {
                          "magstripe": "Y",
                          "manualEntry": "Y"
                      }
                  },
                  "merchant": {
                      "mid": 8585812,
                      "name": "RealtimePOS - Retail"
                  },
                  "receipt": [
                      {
                          "key": "MaskedPAN",
                          "printValue": "XXXXXXXXXXXX1111"
                      },
                      {
                          "key": "CardEntryMode",
                          "printName": "ENTRY METHOD",
                          "printValue": "KEYED"
                      },
                      {
                          "key": "SignatureRequired",
                          "printValue": "N"
                      }
                  ],
                  "server": {
                      "name": "UTGAPI12CE"
                  },
                  "transaction": {
                      "authSource": "E",
                      "invoice": "4666309473",
                      "purchaseCard": {
                          "customerReference": "1234567",
                          "destinationPostalCode": "89123",
                          "productDescriptors": [
                              "Test"
                          ]
                      },
                      "responseCode": "D",
                      "saleFlag": "S"
                  },
                  "universalToken": {
                      "value": "444433-2D5C1A5C-001624-00001621-16BAAF4ACC6"
                  }
              }
          ]
      }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
      {
        "result": [
            {
                "dateTime": "2022-05-02T02:19:38.000-07:00",
                "receiptColumns": 30,
                "amount": {
                    "total": 5
                },
                "card": {
                    "type": "VS",
                    "entryMode": "M",
                    "number": "XXXXXXXXXXXX1111",
                    "present": "N",
                    "securityCode": {},
                    "token": {
                        "value": "8042677003331111"
                    }
                },
                "clerk": {
                    "numericId": 24
                },
                "customer": {
                    "addressLine1": "89 Main Street",
                    "firstName": "XYZ",
                    "lastName": "RON",
                    "postalCode": "89000"
                },
                "device": {
                    "capability": {
                        "magstripe": "Y",
                        "manualEntry": "Y"
                    }
                },
                "merchant": {
                    "mid": 8504672
                },
                "receipt": [
                    {
                        "key": "MaskedPAN",
                        "printValue": "XXXXXXXXXXXX1111"
                    },
                    {
                        "key": "CardEntryMode",
                        "printName": "ENTRY METHOD",
                        "printValue": "KEYED"
                    },
                    {
                        "key": "SignatureRequired",
                        "printValue": "Y"
                    }
                ],
                "server": {
                    "name": "UTGAPI12CE"
                },
                "transaction": {
                    "authorizationCode": "OK168Z",
                    "authSource": "E",
                    "invoice": "3333333309",
                    "purchaseCard": {
                        "customerReference": "457",
                        "destinationPostalCode": "89123",
                        "productDescriptors": [
                            "Potential",
                            "Wrong"
                        ]
                    },
                    "responseCode": "A",
                    "saleFlag": "S"
                },
                "universalToken": {
                    "value": "444433-2D5C1A5C-001624-00001621-16BAAF4ACC6"
                }
            }
        ]
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      {
          "result": [
              {
                  "dateTime": "2022-05-08T01:18:22.000-07:00",
                  "receiptColumns": 30,
                  "amount": {
                      "total": 5
                  },
                  "card": {
                      "type": "VS",
                      "entryMode": "M",
                      "number": "XXXXXXXXXXXX1111",
                      "present": "N",
                      "token": {
                          "value": "1111x19h4cryk231"
                      }
                  },
                  "clerk": {
                      "numericId": 24
                  },
                  "device": {
                      "capability": {
                          "magstripe": "Y",
                          "manualEntry": "Y"
                      }
                  },
                  "merchant": {
                      "mid": 8628968
                  },
                  "receipt": [
                      {
                          "key": "MaskedPAN",
                          "printValue": "XXXXXXXXXXXX1111"
                      },
                      {
                          "key": "CardEntryMode",
                          "printName": "ENTRY METHOD",
                          "printValue": "KEYED"
                      },
                      {
                          "key": "SignatureRequired",
                          "printValue": "Y"
                      }
                  ],
                  "server": {
                      "name": "UTGAPI03CE"
                  },
                  "transaction": {
                      "authorizationCode": "OK207Z",
                      "authSource": "E",
                      "invoice": "3333333309",
                      "responseCode": "A",
                      "saleFlag": "S"
                  },
                  "universalToken": {
                      "value": "444433-2D5C1A5C-001624-00001621-16BAAF4ACC6"
                  }
              }
          ]
      }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime": "2022-02-09T05:11:54.000-08:00",
            "receiptColumns": 30,
            "amount": {
              "total": 5
            },
            "card": {
              "type": "VS",
              "entryMode": "M",
              "number": "XXXXXXXXXXXX1111",
              "present": "N",
              "securityCode": {
                "result": "N",
                "valid": "N"
              },
              "token": {
                "value": "8042714004661111"
              }
            },
            "clerk": {
              "numericId": 16
            },
            "device": {
              "capability": {
                "magstripe": "Y",
                "manualEntry": "Y"
              }
            },
            "merchant": {
              "mid": 8585812,
              "name": "RealtimePOS - Retail"
            },
            "receipt": [
              {
                "key": "MaskedPAN",
                "printValue": "XXXXXXXXXXXX1111"
              },
              {
                "key": "CardEntryMode",
                "printName": "ENTRY METHOD",
                "printValue": "KEYED"
              },
              {
                "key": "SignatureRequired",
                "printValue": "N"
              }
            ],
            "server": {
              "name": "UTGAPI12CE"
            },
            "transaction": {
              "authSource": "E",
              "invoice": "4666309473",
              "purchaseCard": {
                "customerReference": "1234567",
                "destinationPostalCode": "89123",
                "productDescriptors": [
                  "Test"
                ]
              },
              "responseCode": "D",
              "saleFlag": "S"
            },
            "universalToken": {
              "value": "444433-2D5C1A5C-001624-00001621-16BAAF4ACC6"
            }
          }
        ]
      }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime": "2022-05-16T14:59:54.000-07:00",
            "receiptColumns": 30,
            "amount": {
              "total": 5
            },
            "card": {
              "type": "VS",
              "entryMode": "M",
              "number": "XXXXXXXXXXXX2224",
              "token": {
                "value": "2224kz7vybyv1gs3"
              }
            },
            "device": {
              "capability": {
                "magstripe": "Y",
                "manualEntry": "Y"
              }
            },
            "merchant": {
              "mid": 8628968
            },
            "receipt": [
              {
                "key": "TransactionResponse",
                "printName": "Response",
                "printValue": "SALE CORRECTION"
              },
              {
                "key": "MaskedPAN",
                "printValue": "XXXXXXXXXXXX2224"
              },
              {
                "key": "CardEntryMode",
                "printName": "ENTRY METHOD",
                "printValue": "KEYED"
              },
              {
                "key": "SignatureRequired",
                "printValue": "N"
              }
            ],
            "server": {
              "name": "UTGAPI07CE"
            },
            "transaction": {
              "authSource": "E",
              "invoice": "0000000001",
              "responseCode": "D",
              "saleFlag": "S"
            }
          }
        ]
      }
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
      {
          "result": [
              {
                  "error": {
                      "longText": "GTV Msg: ERROR{0} 20018: no default category found, UC, Mod10=N TOKEN01CE ENGINE29CE",
                      "primaryCode": 9100,
                      "shortText": "SYSTEM ERROR"
                  },
                  "server": {
                      "name": "UTGAPI12CE"
                  }
              }
          ]
      }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
      {
          "result": [
              {
                  "error": {
                      "longText": "Token contains invalid characters UTGAPI08CE",
                      "primaryCode": 9864,
                      "shortText": "Invalid Token"
                  },
                  "server": {
                      "name": "UTGAPI08CE"
                  }
              }
          ]
      }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      {
          "result": [
              {
                  "error": {
                      "longText": "INTERNET FAILURE:  Timeout waiting for response across the Internet UTGAPI05CE",
                      "primaryCode": 9961,
                      "shortText": "INTERNET FAILURE"
                  },
                  "server": {
                      "name": "UTGAPI05CE"
                  }
              }
          ]
      }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
      {
          "result": [
              {
                  "error": {
                      "longText": "record not posted ENGINE21CE",
                      "primaryCode": 9844,
                      "shortText": "I/O ERROR"
                  },
                  "server": {
                      "name": "UTGAPI05CE"
                  }
              }
          ]
      }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
      {
          "result": [
              {
                  "error": {
                      "longText": "Invoice Not Found 00000000kl 0008628968  ENGINE29CE",
                      "primaryCode": 9815,
                      "shortText": "NO INV"
                  },
                  "server": {
                      "name": "UTGAPI13CE"
                  }
              }
          ]
      }
    RESPONSE
  end

  def successful_access_token_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime": "2022-06-22T15:27:51.000-07:00",
            "receiptColumns": 30,
            "credential": {
              "accessToken": "3F6A334E-01E5-4EDB-B4CE-0B1BEFC13518"
            },
            "device": {
              "capability": {
                "magstripe": "Y",
                "manualEntry": "Y"
              }
            },
            "server": {
              "name": "UTGAPI09CE"
            }
          }
        ]
      }
    RESPONSE
  end
end
