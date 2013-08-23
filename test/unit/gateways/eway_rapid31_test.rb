require 'test_helper'

class EwayRapid31Test < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = EwayRapid31Gateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card('4444333322221111')
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :email => 'jim.smith@example.com',
      :ip => '127.0.0.1',
      :transaction_type => 'MOTO'
    }
  end

  def test_successful_purchase
    stub_comms(:ssl_request) do
      assert @response = @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_purchase_request(100)) == JSON.parse(data)
    end.respond_with(successful_purchase_response)

    assert_equal '326898', @response.authorization
    assert_success @response
    assert @response.test?
  end

  def test_unsuccessful_purchase
    stub_comms(:ssl_request) do
      assert @response = @gateway.purchase(@amount + 1, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_purchase_request(101)) == JSON.parse(data)
    end.respond_with(failed_purchase_response)

    assert_equal '', @response.authorization
    assert_failure @response
    assert @response.test?
  end

  def test_successful_store
    stub_comms(:ssl_request) do
      assert @response = @gateway.store(@credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_store_request(:month => @credit_card.month)) == JSON.parse(data)
    end.respond_with(successful_store_response)

    assert_equal 915022769090, @response.authorization
    assert_success @response
    assert_nil @response.avs_result['code']
    assert @response.test?
  end

  def test_unsuccessful_store
    bad_credit_card = credit_card('4444333322221111', :month => 13)

    stub_comms(:ssl_request) do
      assert @response = @gateway.store(bad_credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_store_request(:month => bad_credit_card.month)) == JSON.parse(data)
    end.respond_with(failed_store_response)

    assert_nil @response.authorization
    assert_nil @response.avs_result['code']
    assert_failure @response
    assert @response.test?
  end


  def test_successful_purchase_with_token
    stub_comms(:ssl_request) do
      assert @response = @gateway.purchase(@amount, 918260741894, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_purchase_with_token_request(918260741894)) == JSON.parse(data)
    end.respond_with(successful_purchase_with_token_response)

    assert_equal '511006', @response.authorization
    assert_equal 918260741894, @response.params['Customer']['TokenCustomerID']
    assert_success @response
    assert @response.test?
  end

  def test_unsuccessful_purchase_with_token
    stub_comms(:ssl_request) do
      assert @response = @gateway.purchase(@amount, 0, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_purchase_with_token_request(0)) == JSON.parse(data)
    end.respond_with(failed_purchase_with_token_response)

    assert 'V6040,V6021,V6022,V6101,V6102', @response.message
    assert_failure @response
    assert @response.test?
  end

  def test_successful_refund
    stub_comms(:ssl_request) do
      assert @response = @gateway.refund(@amount, '10326714', @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_refund_request(10326714)) == JSON.parse(data)
    end.respond_with(successful_refund_response)

    assert_equal "607276", @response.authorization
    assert_success @response
    assert @response.test?
  end

  def test_unsuccessful_refund
    stub_comms(:ssl_request) do
      assert @response = @gateway.refund(@amount, 0, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_refund_request(0)) == JSON.parse(data)
    end.respond_with(failed_refund_response)

    assert '', @response.authorization
    assert 'S5010', @response.params['Errors']
    assert_failure @response
    assert @response.test?
  end

  def test_successful_update
    stub_comms(:ssl_request) do
      assert @response = @gateway.update(915845997420, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_update_request(915845997420)) == JSON.parse(data)
    end.respond_with(successful_refund_response)

    assert_success @response
    assert @response.test?
  end

  def test_unsuccessful_update
    stub_comms(:ssl_request) do
      assert @response = @gateway.update(0, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert JSON.parse(expected_update_request(0)) == JSON.parse(data)
    end.respond_with(failed_update_response)

    assert_equal 'Invalid TokenCustomerID', @response.message
    assert_failure @response
    assert @response.test?
  end

  private

  def successful_purchase_response
    <<-JSON
      {
          "AuthorisationCode":"326898",
          "ResponseCode":"00",
          "ResponseMessage":"A2000",
          "TransactionID":10324296,
          "TransactionStatus":true,
          "TransactionType":"MOTO",
          "BeagleScore":0,
          "Verification":{
              "CVN":0,
              "Address":0,
              "Email":0,
              "Mobile":0,
              "Phone":0
          },
          "Customer":{
              "CardDetails":{
                  "Number":"444433XXXXXX1111",
                  "Name":"Longbob Longsen",
                  "ExpiryMonth":"09",
                  "ExpiryYear":"14",
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":null,
              "Reference":"",
              "Title":"Mr.",
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":"",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Comments":"",
              "Fax":"(555)555-6666",
              "Url":""
          },
          "Payment":{
              "TotalAmount":100,
              "InvoiceNumber":"",
              "InvoiceDescription":"Store Purchase",
              "InvoiceReference":"1",
              "CurrencyCode":"AUD"
          },
          "Errors":null
      }
    JSON
  end

  def failed_purchase_response
    <<-JSON
      {
          "AuthorisationCode":"",
          "ResponseCode":"01",
          "ResponseMessage":"D4401",
          "TransactionID":10324297,
          "TransactionStatus":false,
          "TransactionType":"MOTO",
          "BeagleScore":0,
          "Verification":{
              "CVN":0,
              "Address":0,
              "Email":0,
              "Mobile":0,
              "Phone":0
          },
          "Customer":{
              "CardDetails":{
                  "Number":"444433XXXXXX1111",
                  "Name":"Longbob Longsen",
                  "ExpiryMonth":"09",
                  "ExpiryYear":"14",
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":null,
              "Reference":"",
              "Title":"Mr.",
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":"",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Comments":"",
              "Fax":"(555)555-6666",
              "Url":""
          },
          "Payment":{
              "TotalAmount":101,
              "InvoiceNumber":"",
              "InvoiceDescription":"Store Purchase",
              "InvoiceReference":"1",
              "CurrencyCode":"AUD"
          },
          "Errors":null
      }
    JSON
  end

  def expected_purchase_request(amount)
    request = <<-JSON
      {
          "Payment":{
              "InvoiceReference":"1",
              "InvoiceDescription":"Store Purchase",
              "TotalAmount":#{amount},
              "CurrencyCode":"AUD"
          },
          "Customer":{
              "CardDetails":{
                  "Name":"Longbob Longsen",
                  "Number":"4444333322221111",
                  "ExpiryMonth":"09",
                  "ExpiryYear":"14",
                  "CVN":"123"
              },
              "FirstName":"Jim",
              "LastName":"Smith",
              "Title":"",
              "CompanyName":"Widgets Inc",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Fax":"(555)555-6666",
              "Email":"jim.smith@example.com"
          },
          "CustomerIP":"127.0.0.1",
          "DeviceID":"ActiveMerchant",
          "TransactionType":"MOTO"
      }
    JSON

    request
  end

  def expected_store_request(options = {})
    request = <<-JSON
      {
          "Customer":{
              "CardDetails":{
                  "Name":"Longbob Longsen",
                  "Number":"4444333322221111",
                  "ExpiryMonth":"#{sprintf('%02d', options[:month])}",
                  "ExpiryYear":"14",
                  "CVN":"123"
              },
              "FirstName":"Jim",
              "LastName":"Smith",
              "Title":"",
              "CompanyName":"Widgets Inc",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Fax":"(555)555-6666",
              "Email":"jim.smith@example.com"
          }
      }
    JSON

    request
  end

  def successful_store_response
    <<-JSON
      {
          "Customer":{
              "CardDetails":{
                  "Number":"444433XXXXXX1111",
                  "Name":"Longbob Longsen",
                  "ExpiryMonth":"09",
                  "ExpiryYear":"14",
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":915022769090,
              "Reference":"",
              "Title":"Mr.",
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":"",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Comments":"",
              "Fax":"(555)555-6666",
              "Url":""
          },
          "Errors":null
      }
    JSON
  end

  def failed_store_response
    <<-JSON
      {
          "Customer":{
              "CardDetails":{
                  "Number":"444433XXXXXX1111",
                  "Name":"Longbob Longsen",
                  "ExpiryMonth":"13",
                  "ExpiryYear":"14",
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":null,
              "Reference":null,
              "Title":null,
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":null,
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":null,
              "Comments":null,
              "Fax":"(555)555-6666",
              "Url":null
          },
          "Errors":"V6101"
      }
    JSON
  end

  def successful_refund_response
    <<-JSON
      {
          "AuthorisationCode":"607276",
          "ResponseCode":null,
          "ResponseMessage":"A2000",
          "TransactionID":10326715,
          "TransactionStatus":true,
          "Verification":null,
          "Customer":{
              "CardDetails":{
                  "Number":null,
                  "Name":null,
                  "ExpiryMonth":null,
                  "ExpiryYear":null,
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":null,
              "Reference":null,
              "Title":null,
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":null,
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":null,
              "Comments":null,
              "Fax":"(555)555-6666",
              "Url":null
          },
          "Refund":{
              "TransactionID":null,
              "TotalAmount":100,
              "InvoiceNumber":null,
              "InvoiceDescription":null,
              "InvoiceReference":null,
              "CurrencyCode":null
          },
          "Errors":""
      }
    JSON
  end

  def expected_refund_request(trans_id)
    request = <<-JSON
      {
          "Refund":{
              "TransactionID":"#{trans_id}",
              "InvoiceReference":"1",
              "InvoiceDescription":"Store Purchase",
              "TotalAmount":100,
              "CurrencyCode":"AUD"
          },
          "Customer":{
              "FirstName":"Jim",
              "LastName":"Smith",
              "Title":"",
              "CompanyName":"Widgets Inc",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Fax":"(555)555-6666",
              "Email":"jim.smith@example.com"
          },
          "CustomerIP":"127.0.0.1",
          "DeviceID":"ActiveMerchant",
          "TransactionType":"MOTO"
      }
    JSON

    request
  end

  def failed_refund_response
    <<-JSON
      {
          "AuthorisationCode":"",
          "ResponseCode":null,
          "ResponseMessage":"S5010",
          "TransactionID":null,
          "TransactionStatus":false,
          "Verification":null,
          "Customer":{
              "CardDetails":{
                  "Number":null,
                  "Name":null,
                  "ExpiryMonth":null,
                  "ExpiryYear":null,
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":null,
              "Reference":null,
              "Title":null,
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":null,
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":null,
              "Comments":null,
              "Fax":"(555)555-6666",
              "Url":null
          },
          "Refund":{
              "TransactionID":null,
              "TotalAmount":100,
              "InvoiceNumber":null,
              "InvoiceDescription":null,
              "InvoiceReference":null,
              "CurrencyCode":null
          },
          "Errors":"S5010"
      }
    JSON
  end

  def successful_purchase_with_token_response
    <<-JSON
      {
          "AuthorisationCode":"511006",
          "ResponseCode":"00",
          "ResponseMessage":"A2000",
          "TransactionID":10328337,
          "TransactionStatus":true,
          "TransactionType":"MOTO",
          "BeagleScore":0,
          "Verification":{
              "CVN":0,
              "Address":0,
              "Email":0,
              "Mobile":0,
              "Phone":0
          },
          "Customer":{
              "CardDetails":{
                  "Number":"444433XXXXXX1111",
                  "Name":"Longbob Longsen",
                  "ExpiryMonth":"09",
                  "ExpiryYear":"14",
                  "StartMonth":"",
                  "StartYear":"",
                  "IssueNumber":""
              },
              "TokenCustomerID":918260741894,
              "Reference":"",
              "Title":"Mr.",
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":"",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Comments":"",
              "Fax":"(555)555-6666",
              "Url":""
          },
          "Payment":{
              "TotalAmount":100,
              "InvoiceNumber":"",
              "InvoiceDescription":"Store Purchase",
              "InvoiceReference":"1",
              "CurrencyCode":"AUD"
          },
          "Errors":null
      }
    JSON
  end

  def expected_purchase_with_token_request(token)
    request = <<-JSON
      {
          "Payment":{
            "InvoiceReference":"1",
            "InvoiceDescription":"Store Purchase",
            "TotalAmount":100,
            "CurrencyCode":"AUD"
          },
          "Customer":{
            "TokenCustomerID":"#{token}",
            "FirstName":"Jim",
            "LastName":"Smith",
            "Title":"",
            "CompanyName":"Widgets Inc",
            "Street1":"1234 My Street",
            "Street2":"Apt 1",
            "City":"Ottawa",
            "State":"ON",
            "PostalCode":"K1C2N6",
            "Country":"ca",
            "Phone":"(555)555-5555",
            "Mobile":"",
            "Fax":"(555)555-6666",
            "Email":"jim.smith@example.com"
          },
          "CustomerIP":"127.0.0.1",
          "DeviceID":"ActiveMerchant",
          "TransactionType":"MOTO"
      }
    JSON

    request
  end

  def failed_purchase_with_token_response
    <<-JSON
      {
          "AuthorisationCode":null,
          "ResponseCode":null,
          "ResponseMessage":null,
          "TransactionID":null,
          "TransactionStatus":null,
          "TransactionType":"MOTO",
          "BeagleScore":null,
          "Verification":null,
          "Customer":{
              "CardDetails":{
                  "Number":null,
                  "Name":null,
                  "ExpiryMonth":null,
                  "ExpiryYear":null,
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":0,
              "Reference":null,
              "Title":null,
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":null,
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":null,
              "Comments":null,
              "Fax":"(555)555-6666",
              "Url":null
          },
          "Payment":{
              "TotalAmount":100,
              "InvoiceNumber":null,
              "InvoiceDescription":"Store Purchase",
              "InvoiceReference":"1",
              "CurrencyCode":"AUD"
          },
          "Errors":"V6040,V6021,V6022,V6101,V6102"
      }
    JSON
  end

  def successful_update_response
    <<-JSON
      {
          "Customer":{
              "CardDetails":{
                  "Number":"444433XXXXXX1111",
                  "Name":"Longbob Longsen",
                  "ExpiryMonth":"03",
                  "ExpiryYear":"18",
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":915845997420,
              "Reference":"",
              "Title":"Mr.",
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":"",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Comments":"",
              "Fax":"(555)555-6666",
              "Url":""
          },
          "Errors":null
      }
    JSON
  end

  def expected_update_request(token)
    request = <<-JSON
      {
          "Customer":{
              "TokenCustomerID":"#{token}",
              "FirstName":"Jim",
              "LastName":"Smith",
              "Title":"",
              "CompanyName":"Widgets Inc",
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Phone":"(555)555-5555",
              "Mobile":"",
              "Fax":"(555)555-6666",
              "Email":"jim.smith@example.com",
              "CardDetails":{
                  "Name":"Longbob Longsen",
                  "Number":"4444333322221111",
                  "ExpiryMonth":"09",
                  "ExpiryYear":"14",
                  "CVN":"123"
              }
          },
          "CustomerIP":"127.0.0.1",
          "DeviceID":"ActiveMerchant",
          "TransactionType":"MOTO"
      }
    JSON

    request
  end

  def failed_update_response
    <<-JSON
      {
          "Customer":{
              "CardDetails":{
                  "Number":"444433XXXXXX1111",
                  "Name":"Longbob Longsen",
                  "ExpiryMonth":"09",
                  "ExpiryYear":"14",
                  "StartMonth":null,
                  "StartYear":null,
                  "IssueNumber":null
              },
              "TokenCustomerID":0,
              "Reference":null,
              "Title":"Mr.",
              "FirstName":"Jim",
              "LastName":"Smith",
              "CompanyName":"Widgets Inc",
              "JobDescription":null,
              "Street1":"1234 My Street",
              "Street2":"Apt 1",
              "City":"Ottawa",
              "State":"ON",
              "PostalCode":"K1C2N6",
              "Country":"ca",
              "Email":"jim.smith@example.com",
              "Phone":"(555)555-5555",
              "Mobile":null,
              "Comments":null,
              "Fax":"(555)555-6666",
              "Url":null
          },
          "Errors":"V6040"
      }
    JSON
  end
end
