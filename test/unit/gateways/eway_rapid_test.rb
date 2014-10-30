require "test_helper"

class EwayRapidTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = EwayRapidGateway.new(
      :login => "login",
      :password => "password"
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "Transaction Approved Successful", response.message
    assert_equal 10440187, response.authorization
    assert response.test?
  end

  def test_localized_currency
    stub_comms do
      @gateway.purchase(100, @credit_card, :currency => 'CAD')
    end.check_request do |endpoint, data, headers|
      assert_match '"TotalAmount":"100"', data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(100, @credit_card, :currency => 'JPY')
    end.check_request do |endpoint, data, headers|
      assert_match '"TotalAmount":"1"', data
    end.respond_with(successful_purchase_response)
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(-100, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Invalid Payment TotalAmount", response.message
    assert_nil response.authorization
    assert response.test?
  end

  def test_failed_purchase_without_message
    response = stub_comms do
      @gateway.purchase(-100, @credit_card)
    end.respond_with(failed_purchase_response_without_message)

    assert_failure response
    assert_equal "Do Not Honour", response.message
    assert_nil response.authorization
    assert response.test?
  end

  def test_failed_purchase_with_multiple_messages
    response = stub_comms do
      @gateway.purchase(-100, @credit_card)
    end.respond_with(failed_purchase_response_multiple_messages)

    assert_failure response
    assert_equal "Invalid Customer Phone,Invalid ShippingAddress Phone", response.message
    assert_nil response.authorization
    assert response.test?
  end

  def test_purchase_with_all_options
    response = stub_comms do
      @gateway.purchase(200, @credit_card,
        :transaction_type => 'CustomTransactionType',
        :redirect_url => "http://awesomesauce.com",
        :ip => "0.0.0.0",
        :application_id => "Woohoo",
        :description => "The Really Long Description More Than Sixty Four Characters Gets Truncated",
        :order_id => "orderid1",
        :currency => "INR",
        :email => "jim@example.com",
        :billing_address => {
          :title    => "Mr.",
          :name     => "Jim Awesome Smith",
          :company  => "Awesome Co",
          :address1 => "1234 My Street",
          :address2 => "Apt 1",
          :city     => "Ottawa",
          :state    => "ON",
          :zip      => "K1C2N6",
          :country  => "CA",
          :phone    => "(555)555-5555",
          :fax      => "(555)555-6666"
        },
        :shipping_address => {
          :title    => "Ms.",
          :name     => "Baker",
          :company  => "Elsewhere Inc.",
          :address1 => "4321 Their St.",
          :address2 => "Apt 2",
          :city     => "Chicago",
          :state    => "IL",
          :zip      => "60625",
          :country  => "US",
          :phone    => "1115555555",
          :fax      => "1115556666"
        }
      )
    end.check_request do |endpoint, data, headers|
      # assert_no_match(%r{#{@credit_card.number}}, data)

      assert_match(%r{"TransactionType":"CustomTransactionType"}, data)
      assert_match(%r{"RedirectUrl":"http://awesomesauce.com"}, data)
      assert_match(%r{"CustomerIP":"0.0.0.0"}, data)
      assert_match(%r{"DeviceID":"Woohoo"}, data)

      assert_match(%r{"TotalAmount":"200"}, data)
      assert_match(%r{"InvoiceDescription":"The Really Long Description More Than Sixty Four Characters Gets"}, data)
      assert_match(%r{"InvoiceReference":"orderid1"}, data)
      assert_match(%r{"CurrencyCode":"INR"}, data)

      assert_match(%r{"Title":"Mr."}, data)
      assert_match(%r{"FirstName":"Jim"}, data)
      assert_match(%r{"LastName":"Awesome Smith"}, data)
      assert_match(%r{"CompanyName":"Awesome Co"}, data)
      assert_match(%r{"Street1":"1234 My Street"}, data)
      assert_match(%r{"Street2":"Apt 1"}, data)
      assert_match(%r{"City":"Ottawa"}, data)
      assert_match(%r{"State":"ON"}, data)
      assert_match(%r{"PostalCode":"K1C2N6"}, data)
      assert_match(%r{"Country":"ca"}, data)
      assert_match(%r{"Phone":"\(555\)555-5555"}, data)
      assert_match(%r{"Fax":"\(555\)555-6666"}, data)
      assert_match(%r{"Email":"jim@example\.com"}, data)

      assert_match(%r{"Title":"Ms."}, data)
      assert_match(%r{"LastName":"Baker"}, data)
      assert_no_match(%r{Elsewhere Inc.}, data)
      assert_match(%r{"Street1":"4321 Their St."}, data)
      assert_match(%r{"Street2":"Apt 2"}, data)
      assert_match(%r{"City":"Chicago"}, data)
      assert_match(%r{"State":"IL"}, data)
      assert_match(%r{"PostalCode":"60625"}, data)
      assert_match(%r{"Country":"us"}, data)
      assert_match(%r{"Phone":"1115555555"}, data)
      assert_match(%r{"Fax":"1115556666"}, data)
      assert_match(%r{"Email":null}, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 10440187, response.authorization
    assert response.test?
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "Transaction Approved Successful", response.message
    assert_equal 10774952, response.authorization
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(nil, "auth")
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal "982541", response.message
    assert_equal 10774953, response.authorization
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Invalid Payment TotalAmount", response.message
    assert_nil response.authorization
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(@amount, "auth")
    end.respond_with(failed_capture_response)

    assert_failure response
    assert_equal "Invalid Auth Transaction ID for Capture/Void", response.message
    assert_equal 0, response.authorization
  end

  def test_successful_void
    response = stub_comms do
      @gateway.void("auth")
    end.respond_with(successful_void_response)

    assert_success response
    assert_equal "878060", response.message
    assert_equal 10775041, response.authorization
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void(@amount, "auth")
    end.respond_with(failed_void_response)

    assert_failure response
    assert_equal "Invalid Auth Transaction ID for Capture/Void", response.message
    assert_equal 0, response.authorization
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, :billing_address => {
          :title    => "Mr.",
          :name     => "Jim Awesome Smith",
          :company  => "Awesome Co",
          :address1 => "1234 My Street",
          :address2 => "Apt 1",
          :city     => "Ottawa",
          :state    => "ON",
          :zip      => "K1C2N6",
          :country  => "CA",
          :phone    => "(555)555-5555",
          :fax      => "(555)555-6666"
        })
    end.check_request do |endpoint, data, headers|
      assert_match '"Method":"CreateTokenCustomer"', data
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal "Transaction Approved Successful", response.message
    assert_equal 917224224772, response.authorization
    assert response.test?
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card, :billing_address => {})
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal "Customer CountryCode Required", response.message
    assert_nil response.authorization
    assert response.test?
  end

  def test_successful_update
    response = stub_comms do
      @gateway.update('faketoken', nil)
    end.check_request do |endpoint, data, headers|
      assert_match '"Method":"UpdateTokenCustomer"', data
    end.respond_with(successful_update_response)

    assert_success response
    assert_equal "Transaction Approved Successful", response.message
    assert_equal 916161208398, response.authorization
    assert response.test?
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, '1234567')
    end.check_request do |endpoint, data, headers|
      assert_match %r{Transaction\/1234567\/Refund$}, endpoint
      json = JSON.parse(data)
      assert_equal '100', json['Refund']['TotalAmount']
      assert_equal '1234567', json['Refund']['TransactionID']
    end.respond_with(successful_refund_response)

    assert_success response
    assert_equal "Transaction Approved Successful", response.message
    assert_equal 10488258, response.authorization
    assert response.test?
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(@amount, '1234567')
    end.respond_with(failed_refund_response)

    assert_failure response
    assert_equal "System Error", response.message
    assert_nil response.authorization
    assert response.test?
  end

  def test_successful_stored_card_purchase
    response = stub_comms do
      @gateway.purchase(100, 'the_customer_token', transaction_type: 'MOTO')
    end.check_request do |endpoint, data, headers|
      assert_match '"Method":"TokenPayment"', data
      assert_match '"TransactionType":"MOTO"', data
    end.respond_with(successful_store_purchase_response)

    assert_success response
    assert_equal "Transaction Approved Successful", response.message
    assert_equal 10440234, response.authorization
    assert response.test?
  end

  def test_verification_results
    response = stub_comms do
      @gateway.purchase(100, @credit_card)
    end.respond_with(successful_purchase_response(:verification_status => "Valid"))

    assert_success response
    assert_equal "M", response.cvv_result["code"]
    assert_equal "M", response.avs_result["code"]

    response = stub_comms do
      @gateway.purchase(100, @credit_card)
    end.respond_with(successful_purchase_response(:verification_status => "Invalid"))

    assert_success response
    assert_equal "N", response.cvv_result["code"]
    assert_equal "N", response.avs_result["code"]

    response = stub_comms do
      @gateway.purchase(100, @credit_card)
    end.respond_with(successful_purchase_response(:verification_status => "Unchecked"))

    assert_success response
    assert_equal "P", response.cvv_result["code"]
    assert_equal "I", response.avs_result["code"]
  end

  private

  def successful_purchase_response(options = {})
    verification_status = options[:verification_status] || 0
    verification_status = %Q{"#{verification_status}"} if verification_status.is_a? String
    %(
      {
        "AuthorisationCode": "763051",
        "ResponseCode": "00",
        "ResponseMessage": "A2000",
        "TransactionID": 10440187,
        "TransactionStatus": true,
        "TransactionType": "Purchase",
        "BeagleScore": 0,
        "Verification": {
          "CVN": #{verification_status},
          "Address": #{verification_status},
          "Email": #{verification_status},
          "Mobile": #{verification_status},
          "Phone": #{verification_status}
        },
        "Customer": {
          "CardDetails": {
            "Number": "444433XXXXXX1111",
            "Name": "Longbob Longsen",
            "ExpiryMonth": "09",
            "ExpiryYear": "14",
            "StartMonth": null,
            "StartYear": null,
            "IssueNumber": null
          },
          "TokenCustomerID": null,
          "Reference": "",
          "Title": "Mr.",
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": "",
          "Street1": "1234 My Street",
          "Street2": "Apt 1",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": "ca",
          "Email": "",
          "Phone": "(555)555-5555",
          "Mobile": "",
          "Comments": "",
          "Fax": "(555)555-6666",
          "Url": ""
        },
        "Payment": {
          "TotalAmount": 100,
          "InvoiceNumber": "",
          "InvoiceDescription": "Store Purchase",
          "InvoiceReference": "1",
          "CurrencyCode": "AUD"
        },
        "Errors": null
      }
    )
  end

  def failed_purchase_response_without_message
    %(
      {
        "AuthorisationCode": null,
        "ResponseCode": "05",
        "TransactionID": null,
        "TransactionStatus": null,
        "TransactionType": "Purchase",
        "BeagleScore": null,
        "Verification": null,
        "Customer": {
        }
      }
    )
  end

  def failed_purchase_response_multiple_messages
    %(
      {
        "AuthorisationCode": null,
        "ResponseCode": null,
        "ResponseMessage": "V6070,V6083",
        "TransactionID": null,
        "TransactionStatus": null,
        "TransactionType": "Purchase",
        "BeagleScore": null,
        "Verification": null,
        "Customer": {
        }
      }
    )
  end

  def failed_purchase_response
    %(
      {
        "AuthorisationCode": null,
        "ResponseCode": null,
        "ResponseMessage": null,
        "TransactionID": null,
        "TransactionStatus": null,
        "TransactionType": "Purchase",
        "BeagleScore": null,
        "Verification": null,
        "Customer": {
          "CardDetails": {
            "Number": "444433XXXXXX1111",
            "Name": "Longbob Longsen",
            "ExpiryMonth": "09",
            "ExpiryYear": "2014",
            "StartMonth": null,
            "StartYear": null,
            "IssueNumber": null
          },
          "TokenCustomerID": null,
          "Reference": null,
          "Title": "Mr.",
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": null,
          "Street1": "1234 My Street",
          "Street2": "Apt 1",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": "ca",
          "Email": null,
          "Phone": "(555)555-5555",
          "Mobile": null,
          "Comments": null,
          "Fax": "(555)555-6666",
          "Url": null
        },
        "Payment": {
          "TotalAmount": -100,
          "InvoiceNumber": null,
          "InvoiceDescription": "Store Purchase",
          "InvoiceReference": "1",
          "CurrencyCode": "AUD"
        },
        "Errors": "V6011"
      }
    )
  end

  def successful_authorize_response
    %(
      {
        "AuthorisationCode": "805851",
        "ResponseCode": "00",
        "ResponseMessage": "A2000",
        "TransactionID": 10774952,
        "TransactionStatus": true,
        "TransactionType": "Purchase",
        "BeagleScore": 0,
        "Verification": {
          "CVN": 0,
          "Address": 0,
          "Email": 0,
          "Mobile": 0,
          "Phone": 0
        },
        "Customer": {
          "CardDetails": {
          "Number": "444433XXXXXX1111",
          "Name": "Longbob Longsen",
          "ExpiryMonth": "09",
          "ExpiryYear": "15",
          "StartMonth": null,
          "StartYear": null,
          "IssueNumber": null
        },
        "TokenCustomerID": null,
        "Reference": "",
        "Title": "Mr.",
        "FirstName": "Jim",
        "LastName": "Smith",
        "CompanyName": "Widgets Inc",
        "JobDescription": "",
        "Street1": "1234 My Street",
        "Street2": "Apt 1",
        "City": "Ottawa",
        "State": "ON",
        "PostalCode": "K1C2N6",
        "Country": "ca",
        "Email": "",
        "Phone": "(555)555-5555",
        "Mobile": "",
        "Comments": "",
        "Fax": "(555)555-6666",
        "Url": ""
        },
        "Payment": {
          "TotalAmount":100,
          "InvoiceNumber": "",
          "InvoiceDescription": "Store Purchase",
          "InvoiceReference": "1",
        "CurrencyCode": "AUD"
        },
        "Errors": null
      }
    )
  end

  def failed_authorize_response
    %(
      {
        "AuthorisationCode": null,
        "ResponseCode": null,
        "ResponseMessage": null,
        "TransactionID": null,
        "TransactionStatus": null,
        "TransactionType": "Purchase",
        "BeagleScore": null,
        "Verification": null,
        "Customer": {
          "CardDetails": {
            "Number": "444433XXXXXX1111",
            "Name": "Longbob Longsen",
            "ExpiryMonth": "09",
            "ExpiryYear": "2015",
            "StartMonth": null,
            "StartYear": null,
            "IssueNumber": null
          },
          "TokenCustomerID": null,
          "Reference": null,
          "Title": "Mr.",
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": null,
          "Street1": "1234 My Street",
          "Street2": "Apt 1",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": "ca",
          "Email": null,
          "Phone": "(555)555-5555",
          "Mobile": null,
          "Comments": null,
          "Fax": "(555)555-6666",
          "Url": null
        },
        "Payment": {
          "TotalAmount": -100,
          "InvoiceNumber": null,
          "InvoiceDescription": "Store Purchase",
          "InvoiceReference": "1",
          "CurrencyCode": "AUD"
        },
        "Errors": "V6011"
      }
    )
  end

  def successful_capture_response
    %(
      {
        "ResponseCode": "982541",
        "ResponseMessage": "982541",
        "TransactionID": 10774953,
        "TransactionStatus": true,
        "Errors": null
      }
    )
  end

  def failed_capture_response
    %(
      {
        "ResponseCode": null,
        "ResponseMessage": null
        ,"TransactionID": 0
        ,"TransactionStatus": false,
        "Errors": "V6134"
      }
    )
  end

  def successful_void_response
    %(
      {
        "ResponseCode": "878060",
        "ResponseMessage": "878060",
        "TransactionID": 10775041,
        "TransactionStatus": true,
        "Errors": null
      }
    )
  end

  def failed_void_response
    %(
      {
        "ResponseCode": null,
        "ResponseMessage": null,
        "TransactionID": 0,
        "TransactionStatus": false,
        "Errors": "V6134"
      }
    )
  end

  def successful_store_response
    %(
      {
        "AuthorisationCode": null,
        "ResponseCode": "00",
        "ResponseMessage": "A2000",
        "TransactionID": null,
        "TransactionStatus": false,
        "TransactionType": "Purchase",
        "BeagleScore": null,
        "Verification": {
          "CVN": 0,
          "Address": 0,
          "Email": 0,
          "Mobile": 0,
          "Phone": 0
        },
        "Customer": {
          "CardDetails": {
            "Number": "444433XXXXXX1111",
            "Name": "Longbob Longsen",
            "ExpiryMonth": "09",
            "ExpiryYear": "14",
            "StartMonth": null,
            "StartYear": null,
            "IssueNumber": null
          },
          "TokenCustomerID": 917224224772,
          "Reference": "",
          "Title": "Dr.",
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": "",
          "Street1": "1234 My Street",
          "Street2": "Apt 1",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": "ca",
          "Email": "",
          "Phone": "(555)555-5555",
          "Mobile": "",
          "Comments": "",
          "Fax": "(555)555-6666",
          "Url": ""
        },
        "Payment": {
          "TotalAmount": 0,
          "InvoiceNumber": "",
          "InvoiceDescription": "Store Purchase",
          "InvoiceReference": "1",
          "CurrencyCode": "AUD"
        },
        "Errors": null
      }
    )
  end

  def failed_store_response
    %(
      {
        "AuthorisationCode": null,
        "ResponseCode": null,
        "ResponseMessage": null,
        "TransactionID": null,
        "TransactionStatus": null,
        "TransactionType": "Purchase",
        "BeagleScore": null,
        "Verification": null,
        "Customer": {
          "CardDetails": {
            "Number": "444433XXXXXX1111",
            "Name": "Longbob Longsen",
            "ExpiryMonth": "09",
            "ExpiryYear": "2014",
            "StartMonth": null,
            "StartYear": null,
            "IssueNumber": null
          },
          "TokenCustomerID": null,
          "Reference": null,
          "Title": "Mr.",
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": null,
          "Street1": "1234 My Street",
          "Street2": "Apt 1",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": null,
          "Email": null,
          "Phone": "(555)555-5555",
          "Mobile": null,
          "Comments": null,
          "Fax": "(555)555-6666",
          "Url": null
        },
        "Payment": {
          "TotalAmount": 0,
          "InvoiceNumber": null,
          "InvoiceDescription": "Store Purchase",
          "InvoiceReference": "1",
          "CurrencyCode": "AUD"
        },
        "Errors": "V6044"
      }
    )
  end

  def successful_update_response
    %(
      {
        "AuthorisationCode": null,
        "ResponseCode": "00",
        "ResponseMessage": "A2000",
        "TransactionID": null,
        "TransactionStatus": false,
        "TransactionType": "Purchase",
        "BeagleScore": null,
        "Verification": {
          "CVN": 0,
          "Address": 0,
          "Email": 0,
          "Mobile": 0,
          "Phone": 0
        },
        "Customer": {
          "CardDetails": {
            "Number": "444433XXXXXX1111",
            "Name": "Longbob Longsen",
            "ExpiryMonth": "09",
            "ExpiryYear": "14",
            "StartMonth": null,
            "StartYear": null,
            "IssueNumber": null
          },
          "TokenCustomerID": 916161208398,
          "Reference": "",
          "Title": "Dr.",
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": "",
          "Street1": "1234 My Street",
          "Street2": "Apt 1",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": "ca",
          "Email": "",
          "Phone": "(555)555-5555",
          "Mobile": "",
          "Comments": "",
          "Fax": "(555)555-6666",
          "Url": ""
        },
        "Payment": {
          "TotalAmount": 0,
          "InvoiceNumber": "",
          "InvoiceDescription": "Store Purchase",
          "InvoiceReference": "1",
          "CurrencyCode": "AUD"
        },
        "Errors": null
      }
    )
  end

  def successful_refund_response
    %(
      {
        "AuthorisationCode": "457313",
        "ResponseCode": null,
        "ResponseMessage": "A2000",
        "TransactionID": 10488258,
        "TransactionStatus": true,
        "Verification": null,
        "Customer": {
          "CardDetails": {
            "Number": null,
            "Name": null,
            "ExpiryMonth": null,
            "ExpiryYear": null,
            "StartMonth": null,
            "StartYear": null,
            "IssueNumber": null
          },
          "TokenCustomerID": null,
          "Reference": null,
          "Title": null,
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": null,
          "Street1": "1234 My Street",
          "Street2": "Apt 1",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": "ca",
          "Email": null,
          "Phone": "(555)555-5555",
          "Mobile": null,
          "Comments": null,
          "Fax": "(555)555-6666",
          "Url": null
        },
        "Refund": {
          "TransactionID": null,
          "TotalAmount": 0,
          "InvoiceNumber": null,
          "InvoiceDescription": null,
          "InvoiceReference": null,
          "CurrencyCode": null
        },
        "Errors": null
      }
    )
  end

  def failed_refund_response
    %(
      {
        "AuthorisationCode": null,
        "ResponseCode": null,
        "ResponseMessage": null,
        "TransactionID": null,
        "TransactionStatus": false,
        "Verification": null,
        "Customer": {
          "CardDetails": {
            "Number": null,
            "Name": null,
            "ExpiryMonth": null,
            "ExpiryYear": null,
            "StartMonth": null,
            "StartYear": null,
            "IssueNumber": null
          },
          "TokenCustomerID": null,
          "Reference": null,
          "Title": null,
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": null,
          "Street1": "1234 My Street",
          "Street2": "Apt 1",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": "ca",
          "Email": null,
          "Phone": "(555)555-5555",
          "Mobile": null,
          "Comments": null,
          "Fax": "(555)555-6666",
          "Url": null
        },
        "Refund": {
          "TransactionID": null,
          "TotalAmount": 0,
          "InvoiceNumber": null,
          "InvoiceDescription": null,
          "InvoiceReference": null,
          "CurrencyCode": null
        },
        "Errors": "S5000"
      }
    )
  end

  def successful_store_purchase_response
    %(
      {
        "AuthorisationCode": "232671",
        "ResponseCode": "00",
        "ResponseMessage": "A2000",
        "TransactionID": 10440234,
        "TransactionStatus": true,
        "TransactionType": "MOTO",
        "BeagleScore": 0,
        "Verification": {
          "CVN": 0,
          "Address": 0,
          "Email": 0,
          "Mobile": 0,
          "Phone": 0
        },
        "Customer": {
          "CardDetails": {
            "Number": "444433XXXXXX1111",
            "Name": "Longbob Longsen",
            "ExpiryMonth": "09",
            "ExpiryYear": "14",
            "StartMonth": "",
            "StartYear": "",
            "IssueNumber": ""
          },
          "TokenCustomerID": 912056757740,
          "Reference": "",
          "Title": "Mr.",
          "FirstName": "Jim",
          "LastName": "Smith",
          "CompanyName": "Widgets Inc",
          "JobDescription": "",
          "Street1": "1234 My Street, Apt 1",
          "Street2": "",
          "City": "Ottawa",
          "State": "ON",
          "PostalCode": "K1C2N6",
          "Country": "ca",
          "Email": "",
          "Phone": "(555)555-5555",
          "Mobile": "",
          "Comments": "",
          "Fax": "(555)555-6666",
          "Url": ""
        },
        "Payment": {
          "TotalAmount": 100,
          "InvoiceNumber": "",
          "InvoiceDescription": "",
          "InvoiceReference": "",
          "CurrencyCode": "AUD"
        },
        "Errors": null
      }
    )
  end

end
