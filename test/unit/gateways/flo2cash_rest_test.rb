require 'test_helper'

class Flo2cashRestTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = Flo2cashRestGateway.new(
      :merchant_id => 'account_id',
      :api_key => 'api_key'
    )

    @credit_card = credit_card
    @token = '105463784931'
    @amount = 100

    @options = {
      payment_method_type: 'token',
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      api_key: 'xxx',
      merchant_id: 'mid',
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @token, @options)
    assert_success response

    assert_equal 'P1904M0000251709', response.authorization
    assert response.test?
  end

  def test_fail_purchase
    @gateway.expects(:ssl_request).returns(fail_purchase_response)

    response = @gateway.purchase(@amount, @token, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'payment_id', @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_refund
    @gateway.expects(:commit).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'payment_id', @options)
    assert_failure response
    assert_equal 'This Refund would exceed the amount of the original transact', response.message
  end

  def test_sucessful_card_plan_creation
    @gateway.expects(:ssl_request).returns(successful_card_plan_creation_response)

    response = @gateway.create_card_plan('token', @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 25, response.params['paymentSchedule'].count
  end

  def test_fail_retrieve_card_plan
    @gateway.expects(:commit).returns(fail_retrieve_card_plan_response)

    response = @gateway.retrieve_card_plan('x', @options)
    assert_equal 'Card Plan not found', response.message
  end

  def test_successful_direct_debit_plan_creation
    @gateway.expects(:ssl_request).returns(successful_direct_debit_plan_response)

    response = @gateway.create_direct_debit_plan(@options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 25, response.params['paymentSchedule'].count
  end

  def test_fail_direct_debit_plan_creation
    @gateway.expects(:commit).returns(fail_direct_debit_plan_response)

    response = @gateway.create_direct_debit_plan(@options)
    assert_equal "'Bank Details. Account. Number' must not be empty.", response.message
  end

  private

  def successful_store_response
    {
      'token' => '105463784931',
      'created' => '2019-03-30T15:11:45',
      'uniqueReference' => 'uuid',
      'merchant' => { 'id' => 51145 },
      'card' =>{
        'type' => 'visa',
        'mask' => '400010******2224',
        'bin' => '400010',
        'expiryDate' => '0920',
        'lastFour' => '2224',
        'nameOnCard' => 'Longbob Longsen'} }
  end

  def successful_purchase_response
    {
      "number"=>"P1904M0000251709",
      "timestamp"=>"2019-04-08T11:36:57",
      "type"=>"purchase",
      "status"=>"successful",
      "channel"=>"web",
      "reference"=>nil,
      "particulars"=>nil,
      "amount"=>10.0,
      "amountCaptured"=>10.0,
      "amountRefunded"=>0.0,
      "currency"=>"NZD",
      "initiatedBy"=>nil,
      "receiptRecipient"=>"john.doe@test.com",
      "response"=>{
        "code"=>0,
        "message"=>"successful",
        "providerResponse"=>"00",
        "authCode"=>"C52AA4"
      },
      "merchant"=>{
        "id"=>51145,
        "subAccount"=>11178
      },
      "paymentMethod"=>{
        "card"=>{
          "type"=>"visa",
          "mask"=>"400010******2224",
          "bin"=>"400010",
          "lastFour"=>"2224",
          "expiryDate"=>"0920",
          "nameOnCard"=>"Longbob Longsen",
          "token"=>"37365923419"
        }
      }
    }.to_json
  end

  def fail_purchase_response
    {
      "number"=>"P1904M0000251720",
      "timestamp"=>"2019-04-08T11:57:11",
      "type"=>"purchase",
      "status"=>"declined",
      "channel"=>"web",
      "reference"=>nil,
      "particulars"=>nil,
      "amount"=>17.51,
      "amountCaptured"=>0.0,
      "amountRefunded"=>0.0,
      "currency"=>"NZD",
      "initiatedBy"=>nil,
      "receiptRecipient"=>"john.doe@test.com",
      "response"=>{
        "code"=>200,
        "message"=>"declined - insufficient funds",
        "providerResponse"=>"51",
        "authCode"=>"CE1D11"
      },
      "merchant"=>{
        "id"=>51145,
        "subAccount"=>11178
      },
      "paymentMethod"=>{
        "card"=>{
          "type"=>"visa",
          "mask"=>"400010******2224",
          "bin"=>"400010",
          "lastFour"=>"2224",
          "expiryDate"=>"0920",
          "nameOnCard"=>"Longbob Longsen",
          "token"=>"93765945121"
        }
      },
      "device"=>nil,
      "geolocation"=>nil,
      "refunds"=>nil,
      "captures"=>nil
    }.to_json
  end

  def successful_refund_response
    {
      "number" => "P1904M0000251755",
      "timestamp" => "2019-04-08T12:51:52",
      "type" => "purchase",
      "status" => "successful",
      "channel" => "web",
      "reference" => nil,
      "particulars" => nil,
      "amount" => 10.0,
      "amountCaptured" => 10.0,
      "amountRefunded" => 10.0,
      "currency" => "NZD",
      "initiatedBy" => nil,
      "receiptRecipient" => "john.doe@test.com",
      "response" => {
        "code" => 0,
        "message" => "successful",
        "providerResponse" => "00",
        "authCode" => "EA0D5D"
      },
      "merchant" => {
        "id" => 51145,
        "subAccount" => 11178
      },
      "paymentMethod" => {
        "card" => {
          "type" => "visa",
          "mask" => "400010******2224",
          "bin" => "400010",
          "lastFour" => "2224",
          "expiryDate" => "0920",
          "nameOnCard" => "Longbob Longsen",
          "token" => "109065965928"
        }
      },
      "device" => nil,
      "geolocation" => nil,
      "refunds" => [
        {
          "number" => "P1904M0000251756",
          "timestamp" => "2019-04-08T00:51:54",
          "amount" => 10.0,
          "currency" => "NZD",
          "reference" => nil,
          "particulars" => nil,
          "response" => {
            "code" => 0,
            "message" => "Successful",
            "providerResponse" => "00",
            "authCode" => "6A6A8D"
          }
        }
      ],
      "captures" => nil
    }.to_json
  end

  def failed_refund_response
    ActiveMerchant::Billing::Response.new(
      false,
      'This Refund would exceed the amount of the original transact')
  end

  def successful_card_plan_creation_response
    {
      "id" => 2618,
      "created" => "2019-04-08T15:41:15",
      "startDate" => "2019-05-08",
      "amendmentDate" => nil,
      "nextPaymentDate" => "2019-05-08",
      "type" => "recurring",
      "frequency" => "monthly",
      "status" => "active",
      "statusChangedDate" => "2019-04-08T15:41:15",
      "amount" => 10.0,
      "totalAmount" => nil,
      "currency" => "NZD",
      "reference" => "",
      "particulars" => "",
      "instalmentFailOption" => "",
      "retryPreferences" => nil,
      "merchant" => {
        "id" => 51145,
        "subAccount" => 11178
      },
      "initialPayment" => {
        "date" => "2019-05-08",
        "amount" => 10.0
      },
      "payer" => {
        "companyName" => nil,
        "title" => "Mr.",
        "firstNames" => "John",
        "lastName" => "Doe",
        "dateOfBirth" => nil,
        "telephoneHome" => nil,
        "telephoneWork" => nil,
        "telephoneMobile" => nil,
        "fax" => nil,
        "email" => "john.doe@test.com",
        "address1" => nil,
        "address2" => nil,
        "address3" => nil,
        "suburb" => nil,
        "city" => nil,
        "postcode" => nil,
        "state" => "",
        "country" => ""
      },
      "card" => {
        "type" => "Visa",
        "mask" => "400010******2224",
        "bin" => "400010",
        "lastFour" => "2224",
        "expiryDate" => "0920",
        "nameOnCard" => "Longbob Longsen"
      },
      "amendments" => [],
      "paymentSchedule" => [
        {
          "date" => "2019-05-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2019-05-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2019-06-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2019-07-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2019-08-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2019-09-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2019-10-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2019-11-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2019-12-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-01-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-02-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-03-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-04-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-05-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-06-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-07-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-08-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-09-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-10-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-11-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2020-12-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2021-01-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2021-02-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2021-03-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        },
        {
          "date" => "2021-04-08",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "payment" => nil,
          "retries" => nil
        }
      ]
    }.to_json
  end

  def fail_retrieve_card_plan_response
    ActiveMerchant::Billing::Response.new(false, 'Card Plan not found')
  end

  def successful_direct_debit_plan_response
    {
      "id" => 4559,
      "created" => "2019-04-09T15:18:12",
      "startDate" => "2019-05-09",
      "approvalDate" => nil,
      "amendmentDate" => nil,
      "nextPaymentDate" => "2019-05-09",
      "type" => "recurring",
      "frequency" => "monthly",
      "status" => "pending-approval",
      "statusChangedDate" => "2019-04-09T15:18:12",
      "amount" => 10.0,
      "totalAmount" => nil,
      "currency" => "NZD",
      "reference" => "",
      "particulars" => "",
      "instalmentFailOption" => "",
      "merchantReference1" => nil,
      "merchantReference2" => nil,
      "merchantReference3" => nil,
      "merchant" => {
        "id" => 51145
      },
      "initialPayment" => {
        "date" => "2019-05-09",
        "amount" => 10.0
      },
      "payer" => {
        "companyName" => nil,
        "title" => "Mr.",
        "firstNames" => "John",
        "lastName" => "Doe",
        "dateOfBirth" => nil,
        "telephoneHome" => nil,
        "telephoneWork" => nil,
        "telephoneMobile" => nil,
        "fax" => nil,
        "email" => "john.doe@test.com",
        "address1" => nil,
        "address2" => nil,
        "address3" => nil,
        "suburb" => nil,
        "city" => nil,
        "postcode" => nil,
        "state" => "",
        "country" => ""
      },
      "bankDetails" => {
        "name" => "BNZ",
        "branchAddress1" => "123 Street",
        "branchAddress2" => "Suburb, City",
        "account" => {
          "name" => "Account Name",
          "number" => "44 - 1100 - 0000000 - 000"
        }
      },
      "amendments" => [],
      "paymentSchedule" => [
        {
          "date" => "2019-05-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2019-05-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2019-06-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2019-07-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2019-08-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2019-09-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2019-10-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2019-11-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2019-12-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-01-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-02-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-03-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-04-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-05-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-06-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-07-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-08-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-09-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-10-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-11-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2020-12-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2021-01-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2021-02-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2021-03-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        },
        {
          "date" => "2021-04-09",
          "status" => "scheduled",
          "amount" => 10.0,
          "skip" => false,
          "directDebit" => nil
        }
      ]
    }.to_json
  end

  def fail_direct_debit_plan_response
    ActiveMerchant::Billing::Response.new(false, "'Bank Details. Account. Number' must not be empty.")
  end
end
