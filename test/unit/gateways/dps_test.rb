require File.dirname(__FILE__) + '/../../test_helper'

class DpsTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
        
    @gateway = DpsGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @visa = CreditCard.new(
      :number => '4242424242424242',
      :month => 8,
      :year => 2008,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => 'visa'
    )
    
    @solo = CreditCard.new(
      :type   => "solo",
      :number => "6334900000000005",
      :month  => 11,
      :year   => 2012,
      :first_name  => "Test",
      :last_name   => "Mensch",
      :issue_number => '01'
    )

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
  end
  
  def test_successful_request
    @visa.number = 1
    assert response = @gateway.purchase(Money.new(100), @visa)
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @visa.number = 2
    assert response = @gateway.purchase(Money.new(100), @visa)
    assert !response.success?
    assert response.test?
  end

  def test_request_error
    @visa.number = 3
    assert_raise(Error){ @gateway.purchase(Money.new(100), @visa) }
  end
  
  def test_default_currency
    assert_equal 'NZD', DpsGateway.default_currency
  end
  
  def test_invalid_credentials
    @gateway.expects(:ssl_post).returns(invalid_credentials_response)
    
    assert response = @gateway.purchase(Money.new(100, 'NZD'), @visa)
    assert_equal 'Invalid Credentials', response.message
    assert !response.success?
  end
  
  def test_successful_authorization
     @gateway.expects(:ssl_post).returns(successful_authorization_response)

     assert response = @gateway.purchase(Money.new(100, 'NZD'), @visa)
     assert response.success?
     assert response.test?
     assert_equal 'APPROVED', response.message
     assert_equal '00000004011a2478', response.authorization
  end
  
  def test_successful_solo_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

     assert response = @gateway.purchase(Money.new(100, 'NZD'), @solo)
     assert response.success?
     assert response.test?
     assert_equal 'APPROVED', response.message
     assert_equal '00000004011a2478', response.authorization
  end
  
  private
  def invalid_credentials_response
    '<Txn><ReCo>0</ReCo><ResponseText>Invalid Credentials</ResponseText></Txn>'
  end
  
  def successful_authorization_response
    <<-RESPONSE
<Txn>
  <Transaction success="1" reco="00" responsetext="APPROVED">
    <Authorized>1</Authorized>
    <MerchantReference>Test Transaction</MerchantReference>
    <Cvc2></Cvc2>
    <CardName>Visa</CardName>
    <Retry>0</Retry>
    <StatusRequired>0</StatusRequired>
    <AuthCode>015921</AuthCode>
    <Amount>1.23</Amount>
    <InputCurrencyId>1</InputCurrencyId>
    <InputCurrencyName>NZD</InputCurrencyName>
    <Acquirer>WestpacTrust</Acquirer>
    <CurrencyId>1</CurrencyId>
    <CurrencyName>NZD</CurrencyName>
    <CurrencyRate>1.00</CurrencyRate>
    <Acquirer>WestpacTrust</Acquirer>
    <AcquirerDate>30102000</AcquirerDate>
    <AcquirerId>1</AcquirerId>
    <CardHolderName>DPS</CardHolderName>
    <DateSettlement>20050811</DateSettlement>
    <TxnType>Purchase</TxnType>
    <CardNumber>411111</CardNumber>
    <DateExpiry>0807</DateExpiry>
    <ProductId></ProductId>
    <AcquirerDate>20050811</AcquirerDate>
    <AcquirerTime>060039</AcquirerTime>
    <AcquirerId>9000</AcquirerId>
    <Acquirer>Test</Acquirer>
    <TestMode>1</TestMode>
    <CardId>2</CardId>
    <CardHolderResponseText>APPROVED</CardHolderResponseText>
    <CardHolderHelpText>The Transaction was approved</CardHolderHelpText>
    <CardHolderResponseDescription>The Transaction was approved</CardHolderResponseDescription>
    <MerchantResponseText>APPROVED</MerchantResponseText>
    <MerchantHelpText>The Transaction was approved</MerchantHelpText>
    <MerchantResponseDescription>The Transaction was approved</MerchantResponseDescription>
    <GroupAccount>9997</GroupAccount>
    <DpsTxnRef>00000004011a2478</DpsTxnRef>
    <AllowRetry>0</AllowRetry>
    <DpsBillingId></DpsBillingId>
    <BillingId></BillingId>
    <TransactionId>011a2478</TransactionId>
  </Transaction>
  <ReCo>00</ReCo>
  <ResponseText>APPROVED</ResponseText>
  <HelpText>The Transaction was approved</HelpText>
  <Success>1</Success>
  <TxnRef>00000004011a2478</TxnRef>
</Txn>
    RESPONSE
  end
end
