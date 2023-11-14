require 'test_helper'

class VantivExpressTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = VantivExpressGateway.new(fixtures(:element))
    @credit_card = credit_card
    @check = check
    @amount = 100

    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }

    @apple_pay_network_token = network_tokenization_credit_card(
      '4895370015293175',
      month: '10',
      year: Time.new.year + 2,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      payment_cryptogram: 'CeABBJQ1AgAAAAAgJDUCAAAAAAA=',
      eci: '07',
      transaction_id: 'abc123',
      source: :apple_pay
    )

    @google_pay_network_token = network_tokenization_credit_card(
      '6011000400000000',
      month: '01',
      year: Time.new.year + 2,
      first_name: 'Jane',
      last_name: 'Doe',
      verification_value: '888',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      eci: '05',
      transaction_id: '123456789',
      source: :google_pay
    )
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '2005831886|100', response.authorization
  end

  def test_successful_purchase_without_name
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    @credit_card.first_name = nil
    @credit_card.last_name = nil

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '2005831886|100', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase_with_echeck
    @gateway.expects(:ssl_post).returns(successful_purchase_with_echeck_response)

    response = @gateway.purchase(@amount, @check, @options)
    assert_success response

    assert_equal '2005838412|100', response.authorization
  end

  def test_failed_purchase_with_echeck
    @gateway.expects(:ssl_post).returns(failed_purchase_with_echeck_response)

    response = @gateway.purchase(@amount, @check, @options)
    assert_failure response
  end

  def test_successful_purchase_with_apple_pay
    response = stub_comms do
      @gateway.purchase(@amount, @apple_pay_network_token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match '<WalletType>2</WalletType>', data
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_google_pay
    response = stub_comms do
      @gateway.purchase(@amount, @google_pay_network_token, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match '<WalletType>1</WalletType>', data
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_payment_account_token
    @gateway.expects(:ssl_post).returns(successful_purchase_with_payment_account_token_response)

    response = @gateway.purchase(@amount, 'payment-account-token-id', @options)
    assert_success response

    assert_equal '2005838405|100', response.authorization
  end

  def test_failed_purchase_with_payment_account_token
    @gateway.expects(:ssl_post).returns(failed_purchase_with_payment_account_token_response)

    response = @gateway.purchase(@amount, 'bad-payment-account-token-id', @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal '2005832533|100', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'trans-id')
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'bad-trans-id')
    assert_failure response
    assert_equal 'TransactionID required', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'trans-id')
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'bad-trans-id')
    assert_failure response
    assert_equal 'TransactionID required', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('trans-id')
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('bad-trans-id')
    assert_failure response
    assert_equal 'TransactionAmount required', response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_handles_error_response
    @gateway.expects(:ssl_post).returns(error_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal response.message, 'TargetNamespace required'
    assert_failure response
  end

  def test_successful_purchase_with_card_present_code
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(card_present_code: 'Present'))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<CardPresentCode>2</CardPresentCode>', data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_payment_type
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(payment_type: 'NotUsed'))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<PaymentType>0</PaymentType>', data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_submission_type
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(submission_type: 'NotUsed'))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<SubmissionType>0</SubmissionType>', data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_duplicate_check_disable_flag
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: true))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<DuplicateCheckDisableFlag>1</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: 'true'))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<DuplicateCheckDisableFlag>1</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: false))
    end.check_request do |_endpoint, data, _headers|
      assert_not_match '<DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: 'xxx'))
    end.check_request do |_endpoint, data, _headers|
      assert_not_match '<DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: 'False'))
    end.check_request do |_endpoint, data, _headers|
      assert_not_match '<DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    # when duplicate_check_disable_flag is NOT passed, should not be in XML at all
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match %r(<DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag>), data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_duplicate_override_flag
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_override_flag: true))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<DuplicateCheckDisableFlag>1</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_override_flag: 'true'))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<DuplicateCheckDisableFlag>1</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_override_flag: false))
    end.check_request do |_endpoint, data, _headers|
      assert_not_match '<DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_override_flag: 'xxx'))
    end.check_request do |_endpoint, data, _headers|
      assert_not_match '<DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_override_flag: 'False'))
    end.check_request do |_endpoint, data, _headers|
      assert_not_match '<DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag>', data
    end.respond_with(successful_purchase_response)

    assert_success response

    # when duplicate_override_flag is NOT passed, should not be in XML at all
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match %r(<DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag>), data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_terminal_id
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(terminal_id: '02'))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<TerminalID>02</TerminalID>', data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_billing_email
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(email: 'test@example.com'))
    end.check_request do |_endpoint, data, _headers|
      assert_match '<BillingEmail>test@example.com</BillingEmail>', data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_credit_with_extra_fields
    credit_options = @options.merge({ ticket_number: '1', market_code: 'FoodRestaurant', merchant_supplied_transaction_id: '123' })
    stub_comms do
      @gateway.credit(@amount, @credit_card, credit_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match '<CreditCardCredit', data
      assert_match '<TicketNumber>1</TicketNumber', data
      assert_match '<MarketCode>4</MarketCode>', data
      assert_match '<MerchantSuppliedTransactionID>123</MerchantSuppliedTransactionID>', data
    end.respond_with(successful_credit_response)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<~XML
      <?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<CreditCardSale xmlns=\"https://transaction.elementexpress.com\">\n      <credentials>\n        <AccountID>1013963</AccountID>\n        <AccountToken>683EED8A1A357EB91575A168E74482A74836FD72B1AD11B41B29B473CA9D65B9FE067701</AccountToken>\n        <AcceptorID>3928907</AcceptorID>\n      </credentials>\n      <application>\n        <ApplicationID>5211</ApplicationID>\n        <ApplicationName>Spreedly</ApplicationName>\n        <ApplicationVersion>1</ApplicationVersion>\n      </application>\n      <card>\n        <CardNumber>4000100011112224</CardNumber>\n        <ExpirationMonth>09</ExpirationMonth>\n        <ExpirationYear>16</ExpirationYear>\n        <CardholderName>Longbob Longsen</CardholderName>\n        <CVV>123</CVV>\n      </card>\n      <transaction>\n        <TransactionAmount>1.00</TransactionAmount>\n        <MarketCode>Default</MarketCode>\n      </transaction>\n      <terminal>\n        <TerminalID>01</TerminalID>\n        <CardPresentCode>UseDefault</CardPresentCode>\n        <CardholderPresentCode>UseDefault</CardholderPresentCode>\n        <CardInputCode>UseDefault</CardInputCode>\n        <CVVPresenceCode>UseDefault</CVVPresenceCode>\n        <TerminalCapabilityCode>UseDefault</TerminalCapabilityCode>\n        <TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode>\n        <MotoECICode>UseDefault</MotoECICode>\n      </terminal>\n      <address>\n        <BillingAddress1>456 My Street</BillingAddress1>\n        <BillingAddress2>Apt 1</BillingAddress2>\n        <BillingCity>Ottawa</BillingCity>\n        <BillingState>ON</BillingState>\n        <BillingZipcode>K1C2N6</BillingZipcode>\n      </address>\n    </CreditCardSale>
    XML
  end

  def post_scrubbed
    <<~XML
      <?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<CreditCardSale xmlns=\"https://transaction.elementexpress.com\">\n      <credentials>\n        <AccountID>1013963</AccountID>\n        <AccountToken>[FILTERED]</AccountToken>\n        <AcceptorID>3928907</AcceptorID>\n      </credentials>\n      <application>\n        <ApplicationID>5211</ApplicationID>\n        <ApplicationName>Spreedly</ApplicationName>\n        <ApplicationVersion>1</ApplicationVersion>\n      </application>\n      <card>\n        <CardNumber>[FILTERED]</CardNumber>\n        <ExpirationMonth>09</ExpirationMonth>\n        <ExpirationYear>16</ExpirationYear>\n        <CardholderName>Longbob Longsen</CardholderName>\n        <CVV>[FILTERED]</CVV>\n      </card>\n      <transaction>\n        <TransactionAmount>1.00</TransactionAmount>\n        <MarketCode>Default</MarketCode>\n      </transaction>\n      <terminal>\n        <TerminalID>01</TerminalID>\n        <CardPresentCode>UseDefault</CardPresentCode>\n        <CardholderPresentCode>UseDefault</CardholderPresentCode>\n        <CardInputCode>UseDefault</CardInputCode>\n        <CVVPresenceCode>UseDefault</CVVPresenceCode>\n        <TerminalCapabilityCode>UseDefault</TerminalCapabilityCode>\n        <TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode>\n        <MotoECICode>UseDefault</MotoECICode>\n      </terminal>\n      <address>\n        <BillingAddress1>456 My Street</BillingAddress1>\n        <BillingAddress2>Apt 1</BillingAddress2>\n        <BillingCity>Ottawa</BillingCity>\n        <BillingState>ON</BillingState>\n        <BillingZipcode>K1C2N6</BillingZipcode>\n      </address>\n    </CreditCardSale>
    XML
  end

  def error_response
    <<~XML
      <Response xmlns='https://transaction.elementexpress.com'><Response><ExpressResponseCode>103</ExpressResponseCode><ExpressResponseMessage>TargetNamespace required</ExpressResponseMessage></Response></Response>
    XML
  end

  def successful_purchase_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardSaleResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Approved</ExpressResponseMessage><ExpressTransactionDate>20151201</ExpressTransactionDate><ExpressTransactionTime>104518</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>000</HostResponseCode><HostResponseMessage>AP</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><HostItemID>96</HostItemID><HostBatchAmount>2962.00</HostBatchAmount><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat><AVSResponseCode>N</AVSResponseCode><CVVResponseCode>M</CVVResponseCode><CardLogo>Visa</CardLogo></Card><Transaction><TransactionID>2005831886</TransactionID><ApprovalNumber>000045</ApprovalNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><AcquirerData>aVb001234567810425c0425d5e00</AcquirerData><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Approved</TransactionStatus><TransactionStatusCode>1</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><ApprovedAmount>1.00</ApprovedAmount><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address><BillingAddress1>456 My Street</BillingAddress1><BillingZipcode>K1C2N6</BillingZipcode></Address><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardSaleResponse>
    XML
  end

  def successful_purchase_with_echeck_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CheckSaleResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Success</ExpressResponseMessage><ExpressTransactionDate>20151202</ExpressTransactionDate><ExpressTransactionTime>090320</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>0</HostResponseCode><HostResponseMessage>Transaction Processed</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat></Card><Transaction><TransactionID>2005838412</TransactionID><ReferenceNumber>347520966b3df3e93051b5dc85c355a54e3012c2</ReferenceNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Pending</TransactionStatus><TransactionStatusCode>10</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address><BillingAddress1>456 My Street</BillingAddress1><BillingZipcode>K1C2N6</BillingZipcode></Address><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CheckSaleResponse>
    XML
  end

  def successful_purchase_with_payment_account_token_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardSaleResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Approved</ExpressResponseMessage><ExpressTransactionDate>20151202</ExpressTransactionDate><ExpressTransactionTime>090144</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>000</HostResponseCode><HostResponseMessage>AP</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><HostItemID>155</HostItemID><HostBatchAmount>2995.00</HostBatchAmount><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat><AVSResponseCode>N</AVSResponseCode><CardLogo>Visa</CardLogo></Card><Transaction><TransactionID>2005838405</TransactionID><ApprovalNumber>000001</ApprovalNumber><ReferenceNumber>c0d498aa3c2c07169d13a989a7af91af5bc4e6a0</ReferenceNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><AcquirerData>aVb001234567810425c0425d5e00</AcquirerData><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Approved</TransactionStatus><TransactionStatusCode>1</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><ApprovedAmount>1.00</ApprovedAmount><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountID>C875D86C-5913-487D-822E-76B27E2C2A4E</PaymentAccountID><PaymentAccountType>CreditCard</PaymentAccountType><PaymentAccountReferenceNumber>147b0b90f74faac13afb618fdabee3a4e75bf03b</PaymentAccountReferenceNumber><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address><BillingAddress1>456 My Street</BillingAddress1><BillingZipcode>K1C2N6</BillingZipcode></Address><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardSaleResponse>
    XML
  end

  def successful_credit_response
    <<~XML
      <?xml version=\"1.0\" encoding=\"utf-8\"?><CreditCardCreditResponse xmlns=\"https://transaction.elementexpress.com\"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Approved</ExpressResponseMessage><ExpressTransactionDate>20211122</ExpressTransactionDate><ExpressTransactionTime>174635</ExpressTransactionTime><ExpressTransactionTimezone>UTC-06:00</ExpressTransactionTimezone><HostResponseCode>000</HostResponseCode><HostResponseMessage>AP</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><HostItemID>102</HostItemID><HostBatchAmount>103.00</HostBatchAmount><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><CardLogo>Visa</CardLogo><BIN>400010</BIN></Card><Transaction><TransactionID>122816253</TransactionID><ApprovalNumber>000046</ApprovalNumber><ReferenceNumber>1</ReferenceNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Approved</TransactionStatus><TransactionStatusCode>1</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason><PaymentType>NotUsed</PaymentType><SubmissionType>NotUsed</SubmissionType></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address /><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token /></response></CreditCardCreditResponse>
    XML
  end

  def failed_purchase_with_echeck_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardSaleResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>101</ExpressResponseCode><ExpressResponseMessage>CardNumber Required</ExpressResponseMessage><ExpressTransactionDate>20151202</ExpressTransactionDate><ExpressTransactionTime>090342</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat></Card><Transaction><ReferenceNumber>8fe3b762a2a4344d938c32be31f36e354fb28ee3</ReferenceNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address /><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardSaleResponse>
    XML
  end

  def failed_purchase_with_payment_account_token_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardSaleResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>103</ExpressResponseCode><ExpressResponseMessage>PAYMENT ACCOUNT NOT FOUND</ExpressResponseMessage><ExpressTransactionDate>20151202</ExpressTransactionDate><ExpressTransactionTime>090245</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat></Card><Transaction><ReferenceNumber>564bd4943761a37bdbb3f201faa56faa091781b5</ReferenceNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountID>asdf</PaymentAccountID><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address /><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardSaleResponse>
    XML
  end

  def failed_purchase_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardSaleResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>20</ExpressResponseCode><ExpressResponseMessage>Declined</ExpressResponseMessage><ExpressTransactionDate>20151201</ExpressTransactionDate><ExpressTransactionTime>104817</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>007</HostResponseCode><HostResponseMessage>DECLINED</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat><AVSResponseCode>N</AVSResponseCode><CVVResponseCode>M</CVVResponseCode><CardLogo>Visa</CardLogo></Card><Transaction><TransactionID>2005831909</TransactionID><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><AcquirerData>aVb001234567810425c0425d5e00</AcquirerData><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Declined</TransactionStatus><TransactionStatusCode>2</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address><BillingAddress1>456 My Street</BillingAddress1><BillingZipcode>K1C2N6</BillingZipcode></Address><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardSaleResponse>
    XML
  end

  def successful_authorize_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardAuthorizationResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Approved</ExpressResponseMessage><ExpressTransactionDate>20151201</ExpressTransactionDate><ExpressTransactionTime>120220</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>000</HostResponseCode><HostResponseMessage>AP</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat><AVSResponseCode>N</AVSResponseCode><CVVResponseCode>M</CVVResponseCode><CardLogo>Visa</CardLogo></Card><Transaction><TransactionID>2005832533</TransactionID><ApprovalNumber>000002</ApprovalNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><AcquirerData>aVb001234567810425c0425d5e00</AcquirerData><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Authorized</TransactionStatus><TransactionStatusCode>5</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><ApprovedAmount>1.00</ApprovedAmount><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address><BillingAddress1>456 My Street</BillingAddress1><BillingZipcode>K1C2N6</BillingZipcode></Address><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardAuthorizationResponse>
    XML
  end

  def failed_authorize_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardAuthorizationResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>20</ExpressResponseCode><ExpressResponseMessage>Declined</ExpressResponseMessage><ExpressTransactionDate>20151201</ExpressTransactionDate><ExpressTransactionTime>120315</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>007</HostResponseCode><HostResponseMessage>DECLINED</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat><AVSResponseCode>N</AVSResponseCode><CVVResponseCode>M</CVVResponseCode><CardLogo>Visa</CardLogo></Card><Transaction><TransactionID>2005832537</TransactionID><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><AcquirerData>aVb001234567810425c0425d5e00</AcquirerData><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Declined</TransactionStatus><TransactionStatusCode>2</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address><BillingAddress1>456 My Street</BillingAddress1><BillingZipcode>K1C2N6</BillingZipcode></Address><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardAuthorizationResponse>
    XML
  end

  def successful_capture_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardAuthorizationCompletionResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Success</ExpressResponseMessage><ExpressTransactionDate>20151201</ExpressTransactionDate><ExpressTransactionTime>120222</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>000</HostResponseCode><HostResponseMessage>AP</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><HostItemID>97</HostItemID><HostBatchAmount>2963.00</HostBatchAmount><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat><CardLogo>Visa</CardLogo></Card><Transaction><TransactionID>2005832535</TransactionID><ApprovalNumber>000002</ApprovalNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><AcquirerData>aVb001234567810425c0425d5e00</AcquirerData><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Approved</TransactionStatus><TransactionStatusCode>1</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address /><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardAuthorizationCompletionResponse>
    XML
  end

  def failed_capture_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardAuthorizationCompletionResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>101</ExpressResponseCode><ExpressResponseMessage>TransactionID required</ExpressResponseMessage><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat></Card><Transaction><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address /><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardAuthorizationCompletionResponse>
    XML
  end

  def successful_refund_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardReturnResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Approved</ExpressResponseMessage><ExpressTransactionDate>20151201</ExpressTransactionDate><ExpressTransactionTime>120437</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>000</HostResponseCode><HostResponseMessage>AP</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><HostBatchID>1</HostBatchID><HostItemID>99</HostItemID><HostBatchAmount>2963.00</HostBatchAmount><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat><CardLogo>Visa</CardLogo></Card><Transaction><TransactionID>2005832540</TransactionID><ApprovalNumber>000004</ApprovalNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Approved</TransactionStatus><TransactionStatusCode>1</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address><BillingAddress1>456 My Street</BillingAddress1><BillingZipcode>K1C2N6</BillingZipcode></Address><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardReturnResponse>
    XML
  end

  def failed_refund_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardReturnResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>101</ExpressResponseCode><ExpressResponseMessage>TransactionID required</ExpressResponseMessage><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat></Card><Transaction><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address /><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardReturnResponse>
    XML
  end

  def successful_void_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardReversalResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Success</ExpressResponseMessage><ExpressTransactionDate>20151201</ExpressTransactionDate><ExpressTransactionTime>120516</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>006</HostResponseCode><HostResponseMessage>REVERSED</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat><CardLogo>Visa</CardLogo></Card><Transaction><TransactionID>2005832551</TransactionID><ApprovalNumber>000005</ApprovalNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><AcquirerData>aVb001234567810425c0425d5e00</AcquirerData><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Success</TransactionStatus><TransactionStatusCode>8</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address /><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardReversalResponse>
    XML
  end

  def failed_void_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardReversalResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>101</ExpressResponseCode><ExpressResponseMessage>TransactionAmount required</ExpressResponseMessage><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><EncryptedFormat>Default</EncryptedFormat></Card><Transaction><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address /><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><DDAAccountType>Checking</DDAAccountType><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token><TokenProvider>Null</TokenProvider></Token></response></CreditCardReversalResponse>
    XML
  end

  def successful_verify_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><CreditCardAVSOnlyResponse xmlns="https://transaction.elementexpress.com"><response><ExpressResponseCode>0</ExpressResponseCode><ExpressResponseMessage>Success</ExpressResponseMessage><ExpressTransactionDate>20200505</ExpressTransactionDate><ExpressTransactionTime>094556</ExpressTransactionTime><ExpressTransactionTimezone>UTC-05:00</ExpressTransactionTimezone><HostResponseCode>000</HostResponseCode><HostResponseMessage>AP</HostResponseMessage><Credentials /><Batch><BatchCloseType>Regular</BatchCloseType><BatchQueryType>Totals</BatchQueryType><BatchGroupingCode>FullBatch</BatchGroupingCode><BatchIndexCode>Current</BatchIndexCode></Batch><Card><AVSResponseCode>N</AVSResponseCode><CardLogo>Visa</CardLogo><BIN>400010</BIN></Card><Transaction><TransactionID>48138154</TransactionID><ReferenceNumber>1</ReferenceNumber><ReversalType>System</ReversalType><MarketCode>Default</MarketCode><BillPaymentFlag>False</BillPaymentFlag><DuplicateCheckDisableFlag>False</DuplicateCheckDisableFlag><DuplicateOverrideFlag>False</DuplicateOverrideFlag><RecurringFlag>False</RecurringFlag><ProcessorName>NULL_PROCESSOR_TEST</ProcessorName><TransactionStatus>Success</TransactionStatus><TransactionStatusCode>8</TransactionStatusCode><PartialApprovedFlag>False</PartialApprovedFlag><EMVEncryptionFormat>Default</EMVEncryptionFormat><ReversalReason>Unknown</ReversalReason><PaymentType>NotUsed</PaymentType><SubmissionType>NotUsed</SubmissionType></Transaction><PaymentAccount><PaymentAccountType>CreditCard</PaymentAccountType><PASSUpdaterBatchStatus>Null</PASSUpdaterBatchStatus><PASSUpdaterOption>Null</PASSUpdaterOption></PaymentAccount><Address><BillingAddress1>456 My Street</BillingAddress1><BillingZipcode>K1C2N6</BillingZipcode></Address><ScheduledTask><RunFrequency>OneTimeFuture</RunFrequency><RunUntilCancelFlag>False</RunUntilCancelFlag><ScheduledTaskStatus>Active</ScheduledTaskStatus></ScheduledTask><DemandDepositAccount><CheckType>Personal</CheckType></DemandDepositAccount><TransactionSetup><TransactionSetupMethod>Null</TransactionSetupMethod><Device>Null</Device><Embedded>False</Embedded><CVVRequired>False</CVVRequired><AutoReturn>False</AutoReturn><DeviceInputCode>NotUsed</DeviceInputCode></TransactionSetup><Terminal><TerminalType>Unknown</TerminalType><CardPresentCode>UseDefault</CardPresentCode><CardholderPresentCode>UseDefault</CardholderPresentCode><CardInputCode>UseDefault</CardInputCode><CVVPresenceCode>UseDefault</CVVPresenceCode><TerminalCapabilityCode>UseDefault</TerminalCapabilityCode><TerminalEnvironmentCode>UseDefault</TerminalEnvironmentCode><MotoECICode>UseDefault</MotoECICode><CVVResponseType>Regular</CVVResponseType><ConsentCode>NotUsed</ConsentCode><TerminalEncryptionFormat>Default</TerminalEncryptionFormat></Terminal><AutoRental><AutoRentalVehicleClassCode>Unused</AutoRentalVehicleClassCode><AutoRentalDistanceUnit>Unused</AutoRentalDistanceUnit><AutoRentalAuditAdjustmentCode>NoAdjustments</AutoRentalAuditAdjustmentCode></AutoRental><Healthcare><HealthcareFlag>False</HealthcareFlag><HealthcareFirstAccountType>NotSpecified</HealthcareFirstAccountType><HealthcareFirstAmountType>LedgerBalance</HealthcareFirstAmountType><HealthcareFirstAmountSign>Positive</HealthcareFirstAmountSign><HealthcareSecondAccountType>NotSpecified</HealthcareSecondAccountType><HealthcareSecondAmountType>LedgerBalance</HealthcareSecondAmountType><HealthcareSecondAmountSign>Positive</HealthcareSecondAmountSign><HealthcareThirdAccountType>NotSpecified</HealthcareThirdAccountType><HealthcareThirdAmountType>LedgerBalance</HealthcareThirdAmountType><HealthcareThirdAmountSign>Positive</HealthcareThirdAmountSign><HealthcareFourthAccountType>NotSpecified</HealthcareFourthAccountType><HealthcareFourthAmountType>LedgerBalance</HealthcareFourthAmountType><HealthcareFourthAmountSign>Positive</HealthcareFourthAmountSign></Healthcare><Lodging><LodgingPrestigiousPropertyCode>NonParticipant</LodgingPrestigiousPropertyCode><LodgingSpecialProgramCode>Default</LodgingSpecialProgramCode><LodgingChargeType>Default</LodgingChargeType></Lodging><BIN /><EnhancedBIN /><Token /></response></CreditCardAVSOnlyResponse>
    XML
  end
end
