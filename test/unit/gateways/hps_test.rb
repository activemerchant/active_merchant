require 'test_helper'

class HpsTest < Test::Unit::TestCase
  def setup
    @gateway = HpsGateway.new({:secret_api_key => '12'})

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_charge_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params['response_code']
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_charge_response)

    response = @gateway.purchase(10.34, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params['response_code']
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(10.34, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    capture_response = @gateway.capture(@amount, 16072899)
    assert_instance_of Response, capture_response
    assert_success capture_response
    assert_equal '00', capture_response.params['response_code']
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    capture_response = @gateway.capture(@amount, 216072899)
    assert_instance_of Response, capture_response
    assert_failure capture_response
    assert_equal 'Transaction rejected because the referenced original transaction is invalid. Subject \'216072899\'.  Original transaction not found.', capture_response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    refund = @gateway.refund(@amount,'transaction_id')
    assert_instance_of Response, refund
    assert_success refund
    assert_equal '00', refund.params['response_code']
    assert_equal '0', refund.params['transaction_header']['GatewayRspCode']
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    refund = @gateway.refund(@amount,'169054') #bad transaction id
    assert_instance_of Response, refund
    assert_failure refund
    assert_equal nil, refund.params['response_code']
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    void = @gateway.void('169054')
    assert_instance_of Response, void
    assert_success void
    assert_equal '00', void.params['response_code']
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    void = @gateway.void('169054')
    assert_instance_of Response, void
    assert_failure void
    assert_equal nil , void.params['response_code']
  end

  private

  def successful_charge_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>95878</LicenseId>
               <SiteId>95881</SiteId>
               <DeviceId>2409000</DeviceId>
               <GatewayTxnId>15927453</GatewayTxnId>
               <GatewayRspCode>0</GatewayRspCode>
               <GatewayRspMsg>Success</GatewayRspMsg>
               <RspDT>2014-03-14T15:40:25.4686202</RspDT>
            </Header>
            <Transaction>
               <CreditSale>
                  <RspCode>00</RspCode>
                  <RspText>APPROVAL</RspText>
                  <AuthCode>36987A</AuthCode>
                  <AVSRsltCode>0</AVSRsltCode>
                  <CVVRsltCode>M</CVVRsltCode>
                  <RefNbr>407313649105</RefNbr>
                  <AVSResultCodeAction>ACCEPT</AVSResultCodeAction>
                  <CVVResultCodeAction>ACCEPT</CVVResultCodeAction>
                  <CardType>Visa</CardType>
                  <AVSRsltText>AVS Not Requested.</AVSRsltText>
                  <CVVRsltText>Match.</CVVRsltText>
               </CreditSale>
            </Transaction>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    RESPONSE
  end

  def failed_charge_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <GatewayTxnId>16099851</GatewayTxnId>
               <GatewayRspCode>0</GatewayRspCode>
               <GatewayRspMsg>Success</GatewayRspMsg>
               <RspDT>2014-03-17T13:01:55.851307</RspDT>
            </Header>
            <Transaction>
               <CreditSale>
                  <RspCode>02</RspCode>
                  <RspText>CALL</RspText>
                  <AuthCode />
                  <AVSRsltCode>0</AVSRsltCode>
                  <RefNbr>407613674802</RefNbr>
                  <CardType>Visa</CardType>
                  <AVSRsltText>AVS Not Requested.</AVSRsltText>
               </CreditSale>
            </Transaction>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    RESPONSE
  end

  def successful_authorize_response
   <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <GatewayTxnId>16072891</GatewayTxnId>
               <GatewayRspCode>0</GatewayRspCode>
               <GatewayRspMsg>Success</GatewayRspMsg>
               <RspDT>2014-03-17T13:05:34.5819712</RspDT>
            </Header>
            <Transaction>
               <CreditAuth>
                  <RspCode>00</RspCode>
                  <RspText>APPROVAL</RspText>
                  <AuthCode>43204A</AuthCode>
                  <AVSRsltCode>0</AVSRsltCode>
                  <CVVRsltCode>M</CVVRsltCode>
                  <RefNbr>407613674895</RefNbr>
                  <AVSResultCodeAction>ACCEPT</AVSResultCodeAction>
                  <CVVResultCodeAction>ACCEPT</CVVResultCodeAction>
                  <CardType>Visa</CardType>
                  <AVSRsltText>AVS Not Requested.</AVSRsltText>
                  <CVVRsltText>Match.</CVVRsltText>
               </CreditAuth>
            </Transaction>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
   RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <GatewayTxnId>16088893</GatewayTxnId>
               <GatewayRspCode>0</GatewayRspCode>
               <GatewayRspMsg>Success</GatewayRspMsg>
               <RspDT>2014-03-17T13:06:45.449707</RspDT>
            </Header>
            <Transaction>
               <CreditAuth>
                  <RspCode>54</RspCode>
                  <RspText>EXPIRED CARD</RspText>
                  <AuthCode />
                  <AVSRsltCode>0</AVSRsltCode>
                  <RefNbr>407613674811</RefNbr>
                  <CardType>Visa</CardType>
                  <AVSRsltText>AVS Not Requested.</AVSRsltText>
               </CreditAuth>
            </Transaction>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <GatewayTxnId>16105018</GatewayTxnId>
               <GatewayRspCode>0</GatewayRspCode>
               <GatewayRspMsg>Success</GatewayRspMsg>
               <RspDT>2014-03-17T13:58:09.476107</RspDT>
            </Header>
            <Transaction>
               <ReportTxnDetail>
                  <GatewayTxnId>16101568</GatewayTxnId>
                  <ClientTxnId>0</ClientTxnId>
                  <SiteId>21232</SiteId>
                  <MerchName>TEST ACCOUNT 1 POS13</MerchName>
                  <DeviceId>1525997</DeviceId>
                  <UserName>7822SK</UserName>
                  <ServiceName>CreditAuth</ServiceName>
                  <GatewayRspCode>0</GatewayRspCode>
                  <GatewayRspMsg>Success</GatewayRspMsg>
                  <ReqUtcDT>2014-03-17T18:58:08.837Z</ReqUtcDT>
                  <ReqDT>2014-03-17T18:58:08.837</ReqDT>
                  <RspUtcDT>2014-03-17T18:58:08.96Z</RspUtcDT>
                  <RspDT>2014-03-17T18:58:08.96</RspDT>
                  <SiteTrace />
                  <OriginalGatewayTxnId>0</OriginalGatewayTxnId>
                  <MerchNbr>777700007822</MerchNbr>
                  <TermOrdinal>1</TermOrdinal>
                  <MerchAddr1>1437 YOUNGSTOWN</MerchAddr1>
                  <MerchAddr2 />
                  <MerchCity>JEFFERSONVILL</MerchCity>
                  <MerchState>IN</MerchState>
                  <MerchZip>47130</MerchZip>
                  <MerchPhone />
                  <TzConversion>UTC</TzConversion>
                  <UniqueDeviceId />
                  <Data>
                     <TxnStatus>A</TxnStatus>
                     <CardType>Visa</CardType>
                     <MaskedCardNbr>401200******0016</MaskedCardNbr>
                     <CardPresent>N</CardPresent>
                     <ReaderPresent>N</ReaderPresent>
                     <CardSwiped>N</CardSwiped>
                     <DebitCreditInd>C</DebitCreditInd>
                     <SaleReturnInd>S</SaleReturnInd>
                     <CVVReq>Y</CVVReq>
                     <CVVRsltCode>M</CVVRsltCode>
                     <Amt>50.00</Amt>
                     <AuthAmt>50.00</AuthAmt>
                     <GratuityAmtInfo>0</GratuityAmtInfo>
                     <CashbackAmtInfo>0</CashbackAmtInfo>
                     <CardHolderLastName>Johnson</CardHolderLastName>
                     <CardHolderFirstName>Bill</CardHolderFirstName>
                     <CardHolderAddr>One Heartland Way</CardHolderAddr>
                     <CardHolderCity>Jeffersonville</CardHolderCity>
                     <CardHolderState>IN</CardHolderState>
                     <CardHolderZip>47130</CardHolderZip>
                     <CardHolderPhone />
                     <CardHolderEmail />
                     <AVSRsltCode>0</AVSRsltCode>
                     <CPCReq>N</CPCReq>
                     <CPCInd />
                     <RspCode>00</RspCode>
                     <RspText>APPROVAL</RspText>
                     <AuthCode>43296A</AuthCode>
                     <ReqACI>Y</ReqACI>
                     <RspACI>N</RspACI>
                     <MktSpecDataId>N</MktSpecDataId>
                     <TxnCode>56</TxnCode>
                     <AcctDataSrc>@</AcctDataSrc>
                     <AuthSrcCode>5</AuthSrcCode>
                     <IssTxnId>407613674523000</IssTxnId>
                     <IssValidationCode />
                     <CardHolderIdCode>N</CardHolderIdCode>
                     <NetworkIdCode />
                     <RefNbr>407613674523</RefNbr>
                     <TxnSeqNbr>512</TxnSeqNbr>
                     <DirectMktInvoiceNbr />
                     <DirectMktShipMonth>0</DirectMktShipMonth>
                     <DirectMktShipDay>0</DirectMktShipDay>
                     <CPCCardHolderPONbr />
                     <CPCTaxType />
                     <CPCTaxAmt>0</CPCTaxAmt>
                     <SettlementAmt>50.00</SettlementAmt>
                     <AllowPartialAuth>N</AllowPartialAuth>
                     <AVSRsltText>AVS Not Requested.</AVSRsltText>
                     <CVVRsltText>Match.</CVVRsltText>
                     <TokenizationMsg />
                     <CryptoTypeIn>Clear</CryptoTypeIn>
                     <CryptoTypeOut>Clear</CryptoTypeOut>
                     <AllowDup>Y</AllowDup>
                  </Data>
               </ReportTxnDetail>
            </Transaction>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    RESPONSE
  end

  def failed_capture_response
    <<-Response
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <GatewayTxnId>16104055</GatewayTxnId>
               <GatewayRspCode>3</GatewayRspCode>
               <GatewayRspMsg>Transaction rejected because the referenced original transaction is invalid. Subject '216072899'.  Original transaction not found.</GatewayRspMsg>
               <RspDT>2014-03-17T14:20:32.355307</RspDT>
            </Header>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    Response
  end

  def successful_refund_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <SiteTrace />
               <GatewayTxnId>16092738</GatewayTxnId>
               <GatewayRspCode>0</GatewayRspCode>
               <GatewayRspMsg>Success</GatewayRspMsg>
               <RspDT>2014-03-17T13:31:42.0231712</RspDT>
            </Header>
            <Transaction>
               <CreditReturn />
            </Transaction>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <SiteTrace />
               <GatewayTxnId>16092766</GatewayTxnId>
               <GatewayRspCode>3</GatewayRspCode>
               <GatewayRspMsg>Transaction rejected because the referenced original transaction is invalid.</GatewayRspMsg>
               <RspDT>2014-03-17T13:48:55.3203712</RspDT>
            </Header>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <GatewayTxnId>16092767</GatewayTxnId>
               <GatewayRspCode>0</GatewayRspCode>
               <GatewayRspMsg>Success</GatewayRspMsg>
               <RspDT>2014-03-17T13:53:43.6863712</RspDT>
            </Header>
            <Transaction>
               <CreditVoid />
            </Transaction>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soap:Body>
      <PosResponse xmlns="http://Hps.Exchange.PosGateway" rootUrl="https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway">
         <Ver1.0>
            <Header>
               <LicenseId>21229</LicenseId>
               <SiteId>21232</SiteId>
               <DeviceId>1525997</DeviceId>
               <GatewayTxnId>16103858</GatewayTxnId>
               <GatewayRspCode>3</GatewayRspCode>
               <GatewayRspMsg>Transaction rejected because the referenced original transaction is invalid. Subject '169054'.  Original transaction not found.</GatewayRspMsg>
               <RspDT>2014-03-17T13:55:56.8947712</RspDT>
            </Header>
         </Ver1.0>
      </PosResponse>
   </soap:Body>
</soap:Envelope>
    RESPONSE
  end
end
