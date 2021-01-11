require 'test_helper'

class TwoCTwoPGatewayTest < Test::Unit::TestCase
  def setup
    pem_2c2p = File.read(File.join(File.dirname(__FILE__), '../../support/files/2c2p.pem'))

    @gateway = TwoCTwoPGateway.new(
      merchant_id: 'login',
      secret_key: 'password',
      merchant_pem_password: 'password',
      pem_2c2p: pem_2c2p,
      merchant_private_pem: 'private_key',
      merchant_cert: 'merchant_cert')

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:parse).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '936267', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:parse).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "The length of 'pan' field does not match.", response.error_code
  end

  private

  def successful_purchase_response
    {
      "PaymentResponse"=>{
        "version"=>"9.7",
        "timeStamp"=>"070121061206",
        "merchantID"=>"764764000001638",
        "respCode"=>"00",
        "pan"=>"424242XXXXXX4242",
        "amt"=>"000000001000",
        "uniqueTransactionCode"=>"e6b2aeddfe",
        "tranRef"=>"3481964",
        "approvalCode"=>"936267",
        "refNumber"=>"e6b2aeddfe",
        "eci"=>"06",
        "dateTime"=>"070121131209",
        "status"=>"A",
        "failReason"=>"Approved",
        "userDefined1"=>nil,
        "userDefined2"=>nil,
        "userDefined3"=>nil,
        "userDefined4"=>nil,
        "userDefined5"=>nil,
        "ippPeriod"=>nil,
        "ippInterestType"=>nil,
        "ippInterestRate"=>nil,
        "ippMerchantAbsorbRate"=>nil,
        "paidChannel"=>nil,
        "paidAgent"=>nil,
        "paymentChannel"=>nil,
        "backendInvoice"=>"3322910",
        "issuerCountry"=>"US",
        "issuerCountryA3"=>"USA",
        "bankName"=>"JPMORGAN CHASE BANK NA",
        "cardType"=>"CREDIT",
        "processBy"=>"VI",
        "paymentScheme"=>"VI",
        "rateQuoteID"=>nil,
        "originalAmount"=>nil,
        "fxRate"=>"0.3883",
        "currencyCode"=>"608",
        "hashValue"=>"E7F7A217CB99B1C67A161A99C1451D598492E013"
      }
    }
  end

  def failed_purchase_response
    {
      "PaymentResponse"=>{
        "version"=>"9.7",
        "timeStamp"=>"070121131521",
        "merchantID"=>"764764000001638",
        "respCode"=>"99",
        "pan"=>nil,
        "amt"=>"000000001000",
        "uniqueTransactionCode"=>"974a80e935",
        "tranRef"=>nil,
        "approvalCode"=>nil,
        "refNumber"=>nil,
        "eci"=>nil,
        "dateTime"=>"070121131521",
        "status"=>"F",
        "failReason"=>"The length of 'pan' field does not match.",
        "userDefined1"=>nil,
        "userDefined2"=>nil,
        "userDefined3"=>nil,
        "userDefined4"=>nil,
        "userDefined5"=>nil,
        "ippPeriod"=>nil,
        "ippInterestType"=>nil,
        "ippInterestRate"=>nil,
        "ippMerchantAbsorbRate"=>nil,
        "paidChannel"=>nil,
        "paidAgent"=>nil,
        "paymentChannel"=>nil,
        "backendInvoice"=>nil,
        "issuerCountry"=>nil,
        "issuerCountryA3"=>nil,
        "bankName"=>nil,
        "cardType"=>nil,
        "processBy"=>nil,
        "paymentScheme"=>nil,
        "rateQuoteID"=>nil,
        "originalAmount"=>nil,
        "fxRate"=>nil,
        "currencyCode"=>nil,
        "hashValue"=>"7FB8AFA6B100BECBFA489347DEF3A18ECD5D7751"
      }
    }
  end
end
