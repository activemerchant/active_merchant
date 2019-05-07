require 'test_helper'

class BraspagTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BraspagGateway.new(merchant_id: 'merchant_id', merchant_key: 'merchant_key')

    @credit_card = credit_card('4551870000000181')

    @amount = 100

    @options = {
      order_id: '12345',
      customer: 'John Doe',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal '00e26ed5-d2be-4a6b-a803-cf935a3a05ed', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'Denied', response.message
    assert_equal '7', response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'dce00453-3c48-4ff1-9302-ee1895d0fa1e', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'Denied', response.message
    assert_equal '7', response.error_code
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'dce00453-3c48-4ff1-9302-ee1895d0fa1e', @options)

    assert_success response
    assert_equal 'dce00453-3c48-4ff1-9302-ee1895d0fa1e', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).raises(ActiveMerchant::ResponseError.new(stub(:code => '400', :body => failed_capture_response)))

    response = @gateway.capture(@amount, 'dce00453-3c48-4ff1-9302-ee1895d0fa1e', @options)

    assert_failure response
    assert_equal '308: Transaction not available to capture', response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'dce00453-3c48-4ff1-9302-ee1895d0fa1e', @options)

    assert_success response
    assert_equal 'dce00453-3c48-4ff1-9302-ee1895d0fa1e', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).raises(ActiveMerchant::ResponseError.new(stub(:code => '400', :body => failed_refund_response)))

    response = @gateway.refund(@amount, 'dce00453-3c48-4ff1-9302-ee1895d0fa1e', @options)

    assert_failure response
    assert_equal '309: Transaction not available to void', response.message
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void('dce00453-3c48-4ff1-9302-ee1895d0fa1e', @options)

    assert_success response
    assert_equal 'dce00453-3c48-4ff1-9302-ee1895d0fa1e', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).raises(ActiveMerchant::ResponseError.new(stub(:code => '400', :body => failed_void_response)))

    response = @gateway.void('dce00453-3c48-4ff1-9302-ee1895d0fa1e', @options)

    assert_failure response
    assert_equal '309: Transaction not available to void', response.message
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_request).at_most(2).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal 'b92f3271-58d5-4aac-a4ff-6b70629e47bf|decf5e93-fbb3-4124-9520-b00be4ec894d|Visa', response.authorization
    assert response.test?
  end

  def test_failed_store
    @gateway.expects(:ssl_request).at_most(2).returns(failed_store_response)

    response = @gateway.store(@credit_card, @options)

    assert_failure response
    assert_equal 'ProblemsWithCreditCard', response.message
    assert_equal '12', response.error_code
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).at_most(2).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)

    assert_success response
    assert_equal '0cb958ee-35eb-4fd6-8644-077ef55ff8a6', response.authorization
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).at_most(2).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)

    assert_failure response
    assert_equal 'Denied', response.message
    assert_equal '7', response.error_code
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_antifraud_data_sent
    stub_comms(@gateway, :ssl_request) do
      antifraud = {
        sequence: 'AnalyseFirst',
        sequenceCriteria: 'OnSuccess',
        provider: 'Cybersource',
        totalOrderAmount: 100,
        fingerPrintId: '074c1ee676ed4998ab66491013c565e2',
        browser: {
          cookiesAccepted: true,
          ipAddress: '127.0.0.1',
          type: "Chrome"
        },
        cart: {
          items: [
            {
              name: 'ItemTeste1',
              quantity: 1,
              sku: '20170511',
              unitPrice: 100,
              risk: 'High',
              velocityHedge: 'High'
            }
          ]
        },
        merchantDefinedFields: [
          {
            id: 4,
            value: 'Web'
          }
        ]
      }
      @gateway.authorize(@amount, @credit_card, @options.merge(antifraud: antifraud))
    end.check_request do |method, endpoint, data, headers|
      parsed = JSON.parse(data)
      assert_equal '074c1ee676ed4998ab66491013c565e2', parsed['payment']['fraudAnalysis']['fingerPrintId']
      assert_equal '127.0.0.1', parsed['payment']['fraudAnalysis']['browser']['ipAddress']
      assert_equal 'ItemTeste1', parsed['payment']['fraudAnalysis']['cart']['items'][0]['name']
      assert_equal 'Web', parsed['payment']['fraudAnalysis']['merchantDefinedFields'][0]['value']
    end.respond_with(successful_authorize_response)
  end

  def test_successful_authorize_with_tokenized_card
    response = stub_comms(@gateway, :ssl_request) do
      credit_card = 'b92f3271-58d5-4aac-a4ff-6b70629e47bf|decf5e93-fbb3-4124-9520-b00be4ec894d|Visa'
      @gateway.authorize(@amount, credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      parsed = JSON.parse(data)
      assert_equal 'decf5e93-fbb3-4124-9520-b00be4ec894d', parsed['payment']['creditCard']['cardToken']
      assert_equal 'Visa', parsed['payment']['creditCard']['brand']
    end.respond_with(successful_authorize_response)

    assert_success response
  end


  private

  def pre_scrubbed
    %q(
      opening connection to apisandbox.braspag.com.br:443...
      opened
      starting SSL for apisandbox.braspag.com.br:443...
      SSL established
      <- "POST //v2/sales/ HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nMerchantid: DAE838A3-24A6-464D-BF18-C50C5481E484\r\nMerchantkey: e1PH5TKgL4SZgyvYB4hm2L9nm7zu2J4Y2TuwtsWt\r\nRequestid: 0385738b-99a5-4338-a8c2-15903f0f9a8d\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: apisandbox.braspag.com.br\r\nContent-Length: 472\r\n\r\n"
      <- "{\"payment\":{\"provider\":\"Simulado\",\"amount\":\"1000\",\"installments\":1,\"currency\":\"BRL\",\"capture\":true,\"type\":\"CreditCard\",\"creditCard\":{\"cardNumber\":\"4539704859539511\",\"holder\":\"John Doe\",\"expirationDate\":\"09/2021\",\"securityCode\":\"737\",\"brand\":\"Visa\",\"saveCard\":false}},\"merchantOrderId\":\"ab792cb96546a56dc6aa3981a65912f8\",\"customer\":{\"name\":\"John Doe\",\"address\":{\"street\":\"456 My Street\",\"complement\":\"Apt 1\",\"zipCode\":\"K1C2N6\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\"}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Expires: -1\r\n"
      -> "Location: https://apisandbox.braspag.com.br/v2/sales/4f1f12e9-b7da-49a9-91c9-51b72d472efe\r\n"
      -> "Server: Microsoft-IIS/10.0\r\n"
      -> "RequestId: 0385738b-99a5-4338-a8c2-15903f0f9a8d\r\n"
      -> "X-Response-Time: 269ms\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "Request-Context: appId=cid-v1:92337ff1-a907-4b67-a0ae-ceaf6cd8cb63\r\n"
      -> "Access-Control-Expose-Headers: Request-Context\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "X-Powered-By: ARR/3.0\r\n"
      -> "Date: Sat, 01 Feb 2020 00:42:44 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Length: 1184\r\n"
      -> "\r\n"
      reading 1184 bytes...
      -> "{\"MerchantOrderId\":\"ab792cb96546a56dc6aa3981a65912f8\",\"Customer\":{\"Name\":\"John Doe\",\"Address\":{\"Street\":\"456 My Street\",\"Complement\":\"Apt 1\",\"ZipCode\":\"K1C2N6\",\"City\":\"Ottawa\",\"State\":\"ON\",\"Country\":\"CA\"}},\"Payment\":{\"ServiceTaxAmount\":0,\"Installments\":1,\"Interest\":\"ByMerchant\",\"Capture\":true,\"Authenticate\":false,\"Recurrent\":false,\"CreditCard\":{\"CardNumber\":\"453970******9511\",\"Holder\":\"John Doe\",\"ExpirationDate\":\"09/2021\",\"SaveCard\":false,\"Brand\":\"Visa\"},\"ProofOfSale\":\"20200131094245447\",\"AcquirerTransactionId\":\"0131094245447\",\"AuthorizationCode\":\"250358\",\"PaymentId\":\"4f1f12e9-b7da-49a9-91c9-51b72d472efe\",\"Type\":\"CreditCard\",\"Amount\":1000,\"ReceivedDate\":\"2020-01-31 21:42:45\",\"CapturedAmount\":1000,\"CapturedDate\":\"2020-01-31 21:42:45\",\"Currency\":\"BRL\",\"Country\":\"BRA\",\"Provider\":\"Simulado\",\"ReasonCode\":0,\"ReasonMessage\":\"Successful\",\"Status\":2,\"ProviderReturnCode\":\"6\",\"ProviderReturnMessage\":\"Operation Successful\",\"Links\":[{\"Method\":\"GET\",\"Rel\":\"self\",\"Href\":\"https://apiquerysandbox.braspag.com.br/v2/sales/4f1f12e9-b7da-49a9-91c9-51b72d472efe\"},{\"Method\":\"PUT\",\"Rel\":\"void\",\"Href\":\"https://apisandbox.braspag.com.br/v2/sales/4f1f12e9-b7da-49a9-91c9-51b72d472efe/void\"}]}}"
      read 1184 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to apisandbox.braspag.com.br:443...
      opened
      starting SSL for apisandbox.braspag.com.br:443...
      SSL established
      <- "POST //v2/sales/ HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nMerchantid: [FILTERED]\r\nMerchantkey: [FILTERED]\r\nRequestid: 0385738b-99a5-4338-a8c2-15903f0f9a8d\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: apisandbox.braspag.com.br\r\nContent-Length: 472\r\n\r\n"
      <- "{\"payment\":{\"provider\":\"Simulado\",\"amount\":\"1000\",\"installments\":1,\"currency\":\"BRL\",\"capture\":true,\"type\":\"CreditCard\",\"creditCard\":{\"cardNumber\":\"[FILTERED]\",\"holder\":\"John Doe\",\"expirationDate\":\"09/2021\",\"securityCode\":\"[FILTERED]\",\"brand\":\"Visa\",\"saveCard\":false}},\"merchantOrderId\":\"ab792cb96546a56dc6aa3981a65912f8\",\"customer\":{\"name\":\"John Doe\",\"address\":{\"street\":\"456 My Street\",\"complement\":\"Apt 1\",\"zipCode\":\"K1C2N6\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\"}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Expires: -1\r\n"
      -> "Location: https://apisandbox.braspag.com.br/v2/sales/4f1f12e9-b7da-49a9-91c9-51b72d472efe\r\n"
      -> "Server: Microsoft-IIS/10.0\r\n"
      -> "RequestId: 0385738b-99a5-4338-a8c2-15903f0f9a8d\r\n"
      -> "X-Response-Time: 269ms\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "Request-Context: appId=cid-v1:92337ff1-a907-4b67-a0ae-ceaf6cd8cb63\r\n"
      -> "Access-Control-Expose-Headers: Request-Context\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "X-Powered-By: ARR/3.0\r\n"
      -> "Date: Sat, 01 Feb 2020 00:42:44 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Length: 1184\r\n"
      -> "\r\n"
      reading 1184 bytes...
      -> "{\"MerchantOrderId\":\"ab792cb96546a56dc6aa3981a65912f8\",\"Customer\":{\"Name\":\"John Doe\",\"Address\":{\"Street\":\"456 My Street\",\"Complement\":\"Apt 1\",\"ZipCode\":\"K1C2N6\",\"City\":\"Ottawa\",\"State\":\"ON\",\"Country\":\"CA\"}},\"Payment\":{\"ServiceTaxAmount\":0,\"Installments\":1,\"Interest\":\"ByMerchant\",\"Capture\":true,\"Authenticate\":false,\"Recurrent\":false,\"CreditCard\":{\"CardNumber\":\"453970******9511\",\"Holder\":\"John Doe\",\"ExpirationDate\":\"09/2021\",\"SaveCard\":false,\"Brand\":\"Visa\"},\"ProofOfSale\":\"20200131094245447\",\"AcquirerTransactionId\":\"0131094245447\",\"AuthorizationCode\":\"250358\",\"PaymentId\":\"4f1f12e9-b7da-49a9-91c9-51b72d472efe\",\"Type\":\"CreditCard\",\"Amount\":1000,\"ReceivedDate\":\"2020-01-31 21:42:45\",\"CapturedAmount\":1000,\"CapturedDate\":\"2020-01-31 21:42:45\",\"Currency\":\"BRL\",\"Country\":\"BRA\",\"Provider\":\"Simulado\",\"ReasonCode\":0,\"ReasonMessage\":\"Successful\",\"Status\":2,\"ProviderReturnCode\":\"6\",\"ProviderReturnMessage\":\"Operation Successful\",\"Links\":[{\"Method\":\"GET\",\"Rel\":\"self\",\"Href\":\"https://apiquerysandbox.braspag.com.br/v2/sales/4f1f12e9-b7da-49a9-91c9-51b72d472efe\"},{\"Method\":\"PUT\",\"Rel\":\"void\",\"Href\":\"https://apisandbox.braspag.com.br/v2/sales/4f1f12e9-b7da-49a9-91c9-51b72d472efe/void\"}]}}"
      read 1184 bytes
      Conn close
    )
  end

  def successful_purchase_response
    %(
      {
        "MerchantOrderId": "b7e905c8-9e6f-41d0-9d78-e77660c7ed9f",
        "Customer": {
          "Name": "John Doe",
          "Address": {
            "Street": "456 My Street",
            "Number": "512",
            "Complement": "Apt 1",
            "ZipCode": "K1C2N6",
            "City": "Ottawa",
            "State": "ON",
            "Country": "CA"
          }
        },
        "Payment": {
          "ServiceTaxAmount": 0,
          "Installments": 1,
          "Interest": "ByMerchant",
          "Capture": true,
          "Authenticate": false,
          "Recurrent": false,
          "CreditCard": {
            "CardNumber": "455187******0181",
            "Holder": "John Doe",
            "ExpirationDate": "12/2021",
            "SaveCard": false,
            "Brand": "Visa"
          },
          "ProofOfSale": "20190507031405453",
          "AcquirerTransactionId": "0507031405453",
          "AuthorizationCode": "384910",
          "SoftDescriptor": "Store Purchase",
          "PaymentId": "00e26ed5-d2be-4a6b-a803-cf935a3a05ed",
          "Type": "CreditCard",
          "Amount": 100,
          "ReceivedDate": "2019-05-07 15:14:05",
          "CapturedAmount": 100,
          "CapturedDate": "2019-05-07 15:14:05",
          "Currency": "BRL",
          "Country": "BRA",
          "Provider": "Simulado",
          "ReasonCode": 0,
          "ReasonMessage": "Successful",
          "Status": 2,
          "ProviderReturnCode": "6",
          "ProviderReturnMessage": "Operation Successful",
          "Links": [
            {
              "Method": "GET",
              "Rel": "self",
              "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/00e26ed5-d2be-4a6b-a803-cf935a3a05ed"
            },
            {
              "Method": "PUT",
              "Rel": "void",
              "Href": "https://apisandbox.braspag.com.br/v2/sales/00e26ed5-d2be-4a6b-a803-cf935a3a05ed/void"
            }
          ]
        }
      }
    )
  end

  def failed_purchase_response
    %(
      {
        "MerchantOrderId": "55a5de20db993c815abe14970c2208d7",
        "Customer": {
          "Name": "John Doe",
          "Address": {
            "Street": "456 My Street",
            "Complement": "Apt 1",
            "ZipCode": "K1C2N6",
            "City": "Ottawa",
            "State": "ON",
            "Country": "CA"
          }
        },
        "Payment": {
          "ServiceTaxAmount": 0,
          "Installments": 1,
          "Interest": "ByMerchant",
          "Capture": true,
          "Authenticate": false,
          "Recurrent": false,
          "CreditCard": {
            "CardNumber": "400030******2222",
            "Holder": "John Doe",
            "ExpirationDate": "09/2021",
            "SaveCard": false,
            "Brand": "Visa"
          },
          "AcquirerTransactionId": "0202051226080",
          "SoftDescriptor": "Store Purchase",
          "PaymentId": "acc498f0-d898-44dc-af5d-cbd393233184",
          "Type": "CreditCard",
          "Amount": 100,
          "ReceivedDate": "2020-02-02 17:12:25",
          "Currency": "BRL",
          "Country": "BRA",
          "Provider": "Simulado",
          "ReasonCode": 7,
          "ReasonMessage": "Denied",
          "Status": 3,
          "ProviderReturnCode": "05",
          "ProviderReturnMessage": "Not Authorized",
          "Links": [
            {
              "Method": "GET",
              "Rel": "self",
              "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/acc498f0-d898-44dc-af5d-cbd393233184"
            }
          ]
        }
      }
    )
  end

  def successful_authorize_response
    %(
      {
        "MerchantOrderId": "aac0956c0ebe1bd09269c0736d6e68bc",
        "Customer": {
          "Name": "John Doe",
          "Address": {
            "Street": "456 My Street",
            "Complement": "Apt 1",
            "ZipCode": "K1C2N6",
            "City": "Ottawa",
            "State": "ON",
            "Country": "CA"
          }
        },
        "Payment": {
          "ServiceTaxAmount": 0,
          "Installments": 1,
          "Interest": "ByMerchant",
          "Capture": false,
          "Authenticate": false,
          "Recurrent": false,
          "CreditCard": {
            "CardNumber": "453970******9511",
            "Holder": "John Doe",
            "ExpirationDate": "09/2021",
            "SaveCard": false,
            "Brand": "Visa"
          },
          "ProofOfSale": "1945796",
          "AcquirerTransactionId": "0202051945796",
          "AuthorizationCode": "576792",
          "SoftDescriptor": "Store Purchase",
          "PaymentId": "dce00453-3c48-4ff1-9302-ee1895d0fa1e",
          "Type": "CreditCard",
          "Amount": 100,
          "ReceivedDate": "2020-02-02 17:19:45",
          "Currency": "BRL",
          "Country": "BRA",
          "Provider": "Simulado",
          "ReasonCode": 0,
          "ReasonMessage": "Successful",
          "Status": 1,
          "ProviderReturnCode": "4",
          "ProviderReturnMessage": "Operation Successful",
          "Links": [
            {
              "Method": "GET",
              "Rel": "self",
              "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/dce00453-3c48-4ff1-9302-ee1895d0fa1e"
            },
            {
              "Method": "PUT",
              "Rel": "capture",
              "Href": "https://apisandbox.braspag.com.br/v2/sales/dce00453-3c48-4ff1-9302-ee1895d0fa1e/capture"
            },
            {
              "Method": "PUT",
              "Rel": "void",
              "Href": "https://apisandbox.braspag.com.br/v2/sales/dce00453-3c48-4ff1-9302-ee1895d0fa1e/void"
            }
          ]
        }
      }
    )
  end

  def failed_authorize_response
    %(
      {
        "MerchantOrderId": "f5ba62a400b8fa8e17b609e019ef39fd",
        "Customer": {
          "Name": "John Doe",
          "Address": {
            "Street": "456 My Street",
            "Complement": "Apt 1",
            "ZipCode": "K1C2N6",
            "City": "Ottawa",
            "State": "ON",
            "Country": "CA"
          }
        },
        "Payment": {
          "ServiceTaxAmount": 0,
          "Installments": 1,
          "Interest": "ByMerchant",
          "Capture": false,
          "Authenticate": false,
          "Recurrent": false,
          "CreditCard": {
            "CardNumber": "400030******2222",
            "Holder": "Longbob Longsen",
            "ExpirationDate": "09/2021",
            "SaveCard": false,
            "Brand": "Visa"
          },
          "AcquirerTransactionId": "0202052306536",
          "SoftDescriptor": "Store Purchase",
          "PaymentId": "b9ceb84a-1cd0-4a1b-8148-a659480a08f7",
          "Type": "CreditCard",
          "Amount": 100,
          "ReceivedDate": "2020-02-02 17:23:06",
          "Currency": "BRL",
          "Country": "BRA",
          "Provider": "Simulado",
          "ReasonCode": 7,
          "ReasonMessage": "Denied",
          "Status": 3,
          "ProviderReturnCode": "05",
          "ProviderReturnMessage": "Not Authorized",
          "Links": [
            {
              "Method": "GET",
              "Rel": "self",
              "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/b9ceb84a-1cd0-4a1b-8148-a659480a08f7"
            }
          ]
        }
      }
    )
  end

  def successful_capture_response
    %(
      {
        "Status":2,
        "ReasonCode":0,
        "ReasonMessage":"Successful",
        "ProviderReturnCode":"6",
        "ProviderReturnMessage":"Operation Successful",
        "Links":[
          {
            "Method":"GET",
            "Rel":"self",
            "Href":"https://apiquerysandbox.braspag.com.br/v2/sales/03670768-9a80-4316-84e0-e6aeaa36552a"
          },
          {
            "Method":"PUT",
            "Rel":"void",
            "Href":"https://apisandbox.braspag.com.br/v2/sales/03670768-9a80-4316-84e0-e6aeaa36552a/void"
          }
        ]
      }
    )
  end

  def failed_capture_response
    %(
      [
        {
          "Code": 308,
          "Message": "Transaction not available to capture"
        }
      ]
    )
  end

  def successful_refund_response
    %(
      {
        "Status": 11,
        "ReasonCode": 0,
        "ReasonMessage": "Successful",
        "ProviderReturnCode": "0",
        "ProviderReturnMessage": "Operation Successful",
        "Links": [
          {
            "Method": "GET",
            "Rel": "self",
            "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/32bc5585-f84a-4d5d-b0b6-93f52cca1c94"
          }
        ]
      }
    )
  end

  def failed_refund_response
    %(
      [
        {
          "Code": 309,"Message":
          "Transaction not available to void"
        }
      ]
    )
  end

  def successful_void_response
    %(
      {
        "Status": 10,
        "ReasonCode": 0,
        "ReasonMessage": "Successful",
        "ProviderReturnCode": "0",
        "ProviderReturnMessage": "Operation Successful",
        "Links": [
          {
            "Method": "GET",
            "Rel": "self",
            "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/007bdb7f-cf7a-44ca-ae7b-c834ae8a51ce"
          }
        ]
      }
    )
  end

  def failed_void_response
    %(
      [
        {
          "Code": 309,
          "Message": "Transaction not available to void"
        }
      ]
    )
  end

  def successful_store_response
    %(
      {
        "MerchantOrderId": "store-d85510d7bf4854d5cf728bbae13df590",
        "Customer": {
          "Name": "John Doe"
        },
        "Payment": {
          "ServiceTaxAmount": 0,
          "Installments": 1,
          "Interest": "ByMerchant",
          "Capture": false,
          "Authenticate": false,
          "Recurrent": false,
          "CreditCard": {
            "CardNumber": "453970******9511",
            "Holder": "John Doe",
            "ExpirationDate": "09/2021",
            "SaveCard": true,
            "CardToken": "decf5e93-fbb3-4124-9520-b00be4ec894d",
            "Brand": "Visa"
          },
          "ProofOfSale": "057709",
          "AcquirerTransactionId": "0202070057709",
          "AuthorizationCode": "125790",
          "SoftDescriptor": "Store Purchase",
          "PaymentId": "b92f3271-58d5-4aac-a4ff-6b70629e47bf",
          "Type": "CreditCard",
          "Amount": 0,
          "ReceivedDate": "2020-02-02 19:00:57",
          "Currency": "BRL",
          "Country": "BRA",
          "Provider": "Simulado",
          "ReasonCode": 0,
          "ReasonMessage": "Successful",
          "Status": 1,
          "ProviderReturnCode": "4",
          "ProviderReturnMessage": "Operation Successful",
          "Links": [
            {
              "Method": "GET",
              "Rel": "self",
              "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/b92f3271-58d5-4aac-a4ff-6b70629e47bf"
            },
            {
              "Method": "PUT",
              "Rel": "capture",
              "Href": "https://apisandbox.braspag.com.br/v2/sales/b92f3271-58d5-4aac-a4ff-6b70629e47bf/capture"
            },
            {
              "Method": "PUT",
              "Rel": "void",
              "Href": "https://apisandbox.braspag.com.br/v2/sales/b92f3271-58d5-4aac-a4ff-6b70629e47bf/void"
            }
          ]
        }
      }
    )
  end

  def failed_store_response
    %(
      {
        "MerchantOrderId": "store-ceada4a7b6bcef02d1bf75b85ef85286",
        "Customer": {
          "Name": "John Doe"
        },
        "Payment": {
          "ServiceTaxAmount": 0,
          "Installments": 1,
          "Interest": "ByMerchant",
          "Capture": false,
          "Authenticate": false,
          "Recurrent": false,
          "CreditCard": {
            "CardNumber": "533231******2798",
            "Holder": "John Doe",
            "ExpirationDate": "09/2021",
            "SaveCard": true,
            "CardToken": "7d00da54-fa61-42f5-8844-eab0c8aee2ae",
            "Brand": "Visa"
          },
          "AcquirerTransactionId": "0202071206177",
          "SoftDescriptor": "Store Purchase",
          "PaymentId": "d0cf61da-f58e-4c64-9a7b-416ec47cd78a",
          "Type": "CreditCard",
          "Amount": 0,
          "ReceivedDate": "2020-02-02 19:12:05",
          "Currency": "BRL",
          "Country": "BRA",
          "Provider": "Simulado",
          "ReasonCode": 12,
          "ReasonMessage": "ProblemsWithCreditCard",
          "Status": 3,
          "ProviderReturnCode": "70",
          "ProviderReturnMessage": "Problems with Creditcard",
          "Links": [
            {
              "Method": "GET",
              "Rel": "self",
              "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/d0cf61da-f58e-4c64-9a7b-416ec47cd78a"
            }
          ]
        }
      }
    )
  end

  def successful_verify_response
    %(
      {
        "MerchantOrderId": "f5f607a8f38869c4f097499b17ad8d00",
        "Customer": {
          "Name": "John Doe",
          "Address": {
            "Street": "456 My Street",
            "Complement": "Apt 1",
            "ZipCode": "K1C2N6",
            "City": "Ottawa",
            "State": "ON",
            "Country": "CA"
          }
        },
        "Payment": {
          "ServiceTaxAmount": 0,
          "Installments": 1,
          "Interest": "ByMerchant",
          "Capture": false,
          "Authenticate": false,
          "Recurrent": false,
          "CreditCard": {
            "CardNumber": "453970******9511",
            "Holder": "John Doe",
            "ExpirationDate": "09/2021",
            "SaveCard": false,
            "Brand": "Visa"
          },
          "ProofOfSale": "4219808",
          "AcquirerTransactionId": "0203094219808",
          "AuthorizationCode": "845896",
          "SoftDescriptor": "Store Purchase",
          "PaymentId": "0cb958ee-35eb-4fd6-8644-077ef55ff8a6",
          "Type": "CreditCard",
          "Amount": 100,
          "ReceivedDate": "2020-02-03 09:42:12",
          "Currency": "BRL",
          "Country": "BRA",
          "Provider": "Simulado",
          "ReasonCode": 0,
          "ReasonMessage": "Successful",
          "Status": 1,
          "ProviderReturnCode": "4",
          "ProviderReturnMessage": "Operation Successful",
          "Links": [
            {
              "Method": "GET",
              "Rel": "self",
              "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/0cb958ee-35eb-4fd6-8644-077ef55ff8a6"
            },
            {
              "Method": "PUT",
              "Rel": "capture",
              "Href": "https://apisandbox.braspag.com.br/v2/sales/0cb958ee-35eb-4fd6-8644-077ef55ff8a6/capture"
            },
            {
              "Method": "PUT",
              "Rel": "void",
              "Href": "https://apisandbox.braspag.com.br/v2/sales/0cb958ee-35eb-4fd6-8644-077ef55ff8a6/void"
            }
          ]
        }
      }
    )
  end

  def failed_verify_response
    %(
      {
        "MerchantOrderId": "994d6b699ea85b6d92cb3330c8cef3e4",
        "Customer": {
          "Name": "John Doe",
          "Address": {
            "Street": "456 My Street",
            "Complement": "Apt 1",
            "ZipCode": "K1C2N6",
            "City": "Ottawa",
            "State": "ON",
            "Country": "CA"
          }
        },
        "Payment": {
          "ServiceTaxAmount": 0,
          "Installments": 1,
          "Interest": "ByMerchant",
          "Capture": false,
          "Authenticate": false,
          "Recurrent": false,
          "CreditCard": {
            "CardNumber": "400030******2222",
            "Holder": "Longbob Longsen",
            "ExpirationDate": "09/2021",
            "SaveCard": false,
            "Brand": "Visa"
          },
          "AcquirerTransactionId": "0203094544426",
          "SoftDescriptor": "Store Purchase",
          "PaymentId": "e62afe1a-2ccb-4dd0-ae5a-e91c447acc44",
          "Type": "CreditCard",
          "Amount": 100,
          "ReceivedDate": "2020-02-03 09:45:40",
          "Currency": "BRL",
          "Country": "BRA",
          "Provider": "Simulado",
          "ReasonCode": 7,
          "ReasonMessage": "Denied",
          "Status": 3,
          "ProviderReturnCode": "05",
          "ProviderReturnMessage": "Not Authorized",
          "Links": [
            {
              "Method": "GET",
              "Rel": "self",
              "Href": "https://apiquerysandbox.braspag.com.br/v2/sales/e62afe1a-2ccb-4dd0-ae5a-e91c447acc44"
            }
          ]
        }
      }
    )
  end
end
