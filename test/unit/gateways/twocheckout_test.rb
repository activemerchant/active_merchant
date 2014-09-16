require 'test_helper'

class TwocheckoutTest < Test::Unit::TestCase
  def setup
    @gateway = TwocheckoutGateway.new(fixtures(:twocheckout))
    @token = @gateway.options[:token]
    @amount = 100
    @options = {
      email:  'example@2co.com',
      billing_address: address,
      shipping_address: address,
      description: 'twocheckout active merchant unit test',
      order_id: '123',
      currency: 'USD'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    @amount = 100
    assert response = @gateway.purchase(@amount, @token, @options)
    assert_instance_of Response, response
    assert_not_nil response.params['response']['transactionId']
    assert_not_nil response.params['response']['merchantOrderId']
    assert_equal response.authorization, response.params['response']['orderNumber']
    assert_equal @options[:currency], response.params['response']['currencyCode']
    assert_equal '%.2f' % (@amount / 100), response.params['response']['total']
    assert_success response
    assert_equal '9093718683828', response.authorization
  end

  def test_successful_purchase_with_items
    @gateway.expects(:ssl_request).returns(successful_purchase_response_with_items)
    items = [
      {
        name: 'Example Lineitem',
        price: 250,
        quantity: 2,
        options: [
          {
            name: 'color',
            value: 'red',
            price: 100
          },
          {
            name: 'size',
            value: 'XL',
            price: 300
          }
        ]
      },
      {
        name: 'Example Lineitem',
        price: 200,
        quantity: 1,
        recurrence: '1 Month',
        duration: 'Forever'
      }
    ]
    @options[:items] = items
    @amount = 1598
    assert response = @gateway.purchase(@amount, @token, @options)
    assert_instance_of Response, response
    assert_not_nil response.params['response']['transactionId']
    assert_not_nil response.params['response']['merchantOrderId']
    assert_equal response.authorization, response.params['response']['orderNumber']
    assert_equal @options[:currency], response.params['response']['currencyCode']
    assert_equal '%.2f' % (@amount / 100), response.params['response']['total']
    assert_success response
    assert_equal '9093718683882', response.authorization
  end

  def test_failed_validation
    @gateway.expects(:ssl_request).returns(failed_validation_purchase_response)
    @options[:order_id] = nil
    assert response = @gateway.purchase(@amount, @token, @options)
    assert_failure response
    assert_equal 'Bad request - parameter error', response.message
  end

  def test_failed_authorization
    @gateway.expects(:ssl_request).returns(failed_authorization_purchase_response)
    assert response = @gateway.purchase(@amount, @token, @options)
    assert_failure response
    assert_equal 'Payment Authorization Failed: Please use a different credit card or payment method and try again, or contact your bank for more information.', response.message
  end

  def successful_purchase_response
    <<-RESPONSE
    {
        "validationErrors": null,
        "exception": null,
        "response": {
            "type": "AuthResponse",
            "responseMsg": "Successfully authorized the provided credit card",
            "recurrentInstallmentId": null,
            "lineItems": [
                {
                    "options": [],
                    "price": "1.00",
                    "quantity": "1",
                    "recurrence": null,
                    "startupFee": null,
                    "productId": "",
                    "tangible": "N",
                    "name": "123",
                    "type": "product",
                    "description": "",
                    "duration": null
                }
            ],
            "transactionId": "9093718683849",
            "billingAddr": {
                "addrLine1": "1234 My Street",
                "addrLine2": "Apt 1",
                "city": "Ottawa",
                "zipCode": "K1C2N6",
                "phoneNumber": "(555)555-5555",
                "phoneExtension": null,
                "email": "example@2co.com",
                "name": "Jim Smith",
                "state": "ON",
                "country": "CA"
            },
            "shippingAddr": {
                "addrLine1": "1234 My Street",
                "addrLine2": "Apt 1",
                "city": "Ottawa",
                "zipCode": "K1C2N6",
                "phoneNumber": "(555)555-5555",
                "phoneExtension": null,
                "email": "example@2co.com",
                "name": "Jim Smith",
                "state": "ON",
                "country": "CA"
            },
            "merchantOrderId": "123",
            "orderNumber": "9093718683828",
            "responseCode": "APPROVED",
            "total": "1.00",
            "currencyCode": "USD",
            "errors": null
        }
    }
    RESPONSE
  end

  def successful_purchase_response_with_items
    <<-RESPONSE
    {
        "validationErrors": null,
        "exception": null,
        "response": {
            "type": "AuthResponse",
            "responseMsg": "Successfully authorized the provided credit card",
            "recurrentInstallmentId": null,
            "lineItems": [
                {
                    "options": [
                        {
                            "optName": "color",
                            "optValue": "red",
                            "optSurcharge": "1.00"
                        },
                        {
                            "optName": "size",
                            "optValue": "XL",
                            "optSurcharge": "3.00"
                        }
                    ],
                    "price": "2.50",
                    "quantity": "2",
                    "recurrence": null,
                    "startupFee": null,
                    "productId": "",
                    "tangible": "N",
                    "name": "Example Lineitem",
                    "type": "product",
                    "description": "",
                    "duration": null
                },
                {
                    "options": [],
                    "price": "2.00",
                    "quantity": "1",
                    "recurrence": "1 Month",
                    "startupFee": null,
                    "productId": "",
                    "tangible": "N",
                    "name": "Example Lineitem",
                    "type": "product",
                    "description": "",
                    "duration": "Forever"
                }
            ],
            "transactionId": "9093718683903",
            "billingAddr": {
                "addrLine1": "1234 My Street",
                "addrLine2": "Apt 1",
                "city": "Ottawa",
                "zipCode": "K1C2N6",
                "phoneNumber": "(555)555-5555",
                "phoneExtension": null,
                "email": "example@2co.com",
                "name": "Jim Smith",
                "state": "ON",
                "country": "CA"
            },
            "shippingAddr": {
                "addrLine1": "1234 My Street",
                "addrLine2": "Apt 1",
                "city": "Ottawa",
                "zipCode": "K1C2N6",
                "phoneNumber": "(555)555-5555",
                "phoneExtension": null,
                "email": "example@2co.com",
                "name": "Jim Smith",
                "state": "ON",
                "country": "CA"
            },
            "merchantOrderId": "123",
            "orderNumber": "9093718683882",
            "responseCode": "APPROVED",
            "total": "15.00",
            "currencyCode": "USD",
            "errors": null
        }
    }
    RESPONSE
  end

  def failed_validation_purchase_response
    <<-RESPONSE
    {
      "validationErrors": null,
      "exception": {
        "errorMsg": "Bad request - parameter error",
        "httpStatus": "500",
        "exception": false,
        "errorCode": "400"
      },
      "response": null
    }
    RESPONSE
  end

  def failed_authorization_purchase_response
    <<-RESPONSE
    {
        "validationErrors": null,
        "exception": {
            "errorMsg": "Payment Authorization Failed: Please use a different credit card or payment method and try again, or contact your bank for more information.",
            "httpStatus": "400",
            "exception": false,
            "errorCode": "606"
        },
        "response": null
    }
    RESPONSE
  end
end
