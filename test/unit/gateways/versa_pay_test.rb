require 'test_helper'

class VersaPayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = VersaPayGateway.new(fixtures(:versa_pay))
    @credit_card = credit_card
    @amount = 100
    @options = {
      email: 'test@gmail.com',
      billing_address: address.merge(name: 'Cure Tester'),
      ip_address: '127.0.0.1'
    }
  end

  def test_required_client_id_and_client_secret
    error = assert_raises ArgumentError do
      VersaPayGateway.new
    end

    assert_equal 'Missing required parameter: api_token', error.message
  end

  def test_supported_card_types
    assert_equal VersaPayGateway.supported_cardtypes, %i[visa master american_express discover]
  end

  def test_supported_countries
    assert_equal VersaPayGateway.supported_countries, ['US']
  end

  def test_request_headers_building
    gateway = VersaPayGateway.new(api_token: 'abc123', api_key: 'def456')
    headers = gateway.send :request_headers

    assert_equal 'application/json', headers['Content-Type']
    assert_equal 'Basic YWJjMTIzOmRlZjQ1Ng==', headers['Authorization']
  end

  def test_build_order_request_url
    action = :auth
    assert_equal @gateway.send(:url, action), "#{@gateway.test_url}/api/gateway/v1/orders/auth"
  end

  def test_error_code_from_errors
    # a HTTP 412 response structure
    error = @gateway.send(:error_code_from, { 'success' => false, 'errors' => ['fund_address_unspecified'], 'response_code' => 999 })
    assert_equal error, 'response_code: 999'
  end

  def test_error_code_from_gateway_error_code
    error = @gateway.send(:error_code_from, declined_errors)
    assert_equal error, 'gateway_error_code: 567.005 | response_code: 999'
  end

  def test_message_from_successful_purchase
    message = @gateway.send(:message_from, @gateway.send(:parse, successful_purchase_response))
    assert_equal message, 'Succeeded'
  end

  def test_message_from_failed_transaction_response
    message = @gateway.send(:message_from, declined_errors)
    assert_equal message, 'gateway_error_message: DECLINED | gateway_response_errors: [gateway - DECLINED]'
  end

  def test_message_from_failed_transaction_response_412
    message = @gateway.send(:message_from, { 'success' => false, 'errors' => ['fund_address_unspecified'], 'response_code' => 999 })
    assert_equal message, 'errors: fund_address_unspecified'
  end

  def test_successful_authorize
    billing_address = @options[:billing_address]
    @gateway.expects(:ssl_request).with(
      :post,
      'https://uat.versapay.com/api/gateway/v1/orders/auth',
      all_of(
        includes(
          "amount_cents\":\"#{@amount}",
          "email\":\"#{@options[:email]}\"",
          'currency":"USD"',
          "billing_name\":\"#{billing_address[:company]}\"",
          "billing_address\":\"#{billing_address[:address1]}\"",
          "billing_city\":\"#{billing_address[:city]}\"",
          'billing_country":"CAN"',
          "billing_email\":\"#{@options[:email]}\"",
          "billing_telephone\":\"#{billing_address[:phone]}\"",
          "name\":\"#{@credit_card.name}\"",
          "expiry_month\":\"0#{@credit_card.month}\"",
          "expiry_year\":#{@credit_card.year}",
          "card_number\":\"#{@credit_card.number}\"",
          "cvv\":\"#{@credit_card.verification_value}\""
        )
      ),
      anything
    ).
      returns(successful_authorize_response)
    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_successful_purchase
    billing_address = @options[:billing_address]
    @gateway.expects(:ssl_request).with(
      :post,
      'https://uat.versapay.com/api/gateway/v1/orders/sale',
      all_of(
        includes(
          "amount_cents\":\"#{@amount}",
          "email\":\"#{@options[:email]}\"",
          'currency":"USD"',
          "billing_name\":\"#{billing_address[:company]}\"",
          "billing_address\":\"#{billing_address[:address1]}\"",
          "billing_city\":\"#{billing_address[:city]}\"",
          'billing_country":"CAN"',
          "billing_email\":\"#{@options[:email]}\"",
          "billing_telephone\":\"#{billing_address[:phone]}\"",
          "name\":\"#{@credit_card.name}\"",
          "expiry_month\":\"0#{@credit_card.month}\"",
          "expiry_year\":#{@credit_card.year}",
          "card_number\":\"#{@credit_card.number}\"",
          "cvv\":\"#{@credit_card.verification_value}\""
        )
      ),
      anything
    ).
      returns(successful_purchase_response)
    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_capture
    authorization = 'some_authorize'
    @gateway.expects(:ssl_request).with(
      :post,
      'https://uat.versapay.com/api/gateway/v1/orders/capture',
      all_of(
        includes(
          "amount_cents\":#{@amount}",
          "transaction\":\"#{authorization}\""
        )
      ),
      anything
    ).
      returns(successful_capture_response)
    @gateway.capture(@amount, authorization, @options)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_authorize_response
    '{
        "success": true,
        "transaction": "3JAKFW7LPS3E",
        "authorization": "rnvlqd0o6uh7",
        "gateway_token": "1693864",
        "order": "ABCDF",
        "wallet": "7BMJIY82GASM",
        "credit_card": "CC8EE82PIWHW",
        "transactions": [
          {
            "token": "3JAKFW7LPS3E",
            "amount_in_cents": 500,
            "message": null,
            "link_url": null,
            "type": "transaction",
            "transaction_type": "request_money",
            "email": "spreedlyuat@gmail.com",
            "state": "completed",
            "transaction_reference": null,
            "unique_reference": null,
            "from_account": "John Smith",
            "to_account": "SpreedlyUAT",
            "process_on": null,
            "created_by_user": "ZGpuG4yfzg9uJKSGjuqw",
            "auto_withdraw": false,
            "auto_withdrawal_token": null,
            "created_at": "2024-10-01T11:17:54-04:00",
            "step_types": [
              "TransactionSteps::CardAuthorizeStep"
            ],
            "action": "authorize",
            "payment_method": "credit_card",
            "wallet": "7BMJIY82GASM",
            "credit_card": "CC8EE82PIWHW",
            "settlement_token": "MA48RC9CU55R",
            "currency": "usd",
            "approved_amount_cents": 500,
            "fee_amount_cents": 0,
            "fee_exempt": false,
            "gateway_response": {
              "token": "rnvlqd0o6uh7",
              "gateway_token": "1693864",
              "credit_card_bin": "489528",
              "credit_card_masked_number": "XXXXXXXXXXXX0006",
              "authorization_response": null,
              "authorization_code": "630753",
              "avs_response": "D",
              "approved_amount_cents": 500,
              "gateway_response": {
                "response": {
                  "authentication": {
                    "responsestatus": "success",
                    "sessionid": null
                  },
                  "content": {
                    "update": [
                      {
                        "customer": {
                          "refname": "customer",
                          "responsestatus": "success",
                          "id": "10448"
                        }
                      },
                      {
                        "contact": {
                          "refname": "contact",
                          "responsestatus": "failure",
                          "errors": {
                            "error": {
                              "number": "102.021",
                              "description": "name is invalid"
                            }
                          }
                        }
                      },
                      {
                        "contact": {
                          "refname": "shippingcontact",
                          "responsestatus": "failure",
                          "errors": {
                            "error": {
                              "number": "102.021",
                              "description": "name is invalid"
                            }
                          }
                        }
                      }
                    ],
                    "create": [
                      {
                        "contact": {
                          "refname": "contact",
                          "responsestatus": "success",
                          "id": "1804100"
                        }
                      },
                      {
                        "contact": {
                          "refname": "shippingcontact",
                          "responsestatus": "success",
                          "id": "1804101"
                        }
                      },
                      {
                        "salesdocument": {
                          "refname": "invoice",
                          "responsestatus": "success",
                          "id": "1653055"
                        }
                      },
                      {
                        "transaction": {
                          "refname": "33636d0a-63b1-4f71-a493-46ab68dc0fc1",
                          "responsestatus": "success",
                          "authorizationresponse": "APPROVAL",
                          "authorizationcode": "630753",
                          "avsresponse": "D",
                          "hash": "######0006",
                          "cardtype.name": "Visa",
                          "accountholder": "John Smith",
                          "amount": "5.00",
                          "account.id": "2013",
                          "token": "7b5a6d65-2408-4ce7-bfd9-f27d0e4d50f4",
                          "id": "1693864"
                        }
                      }
                    ]
                  }
                }
              },
              "credit_card": {
                "token": "7b5a6d65-2408-4ce7-bfd9-f27d0e4d50f4"
              },
              "gateway_status": "success",
              "error_code": null,
              "message": ""
            },
            "gateway_token": "1693864",
            "gateway_authorization_code": "630753",
            "gateway_error_scope": "tpro4",
            "gateway_error_message": "",
            "authorization_response": "100",
            "avs_response": "D",
            "credit_card_bin": "489528",
            "credit_card_masked_number": "XXXXXXXXXXXX0006",
            "credit_card_brand": "visa",
            "credit_card_expiry": "092025"
          }
        ],
        "response_code": 100
      }'
  end

  def successful_purchase_response
    '{
        "success": true,
        "transaction": "9FWZJY6PYSLC",
        "authorization": "d2qzud1t4jfy",
        "gateway_token": "1693860",
        "order": "ABCDF",
        "wallet": "4IV2MFVWC5MZ",
        "credit_card": "CC5NDN53P6B1",
        "transactions": [
          {
            "token": "9FWZJY6PYSLC",
            "amount_in_cents": 500,
            "message": null,
            "link_url": null,
            "type": "transaction",
            "transaction_type": "request_money",
            "email": "spreedlyuat@gmail.com",
            "state": "completed",
            "transaction_reference": null,
            "unique_reference": null,
            "from_account": "John Smith",
            "to_account": "SpreedlyUAT",
            "process_on": null,
            "created_by_user": "ZGpuG4yfzg9uJKSGjuqw",
            "auto_withdraw": false,
            "auto_withdrawal_token": null,
            "created_at": "2024-10-01T11:15:29-04:00",
            "step_types": [
              "TransactionSteps::CardSaleStep"
            ],
            "action": "sale",
            "payment_method": "credit_card",
            "wallet": "4IV2MFVWC5MZ",
            "credit_card": "CC5NDN53P6B1",
            "settlement_token": "MA48RC9CU55R",
            "currency": "usd",
            "approved_amount_cents": 500,
            "fee_amount_cents": 0,
            "fee_exempt": false,
            "gateway_response": {
              "token": "d2qzud1t4jfy",
              "gateway_token": "1693860",
              "credit_card_bin": "489528",
              "credit_card_masked_number": "XXXXXXXXXXXX0006",
              "authorization_response": null,
              "authorization_code": "883400",
              "avs_response": "D",
              "approved_amount_cents": 500,
              "gateway_response": {
                "response": {
                  "authentication": {
                    "responsestatus": "success",
                    "sessionid": null
                  },
                  "content": {
                    "update": [
                      {
                        "customer": {
                          "refname": "customer",
                          "responsestatus": "success",
                          "id": "10448"
                        }
                      },
                      {
                        "contact": {
                          "refname": "contact",
                          "responsestatus": "failure",
                          "errors": {
                            "error": {
                              "number": "102.021",
                              "description": "name is invalid"
                            }
                          }
                        }
                      },
                      {
                        "contact": {
                          "refname": "shippingcontact",
                          "responsestatus": "failure",
                          "errors": {
                            "error": {
                              "number": "102.021",
                              "description": "name is invalid"
                            }
                          }
                        }
                      }
                    ],
                    "create": [
                      {
                        "contact": {
                          "refname": "contact",
                          "responsestatus": "success",
                          "id": "1804092"
                        }
                      },
                      {
                        "contact": {
                          "refname": "shippingcontact",
                          "responsestatus": "success",
                          "id": "1804093"
                        }
                      },
                      {
                        "salesdocument": {
                          "refname": "invoice",
                          "responsestatus": "success",
                          "id": "1653051"
                        }
                      },
                      {
                        "transaction": {
                          "refname": "8c8d7108-e116-4b1b-beab-9866d0505d3e",
                          "responsestatus": "success",
                          "authorizationresponse": "APPROVAL",
                          "authorizationcode": "883400",
                          "avsresponse": "D",
                          "hash": "######0006",
                          "cardtype.name": "Visa",
                          "accountholder": "John Smith",
                          "amount": "5.00",
                          "account.id": "2013",
                          "token": "42aae6ae-a70e-4659-83c7-b09019d5f687",
                          "id": "1693860"
                        }
                      }
                    ]
                  }
                }
              },
              "credit_card": {
                "token": "42aae6ae-a70e-4659-83c7-b09019d5f687"
              },
              "gateway_status": "success",
              "error_code": null,
              "message": ""
            },
            "gateway_token": "1693860",
            "gateway_authorization_code": "883400",
            "gateway_error_scope": "tpro4",
            "gateway_error_message": "",
            "authorization_response": "100",
            "avs_response": "D",
            "credit_card_bin": "489528",
            "credit_card_masked_number": "XXXXXXXXXXXX0006",
            "credit_card_brand": "visa",
            "credit_card_expiry": "092025"
          }
        ],
        "response_code": 100
      }'
  end

  def successful_verify_response
    {
      success: true,
      transaction: '5WWQLJ95M4UJ',
      order: 'ABCDF',
      wallet: '7WRP6YFJGNND',
      credit_card: 'CC6AEGBDGIVA',
      transactions: [
        {
          token: '5WWQLJ95M4UJ',
          amount_in_cents: 0,
          message: null,
          link_url: null,
          type: 'transaction',
          transaction_type: 'request_money',
          email: 'spreedlyuat@gmail.com',
          state: 'completed',
          transaction_reference: null,
          unique_reference: null,
          from_account: 'John Smith',
          to_account: 'SpreedlyUAT',
          process_on: null,
          created_by_user: 'ZGpuG4yfzg9uJKSGjuqw',
          auto_withdraw: false,
          auto_withdrawal_token: null,
          created_at: '2024-10-02T11:20:59-04:00',
          step_types: [
            'TransactionSteps::CardVerifyStep'
          ],
          action: 'verify',
          payment_method: 'credit_card',
          wallet: '7WRP6YFJGNND',
          credit_card: 'CC6AEGBDGIVA',
          settlement_token: 'MA48RC9CU55R',
          currency: 'usd',
          approved_amount_cents: 0,
          fee_amount_cents: 0,
          fee_exempt: false,
          gateway_response: {
            token: 'qa3qhyo96hci',
            gateway_token: '1695157',
            credit_card_bin: '489528',
            credit_card_masked_number: 'XXXXXXXXXXXX0006',
            authorization_response: null,
            authorization_code: '789749',
            avs_response: 'D',
            cvv_response: 'P',
            gateway_response: {
              response: {
                authentication: {
                  responsestatus: 'success',
                  sessionid: null
                },
                content: {
                  update: [
                    {
                      customer: {
                        refname: 'customer',
                        responsestatus: 'success',
                        id: '10441'
                      }
                    },
                    {
                      contact: {
                        refname: 'contact',
                        responsestatus: 'failure',
                        errors: {
                          error: {
                            number: '102.021',
                            description: 'name is invalid'
                          }
                        }
                      }
                    },
                    {
                      contact: {
                        refname: 'shippingcontact',
                        responsestatus: 'failure',
                        errors: {
                          error: {
                            number: '102.021',
                            description: 'name is invalid'
                          }
                        }
                      }
                    }
                  ],
                  create: [
                    {
                      contact: {
                        refname: 'contact',
                        responsestatus: 'success',
                        id: '1806296'
                      }
                    },
                    {
                      contact: {
                        refname: 'shippingcontact',
                        responsestatus: 'success',
                        id: '1806297'
                      }
                    },
                    {
                      salesdocument: {
                        refname: 'invoice',
                        responsestatus: 'success',
                        id: '1654169'
                      }
                    },
                    {
                      transaction: {
                        refname: 'c1ff4389-16e3-40c5-99b1-46a006528a35',
                        responsestatus: 'success',
                        authorizationresponse: 'APPROVAL',
                        authorizationcode: '789749',
                        cvvresponse: 'P',
                        avsresponse: 'D',
                        hash: '######0006',
                        "cardtype.name": 'Visa',
                        accountholder: 'John Smith',
                        amount: '0.00',
                        "account.id": '2013',
                        token: '9bbb5a74-2df1-489a-8fdd-595fab2dd8b6',
                        id: '1695157'
                      }
                    }
                  ]
                }
              }
            },
            credit_card: {
              token: '9bbb5a74-2df1-489a-8fdd-595fab2dd8b6'
            },
            approved_amount_cents: 0,
            gateway_status: 'success',
            error_code: null,
            message: ''
          },
          gateway_token: '1695157',
          gateway_authorization_code: '789749',
          gateway_error_scope: 'tpro4',
          gateway_error_message: '',
          authorization_response: '100',
          avs_response: 'D',
          cvv_response: 'P',
          credit_card_bin: '489528',
          credit_card_masked_number: 'XXXXXXXXXXXX0006',
          credit_card_brand: 'visa',
          credit_card_expiry: '092025'
        }
      ],
      response_code: 100
    }
  end

  def successful_capture_response
    '{
      "success": true,
      "transaction": "24CBTZLZWRBL",
      "authorization": "hh3mv9rf6rq2",
      "gateway_token": "1695201",
      "order": "ABCDF",
      "wallet": "8UTAGL9Q9A3Y",
      "credit_card": "CC4GDVXJD8KW",
      "transactions": [
        {
          "token": "24CBTZLZWRBL",
          "amount_in_cents": 500,
          "message": null,
          "link_url": null,
          "type": "transaction",
          "transaction_type": "request_money",
          "email": "spreedlyuat@gmail.com",
          "state": "completed",
          "transaction_reference": null,
          "unique_reference": null,
          "from_account": "Longbob Longsen",
          "to_account": "SpreedlyUAT",
          "process_on": null,
          "created_by_user": "ZGpuG4yfzg9uJKSGjuqw",
          "auto_withdraw": false,
          "auto_withdrawal_token": null,
          "created_at": "2024-10-02T11:53:52-04:00",
          "step_types": [
            "TransactionSteps::CardCaptureStep"
          ],
          "action": "capture",
          "payment_method": "credit_card",
          "wallet": "8UTAGL9Q9A3Y",
          "credit_card": "CC4GDVXJD8KW",
          "settlement_token": "MA48RC9CU55R",
          "currency": "usd",
          "approved_amount_cents": 500,
          "fee_amount_cents": 0,
          "fee_exempt": false,
          "gateway_response": {
            "token": "hh3mv9rf6rq2",
            "gateway_token": "1695201",
            "authorization_response": null,
            "authorization_code": "085997",
            "avs_response": "D",
            "approved_amount_cents": 500,
            "gateway_response": {
              "response": {
                "authentication": {
                  "responsestatus": "success",
                  "sessionid": null
                },
                "content": {
                  "create": {
                    "transaction": {
                      "refname": "90a02da5-813e-40cd-a1ae-ba7ac1ef6b62",
                      "responsestatus": "success",
                      "authorizationresponse": "APPROVAL",
                      "authorizationcode": "085997",
                      "avsresponse": "D",
                      "hash": "######0006",
                      "cardtype.name": "Visa",
                      "accountholder": "Longbob Longsen",
                      "amount": "5.00",
                      "account.id": "2013",
                      "id": "1695201"
                    }
                  }
                }
              }
            },
            "gateway_status": "success",
            "error_code": null,
            "message": ""
          },
          "gateway_token": "1695201",
          "gateway_authorization_code": "085997",
          "gateway_error_scope": "tpro4",
          "gateway_error_message": "",
          "authorization_response": "100",
          "avs_response": "D",
          "credit_card_brand": "visa",
          "credit_card_expiry": "122025"
        }
      ],
      "response_code": 100
    }'
  end

  def declined_errors
    { 'success' => false,
     'transactions' =>
      [{ 'state' => 'declined',
        'step_types' => ['TransactionSteps::CardVerifyStep'],
        'action' => 'verify',
        'fee_exempt' => false,
        'gateway_response' =>
         { 'errors' => { 'gateway' => ['DECLINED'] },
          'gateway_response' => { 'response' => { 'authentication' => { 'responsestatus' => 'success', 'sessionid' => nil } } },
          'gateway_status' => 'failure',
          'authorization_response' => '567.005: DECLINED',
          'error_code' => '567.005',
          'message' => 'DECLINED' },
        'gateway_token' => '1695306',
        'gateway_authorization_response' => '567.005: DECLINED',
        'gateway_error_code' => '567.005',
        'gateway_error_message' => 'DECLINED',
        'authorization_response' => '200',
        'credit_card_bin' => '426428',
        'credit_card_masked_number' => 'XXXXXXXXXXXX4500',
        'credit_card_brand' => 'visa',
        'credit_card_expiry' => '092025' }],
     'response_code' => 999 }
  end

  def pre_scrubbed
    <<~PRE_SCRUBBED
      opening connection to uat.versapay.com:443...
      opened
      starting SSL for uat.versapay.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /api/gateway/v1/orders/sale HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic SOMETHING=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: uat.versapay.com\r\nContent-Length: 721\r\n\r\n"
      <- "{\"amount_cents\":500,\"contact\":{\"email\":\"john.smith@test.com\"},\"order\":{\"identifier\":\"ABCDF\",\"number\":\"25e0293a-d1d2-4ba9-ad5e-b322a4fb2e8c\",\"date\":\"2024-10-02\",\"draft\":false,\"amount_cents\":\"500\",\"currency\":\"USD\",\"billing_name\":\"Widgets Inc\",\"billing_address\":\"456 My Street\",\"billing_address2\":\"Apt 1\",\"billing_city\":\"Ottawa\",\"billing_country\":\"CAN\",\"billing_email\":\"john.smith@test.com\",\"billing_telephone\":\"(555)555-5555\",\"billing_postalcode\":\"K1C2N6\",\"billing_state_province\":\"ON\"},\"credit_card\":{\"name\":\"Longbob Longsen\",\"expiry_month\":\"12\",\"expiry_year\":2025,\"card_number\":\"4895281000000006\",\"cvv\":\"123\",\"address\":{\"address_1\":\"456 My Street\",\"city\":\"Ottawa\",\"province\":\"ON\",\"postal_code\":\"K1C2N6\",\"country\":\"CAN\"}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Wed, 02 Oct 2024 21:55:50 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "set-cookie: AWSALBTG=SOMETHING; Expires=Wed, 09 Oct 2024 21:55:48 GMT; Path=/\r\n"
      -> "set-cookie: AWSALBTGCORS=SOMETHING; Expires=Wed, 09 Oct 2024 21:55:48 GMT; Path=/; SameSite=None; Secure\r\n"
      -> "x-xss-protection: 1; mode=block\r\n"
      -> "x-content-type-options: nosniff\r\n"
      -> "x-download-options: noopen\r\n"
      -> "x-permitted-cross-domain-policies: none\r\n"
      -> "referrer-policy: strict-origin-when-cross-origin\r\n"
      -> "etag: W/\"86b028f98d26b815749e0550ac722270\"\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "x-request-id: 6af9640c-78e6-49c8-9d0b-c0d8920dc8e6\r\n"
      -> "x-runtime: 2.352706\r\n"
      -> "strict-transport-security: max-age=63072000; includeSubDomains\r\n"
      -> "access-control-allow-headers: X-Requested-With\r\n"
      -> "access-control-allow-methods: GET, HEAD, OPTIONS\r\n"
      -> "access-control-allow-origin: https://testquote.teacherslife.com http://testquote.teacherslife.com\r\n"
      -> "p3p: CP=\"This_site_does_not_have_a_p3p_policy\"\r\n"
      -> "CF-Cache-Status: DYNAMIC\r\n"
      -> "Server: cloudflare\r\n"
      -> "CF-RAY: 8cc7f053e9186787-ATL\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "3f3\r\n"
      reading 1011 bytes...
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~POST_SCRUBBED
      opening connection to uat.versapay.com:443...
      opened
      starting SSL for uat.versapay.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /api/gateway/v1/orders/sale HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: uat.versapay.com\r\nContent-Length: 721\r\n\r\n"
      <- "{\"amount_cents\":500,\"contact\":{\"email\":\"john.smith@test.com\"},\"order\":{\"identifier\":\"ABCDF\",\"number\":\"25e0293a-d1d2-4ba9-ad5e-b322a4fb2e8c\",\"date\":\"2024-10-02\",\"draft\":false,\"amount_cents\":\"500\",\"currency\":\"USD\",\"billing_name\":\"Widgets Inc\",\"billing_address\":\"456 My Street\",\"billing_address2\":\"Apt 1\",\"billing_city\":\"Ottawa\",\"billing_country\":\"CAN\",\"billing_email\":\"john.smith@test.com\",\"billing_telephone\":\"(555)555-5555\",\"billing_postalcode\":\"K1C2N6\",\"billing_state_province\":\"ON\"},\"credit_card\":{\"name\":\"Longbob Longsen\",\"expiry_month\":\"12\",\"expiry_year\":2025,\"card_number\":\"[FILTERED]",\"cvv\":\"[FILTERED]",\"address\":{\"address_1\":\"456 My Street\",\"city\":\"Ottawa\",\"province\":\"ON\",\"postal_code\":\"K1C2N6\",\"country\":\"CAN\"}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Wed, 02 Oct 2024 21:55:50 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "set-cookie: AWSALBTG=SOMETHING; Expires=Wed, 09 Oct 2024 21:55:48 GMT; Path=/\r\n"
      -> "set-cookie: AWSALBTGCORS=SOMETHING; Expires=Wed, 09 Oct 2024 21:55:48 GMT; Path=/; SameSite=None; Secure\r\n"
      -> "x-xss-protection: 1; mode=block\r\n"
      -> "x-content-type-options: nosniff\r\n"
      -> "x-download-options: noopen\r\n"
      -> "x-permitted-cross-domain-policies: none\r\n"
      -> "referrer-policy: strict-origin-when-cross-origin\r\n"
      -> "etag: W/\"86b028f98d26b815749e0550ac722270\"\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "x-request-id: 6af9640c-78e6-49c8-9d0b-c0d8920dc8e6\r\n"
      -> "x-runtime: 2.352706\r\n"
      -> "strict-transport-security: max-age=63072000; includeSubDomains\r\n"
      -> "access-control-allow-headers: X-Requested-With\r\n"
      -> "access-control-allow-methods: GET, HEAD, OPTIONS\r\n"
      -> "access-control-allow-origin: https://testquote.teacherslife.com http://testquote.teacherslife.com\r\n"
      -> "p3p: CP=\"This_site_does_not_have_a_p3p_policy\"\r\n"
      -> "CF-Cache-Status: DYNAMIC\r\n"
      -> "Server: cloudflare\r\n"
      -> "CF-RAY: 8cc7f053e9186787-ATL\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "3f3\r\n"
      reading 1011 bytes...
      Conn close
    POST_SCRUBBED
  end
end
