require 'test_helper'

class PayArcTest < Test::Unit::TestCase
  def setup
    @gateway = PayArcGateway.new(fixtures(:pay_arc))
    credit_card_options = {
      month: '12',
      year: '2022',
      first_name: 'Rex Joseph',
      last_name: '',
      verification_value: '999'
    }
    @credit_card = credit_card('4111111111111111', credit_card_options)
    @invalid_credit_card = credit_card('3111111111111111', credit_card_options)
    @invalid_cvv_card = credit_card('3111111111111111', credit_card_options.update(verification_value: '123'))
    @amount = 100

    @options = {
      billing_address: address,
      description: 'Store Purchase',
      card_source: 'INTERNET',
      address_line1: '920 Sunnyslope Ave',
      address_line2: 'Bronx',
      city: 'New York',
      state: 'New York',
      zip: '10469',
      country: 'USA'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(
      successful_token_response
    ).then.returns(
      successful_charge_response
    )
    response = @gateway.purchase(1022, @credit_card, @options)
    assert_success response

    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
    assert response.test?
  end

  # Failed due to already used / invalid token
  def test_failure_purchase
    @gateway.expects(:ssl_post).times(2).returns(
      successful_token_response
    ).then.returns(
      failed_charge_response
    )
    response = @gateway.purchase(1022, @credit_card, @options)
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  # Failed due to invalid credit card
  def test_failed_token
    @gateway.expects(:ssl_post).returns(failed_token_response)
    response = @gateway.token(@invalid_credit_card, @options)
    assert_failure response
  end

  # Failed due to invalid cvv
  def test_invalid_cvv
    @gateway.expects(:ssl_post).returns(failed_token_response)
    response = @gateway.token(@invalid_cvv_card, @options)
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_token_response)
    response = @gateway.verify(@invalid_cvv_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_token_response)
    response = @gateway.verify(@invalid_credit_card, @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void('FHBDKH123DFKG', @options)
    assert_success response
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void('12345', @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).times(2).returns(
      successful_token_response
    ).then.returns(
      successful_authorize_response
    )
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'authorized', response.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).times(2).returns(
      successful_token_response
    ).then.returns(
      failed_authorize_response
    )
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, 'WSHDHEHKDH')
    assert_success response
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
    assert_equal 'refunded', response.message
  end

  def test_successful_partial_refund
    @gateway.expects(:ssl_post).returns(successful_partial_refund_response)
    response = @gateway.refund(@amount - 1, 'WSHDHEHKDH')
    assert_success response
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
    assert_equal 'partial_refund', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(@amount, 'WSHDHEHKDH')
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    transcript = @gateway.scrub(pre_scrubbed)
    assert_scrubbed('quaslad-test.123.token-for-scrub', transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_equal transcript, post_scrubbed
  end

  private

  def pre_scrubbed
    %{
      <- "POST /v1/tokens HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Bearer token-fortesting\nAccept: application/json\r\nUser-Agent: PayArc ActiveMerchantBindings/1.119.0\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nHost: testapi.payarc.net\r\nContent-Length: 253\r\n\r\n"
      <- "card_source=INTERNET&amount=100&currency=usd&statement_description=&card_number=23445123456&exp_month=12&exp_year=2022&cvv=983&address_line1=920+Sunnyslope+Ave&address_line2=Bronx&city=New+York&state=New+York&zip=10469&country=USA&card_holder_name="

      -> "{"data":{"object":"Token","id":"0q8lLw88mlqEwYNE","used":false,"ip":null,"tokenization_method":null,"created_at":1620645488,"updated_at":1620645488,"card":{"data":{"object":"Card","id":"PMyLv0m5v151095m","address1":"920 Sunnyslope Ave","address2":"Bronx","card_source":"INTERNET","card_holder_name":"","is_default":0,"exp_month":"12","exp_year":"2022","is_verified":0,"fingerprint":"1Lv0NL11yvy5yL05","city":"New York","state":"New York","zip":"10469","brand":"V","last4digit":"1111","first6digi"
      -> "t":411111,"country":"USA","avs_status":null,"cvc_status":null,"address_check_passed":0,"zip_check_passed":0,"customer_id":null,"created_at":1620645488,"updated_at":1620645488}}},"meta":{"include":[],"custom":[]}}"
      }
  end

  def post_scrubbed
    %{
      <- "POST /v1/tokens HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Bearer [FILTERED]Accept: application/json\r\nUser-Agent: PayArc ActiveMerchantBindings/1.119.0\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nHost: testapi.payarc.net\r\nContent-Length: 253\r\n\r\n"
      <- "card_source=INTERNET&amount=100&currency=usd&statement_description=&card_number=[FILTERED]&exp_month=12&exp_year=2022&cvv=[BLANK]&address_line1=920+Sunnyslope+Ave&address_line2=Bronx&city=New+York&state=New+York&zip=10469&country=USA&card_holder_name="

      -> "{"data":{"object":"Token","id":"0q8lLw88mlqEwYNE","used":false,"ip":null,"tokenization_method":null,"created_at":1620645488,"updated_at":1620645488,"card":{"data":{"object":"Card","id":"PMyLv0m5v151095m","address1":"920 Sunnyslope Ave","address2":"Bronx","card_source":"INTERNET","card_holder_name":"","is_default":0,"exp_month":"12","exp_year":"2022","is_verified":0,"fingerprint":"1Lv0NL11yvy5yL05","city":"New York","state":"New York","zip":"10469","brand":"V","last4digit":"1111","first6digi"
      -> "t":411111,"country":"USA","avs_status":null,"cvc_status":null,"address_check_passed":0,"zip_check_passed":0,"customer_id":null,"created_at":1620645488,"updated_at":1620645488}}},"meta":{"include":[],"custom":[]}}"
      }
  end

  def successful_purchase_response
    %(
        {
          "data": {
              "object": "Charge",
              "id": "LDoBnOnRnRWLOyWX",
              "amount": 1010,
              "amount_approved": 0,
              "amount_refunded": 0,
              "amount_captured": 1010,
              "amount_voided": 0,
              "application_fee_amount": 0,
              "tip_amount": 0,
              "payarc_fees": 0,
              "type": "Sale",
              "net_amount": 0,
              "captured": 1,
              "is_refunded": 0,
              "status": "Bad Request - Try Again",
              "auth_code": null,
              "failure_code": "E0911",
              "failure_message": "SystemError",
              "charge_description": null,
              "statement_description": "Bubbles Shop",
              "invoice": null,
              "under_review": 0,
              "created_at": 1622000885,
              "updated_at": 1622000896,
              "email": null,
              "phone_number": null,
              "card_level": "LEVEL2",
              "sales_tax": 10,
              "purchase_order": "ABCD",
              "supplier_reference_number": null,
              "customer_ref_id": null,
              "ship_to_zip": null,
              "amex_descriptor": null,
              "customer_vat_number": null,
              "summary_commodity_code": null,
              "shipping_charges": null,
              "duty_charges": null,
              "ship_from_zip": null,
              "destination_country_code": null,
              "vat_invoice": null,
              "order_date": null,
              "tax_category": null,
              "tax_type": null,
              "tax_rate": null,
              "tax_amount": null,
              "created_by": "bubbles@eyepaste.com",
              "terminal_register": null,
              "tip_amount_refunded": null,
              "sales_tax_refunded": null,
              "shipping_charges_refunded": null,
              "duty_charges_refunded": null,
              "pax_reference_number": null,
              "refund_reason": null,
              "refund_description": null,
              "surcharge": 0,
              "toll_amount": null,
              "refund": {
                  "data": []
              },
              "card": {
                  "data": {
                      "object": "Card",
                      "id": "15y2901NPMP90MLv",
                      "address1": "920 Sunnyslope Ave",
                      "address2": "Bronx",
                      "card_source": "INTERNET",
                      "card_holder_name": "Rex Joseph",
                      "is_default": 0,
                      "exp_month": "12",
                      "exp_year": "2022",
                      "is_verified": 0,
                      "fingerprint": "1Lv0NN9LyN5Pm105",
                      "city": "New York",
                      "state": "New York",
                      "zip": "10469",
                      "brand": "V",
                      "last4digit": "1111",
                      "first6digit": 411111,
                      "country": "USA",
                      "avs_status": null,
                      "cvc_status": null,
                      "address_check_passed": 0,
                      "zip_check_passed": 0,
                      "customer_id": null,
                      "created_at": 1622000879,
                      "updated_at": 1622000896
                  }
              }
          },
          "meta": {
              "include": [
                  "review"
              ],
              "custom": []
          }
      }
    )
  end

  def successful_token_response
    %{
      {
          "data": {
              "object": "Token",
              "id": "0mYL8wllq08YwlNE",
              "used": false,
              "ip": null,
              "tokenization_method": null,
              "created_at": 1620412546,
              "updated_at": 1620412546,
              "card": {
                  "data": {
                      "object": "Card",
                      "id": "59P1y0PL1M9L0vML",
                      "address1": "920 Sunnyslope Ave",
                      "address2": "Bronx",
                      "card_source": "INTERNET",
                      "card_holder_name": "Rex Joseph",
                      "is_default": 0,
                      "exp_month": "12",
                      "exp_year": "2022",
                      "is_verified": 0,
                      "fingerprint": "1Lv0NN9LyN5Pm105",
                      "city": "New York",
                      "state": "New York",
                      "zip": "10469",
                      "brand": "V",
                      "last4digit": "1111",
                      "first6digit": 411111,
                      "country": "USA",
                      "avs_status": null,
                      "cvc_status": null,
                      "address_check_passed": 0,
                      "zip_check_passed": 0,
                      "customer_id": null,
                      "created_at": 1620412546,
                      "updated_at": 1620412546
                  }
              }
          },
          "meta": {
              "include": [],
              "custom": []
          }
      }
    }
  end

  def failed_token_response
    %{
      {
    "status": "error",
    "code": 0,
    "message": "Invalid Card",
    "status_code": 409,
    "exception": "App\\Containers\\Card\\Exceptions\\InvalidCardDetailsException",
    "file": "/home/deploy/payarc.com/app/Containers/Token/Actions/CreateTokenAction.php",
    "line": 45
    }
   }
  end

  def successful_charge_response
    %{
      {
          "data": {
              "object": "Charge",
              "id": "LDoBnOnRnyLyOyWX",
              "amount": 1010,
              "amount_approved": "1010",
              "amount_refunded": 0,
              "amount_captured": "1010",
              "amount_voided": 0,
              "application_fee_amount": 0,
              "tip_amount": 0,
              "payarc_fees": 29,
              "type": "Sale",
              "net_amount": 981,
              "captured": "1",
              "is_refunded": 0,
              "status": "submitted_for_settlement",
              "auth_code": "TAS353",
              "failure_code": null,
              "failure_message": null,
              "charge_description": null,
              "statement_description": "Testing",
              "invoice": null,
              "under_review": false,
              "created_at": 1620473990,
              "updated_at": 1620473992,
              "email": null,
              "phone_number": null,
              "card_level": "LEVEL1",
              "sales_tax": null,
              "purchase_order": null,
              "supplier_reference_number": null,
              "customer_ref_id": null,
              "ship_to_zip": null,
              "amex_descriptor": null,
              "customer_vat_number": null,
              "summary_commodity_code": null,
              "shipping_charges": null,
              "duty_charges": null,
              "ship_from_zip": null,
              "destination_country_code": null,
              "vat_invoice": null,
              "order_date": null,
              "tax_category": null,
              "tax_type": null,
              "tax_rate": null,
              "tax_amount": null,
              "created_by": "bubbles@eyepaste.com",
              "terminal_register": null,
              "tip_amount_refunded": null,
              "sales_tax_refunded": null,
              "shipping_charges_refunded": null,
              "duty_charges_refunded": null,
              "pax_reference_number": null,
              "refund_reason": null,
              "refund_description": null,
              "surcharge": 0,
              "toll_amount": null,
              "refund": {
                  "data": []
              },
              "card": {
                  "data": {
                      "object": "Card",
                      "id": "mP1Lv0NP19mN05MN",
                      "address1": "920 Sunnyslope Ave",
                      "address2": "Bronx",
                      "card_source": "INTERNET",
                      "card_holder_name": "Rex Joseph",
                      "is_default": 0,
                      "exp_month": "12",
                      "exp_year": "2022",
                      "is_verified": 0,
                      "fingerprint": "1Lv0NN9LyN5Pm105",
                      "city": "New York",
                      "state": "New York",
                      "zip": "10469",
                      "brand": "V",
                      "last4digit": "1111",
                      "first6digit": 411111,
                      "country": "USA",
                      "avs_status": null,
                      "cvc_status": null,
                      "address_check_passed": 0,
                      "zip_check_passed": 0,
                      "customer_id": null,
                      "created_at": 1620473969,
                      "updated_at": 1620473992
                  }
              }
          },
          "meta": {
              "include": [
                  "review"
              ],
              "custom": []
          }
      }
    }
  end

  def failed_capture_response
    %{
      {
          "status": "error",
          "code": 0,
          "message": "The given data was invalid.",
          "errors": {
              "currency": [
                  "The selected currency is invalid."
              ],
              "customer_id": [
                  "The customer id field is required when none of token id / cvv / exp year / exp month / card number are present."
              ],
              "token_id": [
                  "The token id field is required when none of customer id / cvv / exp year / exp month / card number are present."
              ],
              "card_number": [
                  "The card number field is required when none of token id / customer id are present."
              ],
              "exp_month": [
                  "The exp month field is required when none of token id / customer id are present."
              ],
              "exp_year": [
                  "The exp year field is required when none of token id / customer id are present."
              ]
          },
          "status_code": 422,
          "exception": "Illuminate\\Validation\\ValidationException",
          "file": "/home/deploy/payarc.com/vendor/laravel/framework/src/Illuminate/Foundation/Http/FormRequest.php",
          "line": 130
      }
    }
  end

  def successful_void_response
    %{
        {
        "data": {
            "object": "Charge",
            "id": "LDoBnOnRnyLyOyWX",
            "amount": 1010,
            "amount_approved": 1010,
            "amount_refunded": 0,
            "amount_captured": 1010,
            "amount_voided": 1010,
            "application_fee_amount": 0,
            "tip_amount": 0,
            "payarc_fees": 29,
            "type": "Sale",
            "net_amount": 0,
            "captured": 1,
            "is_refunded": 0,
            "status": "void",
            "auth_code": "TAS353",
            "failure_code": null,
            "failure_message": null,
            "charge_description": null,
            "statement_description": "Testing",
            "invoice": null,
            "under_review": 0,
            "created_at": 1620473990,
            "updated_at": 1620495791,
            "email": null,
            "phone_number": null,
            "card_level": "LEVEL1",
            "sales_tax": null,
            "purchase_order": null,
            "supplier_reference_number": null,
            "customer_ref_id": null,
            "ship_to_zip": null,
            "amex_descriptor": null,
            "customer_vat_number": null,
            "summary_commodity_code": null,
            "shipping_charges": null,
            "duty_charges": null,
            "ship_from_zip": null,
            "destination_country_code": null,
            "vat_invoice": null,
            "order_date": null,
            "tax_category": null,
            "tax_type": null,
            "tax_rate": null,
            "tax_amount": null,
            "created_by": "bubbles@eyepaste.com",
            "terminal_register": null,
            "tip_amount_refunded": null,
            "sales_tax_refunded": null,
            "shipping_charges_refunded": null,
            "duty_charges_refunded": null,
            "pax_reference_number": null,
            "refund_reason": null,
            "refund_description": null,
            "surcharge": 0,
            "toll_amount": null,
            "refund": {
                "data": []
            },
            "card": {
                "data": {
                    "object": "Card",
                    "id": "mP1Lv0NP19mN05MN",
                    "address1": "920 Sunnyslope Ave",
                    "address2": "Bronx",
                    "card_source": "INTERNET",
                    "card_holder_name": "Rex Joseph",
                    "is_default": 0,
                    "exp_month": "12",
                    "exp_year": "2022",
                    "is_verified": 0,
                    "fingerprint": "1Lv0NN9LyN5Pm105",
                    "city": "New York",
                    "state": "New York",
                    "zip": "10469",
                    "brand": "V",
                    "last4digit": "1111",
                    "first6digit": 411111,
                    "country": "USA",
                    "avs_status": null,
                    "cvc_status": null,
                    "address_check_passed": 0,
                    "zip_check_passed": 0,
                    "customer_id": null,
                    "created_at": 1620473969,
                    "updated_at": 1620473992
                }
            }
        },
        "meta": {
            "include": [
                "review"
            ],
            "custom": []
        }
       }
    }
  end

  def failed_void_response
    %{
      {
        "status": "error",
        "code": 0,
        "message": "Property [is_under_review] does not exist on this collection instance.",
        "status_code": 500,
        "exception": "Exception",
        "file": "/home/deploy/payarc.com/vendor/laravel/framework/src/Illuminate/Support/Collection.php",
        "line": 2160
      }
    }
  end

  def successful_authorize_response
    %{
        {
          "data": {
              "object": "Charge",
              "id": "BXMbnObLnoDMORoD",
              "amount": 1010,
              "amount_approved": "1010",
              "amount_refunded": 0,
              "amount_captured": 0,
              "amount_voided": 0,
              "application_fee_amount": 0,
              "tip_amount": 0,
              "payarc_fees": 0,
              "type": "Sale",
              "net_amount": 0,
              "captured": "0",
              "is_refunded": 0,
              "status": "authorized",
              "auth_code": "TAS363",
              "failure_code": null,
              "failure_message": null,
              "charge_description": null,
              "statement_description": "Testing",
              "invoice": null,
              "under_review": false,
              "created_at": 1620651112,
              "updated_at": 1620651115,
              "email": null,
              "phone_number": null,
              "card_level": "LEVEL1",
              "sales_tax": null,
              "purchase_order": null,
              "supplier_reference_number": null,
              "customer_ref_id": null,
              "ship_to_zip": null,
              "amex_descriptor": null,
              "customer_vat_number": null,
              "summary_commodity_code": null,
              "shipping_charges": null,
              "duty_charges": null,
              "ship_from_zip": null,
              "destination_country_code": null,
              "vat_invoice": null,
              "order_date": null,
              "tax_category": null,
              "tax_type": null,
              "tax_rate": null,
              "tax_amount": null,
              "created_by": "bubbles@eyepaste.com",
              "terminal_register": null,
              "tip_amount_refunded": null,
              "sales_tax_refunded": null,
              "shipping_charges_refunded": null,
              "duty_charges_refunded": null,
              "pax_reference_number": null,
              "refund_reason": null,
              "refund_description": null,
              "surcharge": 0,
              "toll_amount": null,
              "refund": {
                  "data": []
              },
              "card": {
                  "data": {
                      "object": "Card",
                      "id": "mP1Lv0NP19y105MN",
                      "address1": "920 Sunnyslope Ave",
                      "address2": "Bronx",
                      "card_source": "INTERNET",
                      "card_holder_name": "Rex Joseph",
                      "is_default": 0,
                      "exp_month": "12",
                      "exp_year": "2022",
                      "is_verified": 0,
                      "fingerprint": "1Lv0NN9LyN5Pm105",
                      "city": "New York",
                      "state": "New York",
                      "zip": "10469",
                      "brand": "V",
                      "last4digit": "1111",
                      "first6digit": 411111,
                      "country": "USA",
                      "avs_status": null,
                      "cvc_status": null,
                      "address_check_passed": 0,
                      "zip_check_passed": 0,
                      "customer_id": null,
                      "created_at": 1620651066,
                      "updated_at": 1620651115
                  }
              }
          },
          "meta": {
              "include": [
                  "review"
              ],
              "custom": []
          }
      }
    }
  end

  def failed_authorize_response
    %{
       {
          "status": "error",
          "code": 0,
          "message": "The requested token is not valid or already used",
          "status_code": 400,
          "exception": "App\\Containers\\Customer\\Exceptions\\InvalidTokenException",
          "file": "/home/deploy/payarc.com/app/Containers/Charge/Actions/CreateSaleAction.php",
          "line": 260
      }
    }
  end

  def failed_charge_response
    %{
       {
          "status": "error",
          "code": 0,
          "message": "The requested token is not valid or already used",
          "status_code": 400,
          "exception": "App\\Containers\\Customer\\Exceptions\\InvalidTokenException",
          "file": "/home/deploy/payarc.com/app/Containers/Charge/Actions/CreateSaleAction.php",
          "line": 260
      }
    }
  end

  def successful_refund_response
    %{
          {
          "data": {
              "object": "Refund",
              "id": "x9bQvpYvxBOYOqyB",
              "refund_amount": "1010",
              "currency": "usd",
              "status": "refunded",
              "reason": "requested_by_customer",
              "description": "",
              "email": null,
              "receipt_number": null,
              "charge_id": "LnbDBOMMbWXyORXM",
              "created_at": 1620734715,
              "updated_at": 1620734715
          },
          "meta": {
              "include": [],
              "custom": []
          }
      }
    }
  end

  def successful_partial_refund_response
    %{
          {
          "data": {
              "object": "Refund",
              "id": "Pqy8QxY8vb9YvB1O",
              "refund_amount": "500",
              "currency": "usd",
              "status": "partial_refund",
              "reason": "requested_by_customer",
              "description": "",
              "email": null,
              "receipt_number": null,
              "charge_id": "RbWLnOyBbyWBODBX",
              "created_at": 1620734893,
              "updated_at": 1620734893
          },
          "meta": {
              "include": [],
              "custom": []
          }
      }
    }
  end

  def failed_refund_response
    %{
        {
        "status": "error",
        "code": 0,
        "message": "Amount requested is not available for Refund  ",
        "status_code": 409,
        "exception": "Symfony\\Component\\HttpKernel\\Exception\\ConflictHttpException",
        "file": "/home/deploy/payarc.com/app/Containers/Refund/Tasks/CheckAmountTask.php",
        "line": 39    }
    }
  end
end
