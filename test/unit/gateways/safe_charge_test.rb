require 'test_helper'

class SafeChargeTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SafeChargeGateway.new(client_login_id: 'login', client_password: 'password')
    @credit_card = credit_card
    @three_ds_enrolled_card = credit_card('4012 0010 3749 0014')
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
    @merchant_options = @options.merge(
      merchant_descriptor: 'Test Descriptor',
      merchant_phone_number: '(555)555-5555',
      merchant_name: 'Test Merchant'
    )
    @three_ds_options = @options.merge(three_d_secure: true)
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '111951|101508189567|ZQBpAFAASABGAHAAVgBPAFUAMABiADMAewBtAGsAd' \
                 'AAvAFIAQQBrAGoAYwBxACoAXABHAEEAOgA3ACsAMgA4AD0AOABDAG4AbQAzAF' \
                 'UAbQBYAFIAMwA=|%02d|%d|1.00|USD' % [@credit_card.month, @credit_card.year.to_s[-2..-1]], response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_merchant_options
    purchase = stub_comms do
      @gateway.purchase(@amount, @credit_card, @merchant_options)
    end.check_request do |endpoint, data, headers|
      assert_match(/sg_Descriptor/, data)
      assert_match(/sg_MerchantPhoneNumber/, data)
      assert_match(/sg_MerchantName/, data)
    end.respond_with(successful_purchase_response)

    assert_success purchase
    assert_equal '111951|101508189567|ZQBpAFAASABGAHAAVgBPAFUAMABiADMAewBtAGsAd' \
                 'AAvAFIAQQBrAGoAYwBxACoAXABHAEEAOgA3ACsAMgA4AD0AOABDAG4AbQAzAF' \
                 'UAbQBYAFIAMwA=|%02d|%d|1.00|USD' % [@credit_card.month, @credit_card.year.to_s[-2..-1]], purchase.authorization
    assert purchase.test?
  end

  def test_successful_purchase_with_truthy_stored_credential_mode
    purchase = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential_mode: true))
    end.check_request do |endpoint, data, headers|
      assert_match(/sg_StoredCredentialMode=1/, data)
    end.respond_with(successful_purchase_response)

    assert_success purchase
    assert_equal '111951|101508189567|ZQBpAFAASABGAHAAVgBPAFUAMABiADMAewBtAGsAd' \
                 'AAvAFIAQQBrAGoAYwBxACoAXABHAEEAOgA3ACsAMgA4AD0AOABDAG4AbQAzAF' \
                 'UAbQBYAFIAMwA=|%02d|%d|1.00|USD' % [@credit_card.month, @credit_card.year.to_s[-2..-1]], purchase.authorization
    assert purchase.test?
  end

  def test_successful_purchase_with_falsey_stored_credential_mode
    purchase = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential_mode: false))
    end.check_request do |endpoint, data, headers|
      assert_match(/sg_StoredCredentialMode=0/, data)
    end.respond_with(successful_purchase_response)

    assert_success purchase
    assert_equal '111951|101508189567|ZQBpAFAASABGAHAAVgBPAFUAMABiADMAewBtAGsAd' \
                 'AAvAFIAQQBrAGoAYwBxACoAXABHAEEAOgA3ACsAMgA4AD0AOABDAG4AbQAzAF' \
                 'UAbQBYAFIAMwA=|%02d|%d|1.00|USD' % [@credit_card.month, @credit_card.year.to_s[-2..-1]], purchase.authorization
    assert purchase.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '0', response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '111534|101508189855|MQBVAG4ASABkAEgAagB3AEsAbgAtACoAWgAzAFwAW' \
                 'wBNAF8ATQBUAD0AegBQAGwAQAAtAD0AXAB5AFkALwBtAFAALABaAHoAOgBFAE' \
                 'wAUAA1AFUAMwA=|%02d|%d|1.00|USD' % [@credit_card.month, @credit_card.year.to_s[-2..-1]], response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '0', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'auth|transaction_id|token|month|year|amount|currency')
    assert_success response

    assert_equal '111301|101508190200|RwA1AGQAMgAwAEkAWABKADkAcABjAHYAQQA4AC8AZ' \
                 'AAlAHMAfABoADEALAA8ADQAewB8ADsAewBiADsANQBoACwAeAA/AGQAXQAjAF' \
                 'EAYgBVAHIAMwA=|month|year|1.00|currency', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_equal '1163', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'authorization', @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_equal '1163', response.error_code
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('auth|transaction_id|token|month|year|amount|currency')
    assert_success response

    assert_equal '111171|101508208625|ZQBpAFAAZgBuAHEATgBUAHcASAAwADUAcwBHAHQAV' \
                 'QBLAHAAbgB6AGwAJAA1AEMAfAB2AGYASwBrAHEAeQBOAEwAOwBZAGIAewB4AG' \
                 'wAYwBUAE0AMwA=|month|year|0.00|currency', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
    assert_equal 'Invalid Amount', response.message
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal '111534|101508189855|MQBVAG4ASABkAEgAagB3AEsAbgAtACoAWgAzAFwAW' \
                 'wBNAF8ATQBUAD0AegBQAGwAQAAtAD0AXAB5AFkALwBtAFAALABaAHoAOgBFAE' \
                 'wAUAA1AFUAMwA=|%02d|%d|1.00|USD' % [@credit_card.month, @credit_card.year.to_s[-2..-1]], response.authorization
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal '0', response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_3ds_response
    purchase = stub_comms do
      @gateway.purchase(@amount, @three_ds_enrolled_card, @three_ds_options)
    end.check_request do |endpoint, data, headers|
      assert_match(/Sale3D/, data)
      assert_match(/sg_APIType/, data)
    end.respond_with(successful_3ds_purchase_response)

    assert_success purchase
    assert_equal 'MDAwMDAwMDAwMDE1MTAxMDgzMTA=', purchase.params['xid']
    assert_equal 'eJxVUdtuwjAM/ZWK95GYgijIjVTWaUNTGdqQ4DUKFq2gF9J0A75+SVcuixTF59g+sY5xlWqi+ItUo0lgQnUtd+Rl27BXyScYAQce+MB7ApfRJx0FfpOus7IQ0Of9AbIrtK1apbIwAqU6zuYLMQSY8ABZBzEnPY8FfzhjGCH7o7GQOYlIq9J4K6qNd5VD1mZQlU1h9FkEQ47sCrDRB5EaU00ZO5RKHtKyth2ORXYfaNm4qLYqp2wrkjj6ud8XSFbRKYl3F/uGyFwFbqUhMeAwBvC5B6Opz6c+IGt5lLn73hlgR+kAVu6PqMu4xCOB1l1NhTqLydg6ckNIp6osyFZYJ28xsvvAz2/OT2WsRa+bdf2+X6cXtd9oHxZNPks+ojB0DrcFTi2zrkDAJ62cA8icBOuWx7oF2+jf4n8B', purchase.params['pareq']
    assert_equal 'https://pit.3dsecure.net/VbVTestSuiteService/pit1/acsService/paReq?summary=MjRlZGYwY2EtZTk5Zi00NDJjLTljOTAtNWUxZmRhMjEwODg3', purchase.params['acsurl']
  end

  private

  def pre_scrubbed
    %q(
opening connection to process.sandbox.safecharge.com:443...
opened
starting SSL for process.sandbox.safecharge.com:443...
SSL established
<- "POST /service.asmx/Process HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: process.sandbox.safecharge.com\r\nContent-Length: 249\r\n\r\n"
<- "sg_TransType=Sale&sg_Currency=USD&sg_Amount=1.00&sg_ClientLoginID=SpreedlyTestTRX&sg_ClientPassword=5Jp5xKmgqY&sg_ResponseFormat=4&sg_Version=4.1.0&sg_NameOnCard=Longbob+Longsen&sg_CardNumber=4000100011112224&sg_ExpMonth=09&sg_ExpYear=18&sg_CVV2=123"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Wed, 29 Mar 2017 18:28:17 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 727\r\n"
-> "Set-Cookie: visid_incap_847807=oQqFyASiS0y3sQoZ55M7TsH821gAAAAAQUIPAAAAAAA/rRn9PSjQ7LsSqhb2S1AZ; expires=Thu, 29 Mar 2018 13:12:58 GMT; path=/; Domain=.sandbox.safecharge.com\r\n"
-> "Set-Cookie: incap_ses_225_847807=H1/pC1tNgzhTmiAXOl0fA8H821gAAAAAFE9hBYJtG83f0yrtcxrGsg==; path=/; Domain=.sandbox.safecharge.com\r\n"
-> "X-Iinfo: 9-132035054-132035081 NNNN CT(207 413 0) RT(1490812095742 212) q(0 0 6 -1) r(14 14) U5\r\n"
-> "X-CDN: Incapsula\r\n"
-> "\r\n"
reading 727 bytes...
    )
  end

  def post_scrubbed
    %q(
opening connection to process.sandbox.safecharge.com:443...
opened
starting SSL for process.sandbox.safecharge.com:443...
SSL established
<- "POST /service.asmx/Process HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: process.sandbox.safecharge.com\r\nContent-Length: 249\r\n\r\n"
<- "sg_TransType=Sale&sg_Currency=USD&sg_Amount=1.00&sg_ClientLoginID=SpreedlyTestTRX&sg_ClientPassword=[FILTERED]&sg_ResponseFormat=4&sg_Version=4.1.0&sg_NameOnCard=Longbob+Longsen&sg_CardNumber=[FILTERED]&sg_ExpMonth=09&sg_ExpYear=18&sg_CVV2=[FILTERED]"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Wed, 29 Mar 2017 18:28:17 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 727\r\n"
-> "Set-Cookie: visid_incap_847807=oQqFyASiS0y3sQoZ55M7TsH821gAAAAAQUIPAAAAAAA/rRn9PSjQ7LsSqhb2S1AZ; expires=Thu, 29 Mar 2018 13:12:58 GMT; path=/; Domain=.sandbox.safecharge.com\r\n"
-> "Set-Cookie: incap_ses_225_847807=H1/pC1tNgzhTmiAXOl0fA8H821gAAAAAFE9hBYJtG83f0yrtcxrGsg==; path=/; Domain=.sandbox.safecharge.com\r\n"
-> "X-Iinfo: 9-132035054-132035081 NNNN CT(207 413 0) RT(1490812095742 212) q(0 0 6 -1) r(14 14) U5\r\n"
-> "X-CDN: Incapsula\r\n"
-> "\r\n"
reading 727 bytes...
    )
  end

  def successful_purchase_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508189567</TransactionID><Status>APPROVED</Status><AuthCode>111951</AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0"></Reason></ReasonCodes><ErrCode>0</ErrCode><ExErrCode>0</ExErrCode><Token>ZQBpAFAASABGAHAAVgBPAFUAMABiADMAewBtAGsAdAAvAFIAQQBrAGoAYwBxACoAXABHAEEAOgA3ACsAMgA4AD0AOABDAG4AbQAzAFUAbQBYAFIAMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName>University First Federal Credit Union</IssuerBankName><IssuerBankCountry>us</IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>SuiMHP60FrDKfyaJs47hqqrR/JU=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType>Credit</CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse><FinalDecision>Accept</FinalDecision><Recommendations /><Rule /></FraudResponse></Response>
    )
  end

  def failed_purchase_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508189637</TransactionID><Status>DECLINED</Status><AuthCode></AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0">Decline</Reason></ReasonCodes><ErrCode>-1</ErrCode><ExErrCode>0</ExErrCode><Token>bwBVAEYAUgBuAGcAbABSAFYASgB5AEAAMgA/ACsAUQBIAC4AbgB1AHgAdABAAE8ARgBRAGoAbwApACQAWwBKAFwATwAxAEcAMwBZAG4AdwBmACgAMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName></IssuerBankName><IssuerBankCountry></IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>GyueFkuQqW+UL38d57fuA5/RqfQ=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType></CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse><FinalDecision>Accept</FinalDecision><Recommendations /><Rule /></FraudResponse></Response>
    )
  end

  def successful_authorize_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508189855</TransactionID><Status>APPROVED</Status><AuthCode>111534</AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0"></Reason></ReasonCodes><ErrCode>0</ErrCode><ExErrCode>0</ExErrCode><Token>MQBVAG4ASABkAEgAagB3AEsAbgAtACoAWgAzAFwAWwBNAF8ATQBUAD0AegBQAGwAQAAtAD0AXAB5AFkALwBtAFAALABaAHoAOgBFAEwAUAA1AFUAMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName>University First Federal Credit Union</IssuerBankName><IssuerBankCountry>us</IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>SuiMHP60FrDKfyaJs47hqqrR/JU=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType>Credit</CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse><FinalDecision>Accept</FinalDecision><Recommendations /><Rule /></FraudResponse></Response>
    )
  end

  def failed_authorize_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508190604</TransactionID><Status>DECLINED</Status><AuthCode></AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0">Decline</Reason></ReasonCodes><ErrCode>-1</ErrCode><ExErrCode>0</ExErrCode><Token>MQBLAG4AMgAwADMAOABmAFYANABbAGYAcwA+ACMAVgBXAD0AUQBQAEoANQBrAHQAWABsAFEAeABQAF8ARwA6ACsALgBHADUALwBTAEAARwBIACgAMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName></IssuerBankName><IssuerBankCountry></IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>GyueFkuQqW+UL38d57fuA5/RqfQ=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType></CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse><FinalDecision>Accept</FinalDecision><Recommendations /><Rule /></FraudResponse></Response>
    )
  end

  def successful_capture_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508190200</TransactionID><Status>APPROVED</Status><AuthCode>111301</AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0"></Reason></ReasonCodes><ErrCode>0</ErrCode><ExErrCode>0</ExErrCode><Token>RwA1AGQAMgAwAEkAWABKADkAcABjAHYAQQA4AC8AZAAlAHMAfABoADEALAA8ADQAewB8ADsAewBiADsANQBoACwAeAA/AGQAXQAjAFEAYgBVAHIAMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName>University First Federal Credit Union</IssuerBankName><IssuerBankCountry>us</IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>SuiMHP60FrDKfyaJs47hqqrR/JU=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType>Credit</CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse /></Response>
    )
  end

  def failed_capture_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508190627</TransactionID><Status>ERROR</Status><AuthCode></AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><Reason>Transaction must contain a Card/Token/Account</Reason><ErrCode>-1100</ErrCode><ExErrCode>1163</ExErrCode><CustomData></CustomData><AcquirerID>-1</AcquirerID><IssuerBankName></IssuerBankName><IssuerBankCountry></IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>2jmj7l5rSw0yVb/vlWAYkK/YBwk=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType></CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo></Response>
    )
  end

  def successful_refund_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508440432</TransactionID><Status>APPROVED</Status><AuthCode>111207</AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0"></Reason></ReasonCodes><ErrCode>0</ErrCode><ExErrCode>0</ExErrCode><Token>MQBVAG4AUgAwAFcAaABxAGoASABdAE4ALABvAGYANAAmAE8AcQA/AEgAawAkAHYASQBKAFMAegBiACoAcQBBAC8AVABlAD4AKwBkAC0AKwA8ACcAMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName></IssuerBankName><IssuerBankCountry></IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>SuiMHP60FrDKfyaJs47hqqrR/JU=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType></CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse /></Response>
    )
  end

  def failed_refund_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508208595</TransactionID><Status>ERROR</Status><AuthCode></AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><Reason>Transaction must contain a Card/Token/Account</Reason><ErrCode>-1100</ErrCode><ExErrCode>1163</ExErrCode><CustomData></CustomData><AcquirerID>-1</AcquirerID><IssuerBankName></IssuerBankName><IssuerBankCountry></IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>2jmj7l5rSw0yVb/vlWAYkK/YBwk=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType></CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo></Response>
    )
  end

  def successful_credit_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508440421</TransactionID><Status>APPROVED</Status><AuthCode>111644</AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0"></Reason></ReasonCodes><ErrCode>0</ErrCode><ExErrCode>0</ExErrCode><Token>bwA1ADAAcAAwAHUAVABJAFYAUQAlAGcAfAB8AFQAbwBkAHAAbwAjAG4AaABDAHsAUABdACoAYwBaAEsAMQBHAEUAMQBuAHQAdwBXAFUAVABZACMAMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName></IssuerBankName><IssuerBankCountry></IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>SuiMHP60FrDKfyaJs47hqqrR/JU=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType></CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse /></Response>
    )
  end

  def failed_credit_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508440424</TransactionID><Status>DECLINED</Status><AuthCode></AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0">Decline</Reason></ReasonCodes><ErrCode>-1</ErrCode><ExErrCode>0</ExErrCode><Token>RwBVAGQAZgAwAFMAbABwAEwASgBNAFMAXABJAGAAeAAsAHsALAA7ADUAOgBUAEMAZwBNAG4AbABQAC4AQAAvAC0APwBpAEAAWQBoACMAdwBvAGEAMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName></IssuerBankName><IssuerBankCountry></IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>GyueFkuQqW+UL38d57fuA5/RqfQ=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType></CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse /></Response>
    )
  end

  def successful_void_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508208625</TransactionID><Status>APPROVED</Status><AuthCode>111171</AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0"></Reason></ReasonCodes><ErrCode>0</ErrCode><ExErrCode>0</ExErrCode><Token>ZQBpAFAAZgBuAHEATgBUAHcASAAwADUAcwBHAHQAVQBLAHAAbgB6AGwAJAA1AEMAfAB2AGYASwBrAHEAeQBOAEwAOwBZAGIAewB4AGwAYwBUAE0AMwA=</Token><CustomData></CustomData><AcquirerID>19</AcquirerID><IssuerBankName>University First Federal Credit Union</IssuerBankName><IssuerBankCountry>us</IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>SuiMHP60FrDKfyaJs47hqqrR/JU=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType>Credit</CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><FraudResponse /></Response>
    )
  end

  def failed_void_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyTestTRX</ClientLoginID><ClientUniqueID></ClientUniqueID><TransactionID>101508208633</TransactionID><Status>ERROR</Status><AuthCode></AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><Reason>Invalid Amount</Reason><ErrCode>-1100</ErrCode><ExErrCode>1201</ExErrCode><CustomData></CustomData><AcquirerID>-1</AcquirerID><IssuerBankName></IssuerBankName><IssuerBankCountry></IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>2jmj7l5rSw0yVb/vlWAYkK/YBwk=</UniqueCC><CustomData2></CustomData2><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType></CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo></Response>
    )
  end

  def successful_3ds_purchase_response
    %(
      <Response><Version>4.1.0</Version><ClientLoginID>SpreedlyManTestTRX</ClientLoginID><ClientUniqueID>98bd80c8c9534088311153ad6a67d108</ClientUniqueID><TransactionID>101510108310</TransactionID><Status>APPROVED</Status><AuthCode></AuthCode><AVSCode></AVSCode><CVV2Reply></CVV2Reply><ReasonCodes><Reason code="0"></Reason></ReasonCodes><ErrCode>0</ErrCode><ExErrCode>0</ExErrCode><Token>ZQBpAFAAMwBTAEcAMQBZAHcASQA4ADoAPQBlACQAZAB3ACMAWwAyAFoAWQBLAFUAPwBTAHYAKQAnAHQAUAA2AHYAYwAoAG0ARgBNAEEAcAAlAGEAMwA=</Token><CustomData></CustomData><ThreeDResponse><Auth3DResponse><Result>Y</Result><PaReq>eJxVUdtuwjAM/ZWK95GYgijIjVTWaUNTGdqQ4DUKFq2gF9J0A75+SVcuixTF59g+sY5xlWqi+ItUo0lgQnUtd+Rl27BXyScYAQce+MB7ApfRJx0FfpOus7IQ0Of9AbIrtK1apbIwAqU6zuYLMQSY8ABZBzEnPY8FfzhjGCH7o7GQOYlIq9J4K6qNd5VD1mZQlU1h9FkEQ47sCrDRB5EaU00ZO5RKHtKyth2ORXYfaNm4qLYqp2wrkjj6ud8XSFbRKYl3F/uGyFwFbqUhMeAwBvC5B6Opz6c+IGt5lLn73hlgR+kAVu6PqMu4xCOB1l1NhTqLydg6ckNIp6osyFZYJ28xsvvAz2/OT2WsRa+bdf2+X6cXtd9oHxZNPks+ojB0DrcFTi2zrkDAJ62cA8icBOuWx7oF2+jf4n8B</PaReq><MerchantID>000000000000715</MerchantID><ACSurl>https://pit.3dsecure.net/VbVTestSuiteService/pit1/acsService/paReq?summary=MjRlZGYwY2EtZTk5Zi00NDJjLTljOTAtNWUxZmRhMjEwODg3</ACSurl><XID>MDAwMDAwMDAwMDE1MTAxMDgzMTA=</XID><ThreeDReason></ThreeDReason></Auth3DResponse></ThreeDResponse><AcquirerID>19</AcquirerID><IssuerBankName>Visa Production Support Client Bid 1</IssuerBankName><IssuerBankCountry>us</IssuerBankCountry><Reference></Reference><AGVCode></AGVCode><AGVError></AGVError><UniqueCC>rDNDlh6XR8R6CVdGQyqDkZzdqE0=</UniqueCC><CustomData2></CustomData2><ThreeDFlow>1</ThreeDFlow><CreditCardInfo><IsPrepaid>0</IsPrepaid><CardType>Debit</CardType><CardProgram></CardProgram><CardProduct></CardProduct></CreditCardInfo><IsPartialApproval>0</IsPartialApproval><AmountInfo><RequestedAmount>1</RequestedAmount><RequestedCurrency>EUR</RequestedCurrency><ProcessedAmount>1</ProcessedAmount><ProcessedCurrency>EUR</ProcessedCurrency></AmountInfo><RRN></RRN><ICC></ICC><CVVReply></CVVReply></Response>
    )
  end
end
