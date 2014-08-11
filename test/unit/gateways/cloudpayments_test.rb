# encoding: utf-8
require 'test_helper'

class CloudpaymentsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CloudpaymentsGateway.new(public_id: '123', api_secret: "123")

    @token = "a4e67841-abb0-42de-a364-d1d8f9f4b3c0"
    @cryptogram = "01492500008719030128SMfLeYdKp5dSQVIiO5l6ZCJiPdel4uDjdFTTz1UnXY+3QaZcNOW8lmXg0H670MclS4lI+qLkujKF4pR5Ri+T/E04Ufq3t5ntMUVLuZ998DLm+OVHV7FxIGR7snckpg47A73v7/y88Q5dxxvVZtDVi0qCcJAiZrgKLyLCqypnMfhjsgCEPF6d4OMzkgNQiynZvKysI2q+xc9cL0+CMmQTUPytnxX52k9qLNZ55cnE8kuLvqSK+TOG7Fz03moGcVvbb9XTg1oTDL4pl9rgkG3XvvTJOwol3JDxL1i6x+VpaRxpLJg0Zd9/9xRJOBMGmwAxo8/xyvGuAj85sxLJL6fA=="
    @amount = 400
    @refund_amount = 200

    @token_options = {
       :Currency => "RUB",
       :InvoiceId => "1234567",
       :Description => "Payment on example.com",
       :AccountId => "user_x"
    }
    @cryptogram_options = @token_options.merge(:Name => "ALEXANDER")

    @subscriptions_options = {
      :token=>"477BBA133C182267FE5F086924ABDC5DB71F77BFC27F01F2843F2CDC69D89F05",
      :accountId=>"user@example.com",
      :description=>"example.com",
      :email=>"user@example.com",
      :amount=>1.02,
      :currency=>"RUB",
      :requireConfirmation=>false,
      :startDate=>"2014-08-06T16:46:29.5377246Z",
      :interval=>"Month",
      :period=>1
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_pay_response)

    assert response = @gateway.authorize_with_token(@token, @amount, @token_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 504, response.authorization
    assert response.test?
  end

  def test_amount_authorization
    @gateway.expects(:ssl_post).returns(successful_pay_response)

    assert response = @gateway.authorize_with_token(@token, @amount, @token_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal @amount.to_i, response.params['Amount'].to_i
    assert_equal 'Completed', response.params['Status']
    assert response.test?
  end

  def test_successful_charge
    @gateway.expects(:ssl_post).returns(successful_pay_response)

    assert response = @gateway.charge_with_token(@token, @amount, @token_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 504, response.authorization
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(common_successful_response)

    assert response = @gateway.void(504)
    assert_instance_of Response, response
    assert_success response

    assert_equal true, response.success?
    assert_equal 'Transaction approved', response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(common_successful_response)

    assert response = @gateway.refund(100, 504392048)
    assert_instance_of Response, response
    assert_success response

    assert_equal true, response.success?
    assert_equal 'Transaction approved', response.message
    assert response.test?
  end

  def test_successful_confirm
    @gateway.expects(:ssl_post).returns(common_successful_response)

    assert response = @gateway.confirm(100, 504392048)
    assert_instance_of Response, response
    assert_success response

    assert_equal true, response.success?
    assert_equal 'Transaction approved', response.message
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_pay_response)

    assert response = @gateway.charge_with_token(@token, @amount, @token_options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal 'Declined', response.params['Status']
    assert response.test?
  end

  def test_successful_subscription
    @gateway.expects(:ssl_post).returns(successful_subscription_response)

    assert response = @gateway.subscribe(@token, @amount, @subscriptions_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'user@example.com', response.params['AccountId']
    assert_equal 'Month', response.params['Interval']
    assert_equal 1, response.params['Period']
    assert response.test?
  end

  def test_successful_get_subscription
    @gateway.expects(:ssl_post).returns(successful_get_subscription_response)

    assert response = @gateway.get_subscription('sc_8cf8a9338fb8ebf7202b08d09c938')
    assert_instance_of Response, response
    assert_success response

    assert_equal 'sc_8cf8a9338fb8ebf7202b08d09c938', response.authorization
    assert_equal '1@1.com', response.params['AccountId']
    assert_equal 'Month', response.params['Interval']
    assert_equal 'Active', response.params['Status']
    assert_equal 1, response.params['Period']
    assert response.test?
  end

  def test_void_subscription
    @gateway.expects(:ssl_post).returns(common_successful_response)

    assert response = @gateway.void_subscription('sc_8cf8a9338fb8ebf7202b08d09c938')
    assert_instance_of Response, response
    assert_success response

    assert_equal true, response.success?
    assert_equal 'Transaction approved', response.message
    assert response.test?
  end

  private

  def successful_pay_response
    <<-RESPONSE
    {
      "Model": {
        "TransactionId": 504,
        "Amount": 400,
        "Currency": "RUB",
        "CurrencyCode": 0,
        "PaymentAmount": 10.00000,
        "PaymentCurrency": "RUB",
        "PaymentCurrencyCode": 0,
        "InvoiceId": "1234567",
        "AccountId": "user_x",
        "Email": null,
        "Description": "Payment on example.com",
        "JsonData": null,
        "CreatedDate": "#{Date.today}",
        "AuthDate": "#{Date.today}",
        "ConfirmDate": "#{Date.today}",
        "AuthCode": "123456",
        "TestMode": true,
        "IpAddress": "195.91.194.13",
        "IpCountry": "RU",
        "IpCity": "Orenburg",
        "IpRegion": "Orenburg region",
        "IpDistrict": "PFO",
        "IpLatitude": 54.7355,
        "IpLongitude": 55.991982,
        "CardFirstSix": "411111",
        "CardLastFour": "1111",
        "CardType": "Visa",
        "CardTypeCode": 0,
        "IssuerBankCountry": "RU",
        "Status": "Completed",
        "StatusCode": 3,
        "Reason": "Approved",
        "ReasonCode": 0,
        "Name": "CARDHOLDER NAME",
        "Token": "a4e67841-abb0-42de-a364-d1d8f9f4b3c0"
      },
      "Success": true,
      "Message": null
    }
    RESPONSE
  end

  def common_successful_response
    <<-RESPONSE
    {
      "Success":true,
      "Message":null
    }
    RESPONSE
  end

  def unsuccessful_pay_response
    <<-RESPONSE
    {
      "Model": {
        "TransactionId": 504,
        "Amount": 10.00000,
        "Currency": "RUB",
        "CurrencyCode": 0,
        "PaymentAmount": 10.00000,
        "PaymentCurrency": "RUB",
        "PaymentCurrencyCode": 0,
        "InvoiceId": "1234567",
        "AccountId": "user_x",
        "Email": null,
        "Description": "Payment on example.com",
        "JsonData": null,
        "CreatedDate": "#{Date.today}",
        "TestMode": true,
        "IpAddress": "195.91.194.13",
        "IpCountry": "RU",
        "IpCity": "Orenburg",
        "IpRegion": "Orenburg region",
        "IpDistrict": "PFO",
        "IpLatitude": 54.7355,
        "IpLongitude": 55.991982,
        "CardFirstSix": "411111",
        "CardLastFour": "1111",
        "CardType": "Visa",
        "CardTypeCode": 0,
        "IssuerBankCountry": "RU",
        "Status": "Declined",
        "StatusCode": 5,
        "Reason": "InsufficientFunds",
        "ReasonCode": 5051,
        "Name": "CARDHOLDER NAME"
      },
      "Success": false,
      "Message": null
    }
    RESPONSE
  end

  def successful_subscription_response
    <<-RESPONSE
    {
       "Model":{
          "Id": "sc_8cf8a9338fb8ebf7202b08d09c938",
          "AccountId": "user@example.com",
          "Description": "Subscription example.com",
          "Email": "user@example.com",
          "Amount": 1.02,
          "CurrencyCode": 0,
          "Currency": "RUB",
          "Auth": false,
          "StartDate": "#{Date.today}",
          "IntervalCode": 1,
          "Interval": "Month",
          "Period": 1,
          "MaxPeriods": null,
          "StatusCode": 0,
          "Status": "Active",
          "SuccessfulTransactionsNumber": 0,
          "FailedTransactionsNumber": 0,
          "LastTransactionDate": null,
          "NextTransactionDate": "#{Date.today}"
       },
       "Success":true
    }
    RESPONSE
  end

  def successful_get_subscription_response
    <<-RESPONSE
    {
      "Model":{
        "Id":"sc_8cf8a9338fb8ebf7202b08d09c938", //идентификатор подписки
        "AccountId":"1@1.com",
        "Description":"Subscription example.com",
        "Email":"1@1.com",
        "Amount":1.02,
        "CurrencyCode":0,
        "Currency":"RUB",
        "RequireConfirmation":false, //true для двустидайных платежей
        "StartDate":"\/Date(1407343589537)\/",
        "StartDateIso":"2014-08-09T11:49:41", //все даты в UTC
        "IntervalCode":1,
        "Interval":"Month",
        "Period":1,
        "MaxPeriods":null,
        "StatusCode":0,
        "Status":"Active",
        "SuccessfulTransactionsNumber":0,
        "FailedTransactionsNumber":0,
        "LastTransactionDate":null,
        "LastTransactionDateIso":null,
        "NextTransactionDate":"\/Date(1407343589537)\/",
        "NextTransactionDateIso":"2014-08-09T11:49:41"
      },
      "Success":true
    }
    RESPONSE
  end

end
