require "test_helper"

class CenposTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CenposGateway.new(
      :merchant_id => "merchant_id",
      :password => "password",
      :user_id => "user_id"
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "1609995363|4242|1.00", response.authorization
    assert response.test?
  end

  def test_successful_purchase_cvv_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    cvv_result = response.cvv_result
    assert_equal "M", cvv_result["code"]
  end

  def test_successful_purchase_avs_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    avs_result = response.avs_result
    assert_equal "D", avs_result["code"]
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Decline transaction", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert response.test?
  end

  def test_missing_cvv_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    cvv_result = response.cvv_result
    assert_equal nil, cvv_result["code"]
  end

  def test_failed_purchase_avs_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    avs_result = response.avs_result
    assert_equal nil, avs_result["code"]
  end

  def test_unmatched_cvv_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(cvv_no_match_response)

    cvv_result = response.cvv_result
    assert_equal "N", cvv_result["code"]
  end

  def test_avs_result_unmatched_zip
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(avs_zip_no_match_response)

    assert_equal "B", response.avs_result["code"]
  end

  def test_avs_result_unmatched_address
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(avs_billing_no_match_response)

    assert_equal "P", response.avs_result["code"]
  end

  def test_avs_result_unmatched_address_and_zip
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(avs_billing_and_zip_no_match_response)

    assert_equal "C", response.avs_result["code"]
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "1760035844|4242|1.00", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/1760035844/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Decline transaction", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, "")
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "1760035844|4242|1.00", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/1760035844/, data)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void("1758584451|4242|1.00")
    end.check_request do |endpoint, data, headers|
      assert_match(/1758584451/, data)
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "1609995363|4242|1.00", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/1609995363/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(successful_credit_response)

    assert_success response

    assert_equal "1609996211|4242|1.00", response.authorization
    assert response.test?
  end

  def test_failed_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(failed_credit_response)

    assert_failure response
    assert_equal "Invalid card number", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
    assert response.test?
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "Decline transaction", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal "Unable to read error message", response.message
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>2.32</a:Amount><a:AutorizationNumber>TAS977</a:AutorizationNumber><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>2.32</a:OriginalAmount><a:ParameterValidationResultList><a:ParameterValidationResult><a:Name>CVV</a:Name><a:Result> Present;Match (M)</a:Result></a:ParameterValidationResult><a:ParameterValidationResult><a:Name>Billing Address</a:Name><a:Result> Present;Match (N)</a:Result></a:ParameterValidationResult><a:ParameterValidationResult><a:Name>Zip Code</a:Name><a:Result> Present;Match (N)</a:Result></a:ParameterValidationResult></a:ParameterValidationResultList><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1609995363</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber>513519510699</a:TraceNumber><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def failed_purchase_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Decline transaction</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">1</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>30.85</a:Amount><a:AutorizationNumber>N7</a:AutorizationNumber><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>30.85</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1609995417</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber>513519510836</a:TraceNumber><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def successful_authorize_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>16.56</a:Amount><a:AutorizationNumber>TAS788</a:AutorizationNumber><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>16.56</a:OriginalAmount><a:ParameterValidationResultList><a:ParameterValidationResult><a:Name>CVV</a:Name><a:Result> Present;Match (M)</a:Result></a:ParameterValidationResult><a:ParameterValidationResult><a:Name>Billing Address</a:Name><a:Result> Present;Match (N)</a:Result></a:ParameterValidationResult><a:ParameterValidationResult><a:Name>Zip Code</a:Name><a:Result> Present;Match (N)</a:Result></a:ParameterValidationResult></a:ParameterValidationResultList><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1760035844</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber>513520500594</a:TraceNumber><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def failed_authorize_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Decline transaction</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">1</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>73.51</a:Amount><a:AutorizationNumber>N7</a:AutorizationNumber><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>73.51</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1609995953</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber>513520500786</a:TraceNumber><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def successful_capture_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>81.47</a:Amount><a:AutorizationNumber>TAS821</a:AutorizationNumber><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>81.47</a:OriginalAmount><a:ParameterValidationResultList><a:ParameterValidationResult><a:Name>Billing Address</a:Name><a:Result> Present;Match (N)</a:Result></a:ParameterValidationResult><a:ParameterValidationResult><a:Name>Zip Code</a:Name><a:Result> Present;Match (N)</a:Result></a:ParameterValidationResult><a:ParameterValidationResult><a:Name>CVV</a:Name><a:Result> Present;Match (M)</a:Result></a:ParameterValidationResult></a:ParameterValidationResultList><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1609995899</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber i:nil="true"/><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def failed_capture_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Duplicated transaction</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">2</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>65.51</a:Amount><a:AutorizationNumber i:nil="true"/><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>65.51</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1609996127</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber i:nil="true"/><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def successful_void_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>3.98</a:Amount><a:AutorizationNumber>TAS048</a:AutorizationNumber><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>3.98</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1760036131</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber>513520512917</a:TraceNumber><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def failed_void_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Original Transaction not found</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">7</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>88.01</a:Amount><a:AutorizationNumber i:nil="true"/><a:CardType>Credit</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>88.01</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1760036213</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber i:nil="true"/><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def successful_refund_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>95.10</a:Amount><a:AutorizationNumber i:nil="true"/><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>95.10</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1760036098</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber i:nil="true"/><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def failed_refund_response
    %(
      <s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><s:Fault><faultcode xmlns:a=\"http://schemas.microsoft.com/net/2005/12/windowscommunicationfoundation/dispatcher\">a:DeserializationFailed</faultcode><faultstring xml:lang=\"en-US\">The formatter threw an exception while trying to deserialize the message: There was an error while trying to deserialize parameter http://tempuri.org/:request. The InnerException message was 'There was an error deserializing the object of type Acriter.ABI.CenPOS.Client.VirtualTerminal.v6.Common.Requests.ProcessCardRequest. The value '' cannot be parsed as the type 'decimal'.'.  Please see InnerException for more details.</faultstring><detail><ExceptionDetail xmlns=\"http://schemas.datacontract.org/2004/07/System.ServiceModel\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\"><HelpLink i:nil=\"true\"/><InnerException><HelpLink i:nil=\"true\"/><InnerException><HelpLink i:nil=\"true\"/><InnerException><HelpLink i:nil=\"true\"/><InnerException i:nil=\"true\"/><Message>Input string was not in a correct format.</Message><StackTrace>   at System.Number.StringToNumber(String str, NumberStyles options, NumberBuffer&amp; number, NumberFormatInfo info, Boolean parseDecimal)&#xD;\n   at System.Number.ParseDecimal(String value, NumberStyles options, NumberFormatInfo numfmt)&#xD;\n   at System.Xml.XmlConvert.ToDecimal(String s)&#xD;\n   at System.Xml.XmlConverter.ToDecimal(String value)</StackTrace><Type>System.FormatException</Type></InnerException><Message>The value '' cannot be parsed as the type 'decimal'.</Message><StackTrace>   at System.Xml.XmlConverter.ToDecimal(String value)&#xD;\n   at System.Xml.XmlDictionaryReader.ReadElementContentAsDecimal()&#xD;\n   at System.Runtime.Serialization.XmlReaderDelegator.ReadElementContentAsDecimal()&#xD;\n   at ReadProcessCardRequestFromXml(XmlReaderDelegator , XmlObjectSerializerReadContext , XmlDictionaryString[] , XmlDictionaryString[] )&#xD;\n   at System.Runtime.Serialization.ClassDataContract.ReadXmlValue(XmlReaderDelegator xmlReader, XmlObjectSerializerReadContext context)&#xD;
    )
  end


  def successful_credit_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>91.13</a:Amount><a:AutorizationNumber i:nil="true"/><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>91.13</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1609996211</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber i:nil="true"/><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def failed_credit_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><ProcessCreditCardResponse xmlns="http://tempuri.org/"><ProcessCreditCardResult i:type="a:ProcessRecurringSaleResponse" xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Invalid card number</Message><Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">211</Result><a:AccountBalanceAmount i:nil="true"/><a:Amount>44.65</a:Amount><a:AutorizationNumber i:nil="true"/><a:CardType>MASTERCARD</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil="true"/><a:OriginalAmount>44.65</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil="true"/><a:ReferenceNumber>1760036040</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber i:nil="true"/><a:ProtectedCardNumber i:nil="true"/><a:RecurringSaleTokenId i:nil="true"/></ProcessCreditCardResult></ProcessCreditCardResponse></s:Body></s:Envelope>
    )
  end

  def cvv_no_match_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"> <s:Body> <ProcessCreditCardResponse xmlns="http://tempuri.org/"> <ProcessCreditCardResult xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" i:type="a:ProcessRecurringSaleResponse"> <Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message> <Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result> <a:AccountBalanceAmount i:nil="true" /> <a:Amount>96.19</a:Amount> <a:AutorizationNumber>TAS922</a:AutorizationNumber> <a:CardType>VISA</a:CardType> <a:Discount>0</a:Discount> <a:DiscountAmount>0</a:DiscountAmount> <a:EmvData i:nil="true" /> <a:OriginalAmount>96.19</a:OriginalAmount> <a:ParameterValidationResultList> <a:ParameterValidationResult> <a:Name>CVV</a:Name> <a:Result>Not Present;No Match (M)</a:Result> </a:ParameterValidationResult> <a:ParameterValidationResult> <a:Name>Billing Address</a:Name> <a:Result>Present;Match (N)</a:Result> </a:ParameterValidationResult> <a:ParameterValidationResult> <a:Name>Zip Code</a:Name> <a:Result>Present;Match (N)</a:Result> </a:ParameterValidationResult> </a:ParameterValidationResultList> <a:PartiallyAuthorizedAmount i:nil="true" /> <a:ReferenceNumber>1761450083</a:ReferenceNumber> <a:Surcharge>0</a:Surcharge> <a:SurchargeAmount>0</a:SurchargeAmount> <a:TraceNumber>520417500008</a:TraceNumber> <a:ProtectedCardNumber i:nil="true" /> <a:RecurringSaleTokenId i:nil="true" /> </ProcessCreditCardResult> </ProcessCreditCardResponse> </s:Body> </s:Envelope>
    )
  end

  def avs_billing_no_match_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"> <s:Body> <ProcessCreditCardResponse xmlns="http://tempuri.org/"> <ProcessCreditCardResult xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" i:type="a:ProcessRecurringSaleResponse"> <Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message> <Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result> <a:AccountBalanceAmount i:nil="true" /> <a:Amount>96.19</a:Amount> <a:AutorizationNumber>TAS922</a:AutorizationNumber> <a:CardType>VISA</a:CardType> <a:Discount>0</a:Discount> <a:DiscountAmount>0</a:DiscountAmount> <a:EmvData i:nil="true" /> <a:OriginalAmount>96.19</a:OriginalAmount> <a:ParameterValidationResultList> <a:ParameterValidationResult> <a:Name>CVV</a:Name> <a:Result>Present;Match (M)</a:Result> </a:ParameterValidationResult> <a:ParameterValidationResult> <a:Name>Billing Address</a:Name> <a:Result>Not Present;No Match (N)</a:Result> </a:ParameterValidationResult> <a:ParameterValidationResult> <a:Name>Zip Code</a:Name> <a:Result>Present;Match (N)</a:Result> </a:ParameterValidationResult> </a:ParameterValidationResultList> <a:PartiallyAuthorizedAmount i:nil="true" /> <a:ReferenceNumber>1761450083</a:ReferenceNumber> <a:Surcharge>0</a:Surcharge> <a:SurchargeAmount>0</a:SurchargeAmount> <a:TraceNumber>520417500008</a:TraceNumber> <a:ProtectedCardNumber i:nil="true" /> <a:RecurringSaleTokenId i:nil="true" /> </ProcessCreditCardResult> </ProcessCreditCardResponse> </s:Body> </s:Envelope>
    )
  end

  def avs_zip_no_match_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"> <s:Body> <ProcessCreditCardResponse xmlns="http://tempuri.org/"> <ProcessCreditCardResult xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" i:type="a:ProcessRecurringSaleResponse"> <Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message> <Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result> <a:AccountBalanceAmount i:nil="true" /> <a:Amount>96.19</a:Amount> <a:AutorizationNumber>TAS922</a:AutorizationNumber> <a:CardType>VISA</a:CardType> <a:Discount>0</a:Discount> <a:DiscountAmount>0</a:DiscountAmount> <a:EmvData i:nil="true" /> <a:OriginalAmount>96.19</a:OriginalAmount> <a:ParameterValidationResultList> <a:ParameterValidationResult> <a:Name>CVV</a:Name> <a:Result>Present;Match (M)</a:Result> </a:ParameterValidationResult> <a:ParameterValidationResult> <a:Name>Billing Address</a:Name> <a:Result>Present;Match (N)</a:Result> </a:ParameterValidationResult> <a:ParameterValidationResult> <a:Name>Zip Code</a:Name> <a:Result>Not Present;No Match (N)</a:Result> </a:ParameterValidationResult> </a:ParameterValidationResultList> <a:PartiallyAuthorizedAmount i:nil="true" /> <a:ReferenceNumber>1761450083</a:ReferenceNumber> <a:Surcharge>0</a:Surcharge> <a:SurchargeAmount>0</a:SurchargeAmount> <a:TraceNumber>520417500008</a:TraceNumber> <a:ProtectedCardNumber i:nil="true" /> <a:RecurringSaleTokenId i:nil="true" /> </ProcessCreditCardResult> </ProcessCreditCardResponse> </s:Body> </s:Envelope>
    )
  end

  def avs_billing_and_zip_no_match_response
    %(
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"> <s:Body> <ProcessCreditCardResponse xmlns="http://tempuri.org/"> <ProcessCreditCardResult xmlns:a="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" i:type="a:ProcessRecurringSaleResponse"> <Message xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">Approved</Message> <Result xmlns="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common">0</Result> <a:AccountBalanceAmount i:nil="true" /> <a:Amount>96.19</a:Amount> <a:AutorizationNumber>TAS922</a:AutorizationNumber> <a:CardType>VISA</a:CardType> <a:Discount>0</a:Discount> <a:DiscountAmount>0</a:DiscountAmount> <a:EmvData i:nil="true" /> <a:OriginalAmount>96.19</a:OriginalAmount> <a:ParameterValidationResultList> <a:ParameterValidationResult> <a:Name>CVV</a:Name> <a:Result>Present;Match (M)</a:Result> </a:ParameterValidationResult> <a:ParameterValidationResult> <a:Name>Billing Address</a:Name> <a:Result>Not Present;No Match (N)</a:Result> </a:ParameterValidationResult> <a:ParameterValidationResult> <a:Name>Zip Code</a:Name> <a:Result>Not Present;No Match (N)</a:Result> </a:ParameterValidationResult> </a:ParameterValidationResultList> <a:PartiallyAuthorizedAmount i:nil="true" /> <a:ReferenceNumber>1761450083</a:ReferenceNumber> <a:Surcharge>0</a:Surcharge> <a:SurchargeAmount>0</a:SurchargeAmount> <a:TraceNumber>520417500008</a:TraceNumber> <a:ProtectedCardNumber i:nil="true" /> <a:RecurringSaleTokenId i:nil="true" /> </ProcessCreditCardResult> </ProcessCreditCardResponse> </s:Body> </s:Envelope>
    )
  end

  def empty_purchase_response
    %(
    )
  end

  def transcript
    %(
      <- "POST /6/transact.asmx HTTP/1.1\r\nContent-Type: text/xml;charset=UTF-8\r\nAccept-Encoding: gzip,deflate\r\nSoapaction: http://tempuri.org/Transactional/ProcessCard\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ww3.cenpos.net\r\nContent-Length: 1272\r\n\r\n"
      <- "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:tem=\"http://tempuri.org/\" xmlns:acr=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common\" xmlns:acr1=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n<soapenv:Header/>\n   <soapenv:Body>\n      <tem:ProcessCard>\n         <tem:request>\n          <acr:MerchantId>12722385</acr:MerchantId>\n<acr:Password>101010101010</acr:Password>\n<acr:UserId>Webpay</acr:UserId>\n<acr1:Amount>25</acr1:Amount>\n<acr1:CardExpirationDate>0218</acr1:CardExpirationDate>\n<acr1:CardLastFourDigits>1111</acr1:CardLastFourDigits>\n<acr1:CardNumber>4111111111111111</acr1:CardNumber>\n<acr1:CardVerificationNumber>999</acr1:CardVerificationNumber>\n<acr1:CustomerBillingAddress>1234 My Street</acr1:CustomerBillingAddress>\n<acr1:CustomerCode>1231</acr1:CustomerCode>\n<acr1:CustomerEmailAddress/>\n<acr1:CustomerZipCode>K1C2N6</acr1:CustomerZipCode>\n<acr1:InvoiceNumber>612944</acr1:InvoiceNumber>\n<acr1:NameOnCard>Longbob Longsen</acr1:NameOnCard>\n<acr1:TransactionType>Sale</acr1:TransactionType>\n\n         </tem:request>\n      </tem:ProcessCard>\n   </soapenv:Body>\n</soapenv:Envelope>\n"
      -> "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><ProcessCardResponse xmlns=\"http://tempuri.org/\"><ProcessCardResult xmlns:a=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\"><Message xmlns=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common\">Duplicated transaction</Message><Result xmlns=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common\">2</Result><a:AccountBalanceAmount i:nil=\"true\"/><a:Amount>25</a:Amount><a:AutorizationNumber i:nil=\"true\"/><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil=\"true\"/><a:OriginalAmount>25</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil=\"true\"/><a:ReferenceNumber>1608482770</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber i:nil=\"true\"/></ProcessCardResult></ProcessCardResponse></s:Body></s:Envelope>"
    )
  end

  def scrubbed_transcript
    %(
      <- "POST /6/transact.asmx HTTP/1.1\r\nContent-Type: text/xml;charset=UTF-8\r\nAccept-Encoding: gzip,deflate\r\nSoapaction: http://tempuri.org/Transactional/ProcessCard\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ww3.cenpos.net\r\nContent-Length: 1272\r\n\r\n"
      <- "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:tem=\"http://tempuri.org/\" xmlns:acr=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common\" xmlns:acr1=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n<soapenv:Header/>\n   <soapenv:Body>\n      <tem:ProcessCard>\n         <tem:request>\n          <acr:MerchantId>12722385</acr:MerchantId>\n<acr:Password>[FILTERED]</acr:Password>\n<acr:UserId>Webpay</acr:UserId>\n<acr1:Amount>25</acr1:Amount>\n<acr1:CardExpirationDate>0218</acr1:CardExpirationDate>\n<acr1:CardLastFourDigits>1111</acr1:CardLastFourDigits>\n<acr1:CardNumber>[FILTERED]</acr1:CardNumber>\n<acr1:CardVerificationNumber>[FILTERED]</acr1:CardVerificationNumber>\n<acr1:CustomerBillingAddress>1234 My Street</acr1:CustomerBillingAddress>\n<acr1:CustomerCode>1231</acr1:CustomerCode>\n<acr1:CustomerEmailAddress/>\n<acr1:CustomerZipCode>K1C2N6</acr1:CustomerZipCode>\n<acr1:InvoiceNumber>612944</acr1:InvoiceNumber>\n<acr1:NameOnCard>Longbob Longsen</acr1:NameOnCard>\n<acr1:TransactionType>Sale</acr1:TransactionType>\n\n         </tem:request>\n      </tem:ProcessCard>\n   </soapenv:Body>\n</soapenv:Envelope>\n"
      -> "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><ProcessCardResponse xmlns=\"http://tempuri.org/\"><ProcessCardResult xmlns:a=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\"><Message xmlns=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common\">Duplicated transaction</Message><Result xmlns=\"http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common\">2</Result><a:AccountBalanceAmount i:nil=\"true\"/><a:Amount>25</a:Amount><a:AutorizationNumber i:nil=\"true\"/><a:CardType>VISA</a:CardType><a:Discount>0</a:Discount><a:DiscountAmount>0</a:DiscountAmount><a:EmvData i:nil=\"true\"/><a:OriginalAmount>25</a:OriginalAmount><a:ParameterValidationResultList/><a:PartiallyAuthorizedAmount i:nil=\"true\"/><a:ReferenceNumber>1608482770</a:ReferenceNumber><a:Surcharge>0</a:Surcharge><a:SurchargeAmount>0</a:SurchargeAmount><a:TraceNumber i:nil=\"true\"/></ProcessCardResult></ProcessCardResponse></s:Body></s:Envelope>"
    )
  end
end
