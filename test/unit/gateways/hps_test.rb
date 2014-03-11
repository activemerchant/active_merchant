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
    service = mock()
    service.stubs(:charge).returns(successful_charge_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})


    response = gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params["response_code"]
  end

  def test_failed_purchase
    service = mock()
    service.stubs(:charge).raises(failed_charge_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})

    response = gateway.purchase(10.34, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_authorize
    service = mock()
    service.stubs(:authorize).returns(successful_authorize_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})

    response = gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params["response_code"]
  end

  def test_failed_authorize
    service = mock()
      service.stubs(:authorize).raises(failed_authorize_response)
      HpsGateway.any_instance.stubs(:initialize_service).returns(service)

      gateway = HpsGateway.new({:secret_api_key => '12'})

    response = gateway.authorize(10.34, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_capture
    service = mock()
    service.stubs(:authorize).returns(successful_authorize_response)
    service.stubs(:capture).returns(successful_capture_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})

    response = gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params["response_code"]

    capture_response = gateway.capture(@amount, response.params["transaction_id"])
    assert_instance_of Response, capture_response
    assert_success capture_response
    assert_equal '00', capture_response.params["response_code"]
  end

  def test_failed_capture
    service = mock()
    service.stubs(:authorize).returns(successful_authorize_response)
    service.stubs(:capture).raises(failed_capture_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})

    response = gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params["response_code"]

    capture_response = gateway.capture(@amount, "Bad_Transaction_Id")
    assert_instance_of Response, capture_response
    assert_failure capture_response
    assert_equal 'Unable to process the payment transaction.', capture_response.message
  end

  def test_successful_refund
    service = mock()
    service.stubs(:charge).returns(successful_charge_response)
    service.stubs(:refund_transaction).returns(successful_refund_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params['response_code']

    refund = gateway.refund(@amount,response.params['transaction_id'])
    assert_instance_of Response, refund
    assert_success refund
    assert_equal '00', refund.params['response_code']
  end

  def test_failed_refund
    service = mock()
    service.stubs(:charge).returns(successful_charge_response)
    service.stubs(:refund_transaction).raises(failed_refund_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params['response_code']

    refund = gateway.refund(@amount,'Bad_Transaction_Id')
    assert_instance_of Response, refund
    assert_failure refund
    assert_equal nil, refund.params['response_code']
  end

  def test_successful_void
    service = mock()
    service.stubs(:charge).returns(successful_charge_response)
    service.stubs(:void).returns(successful_void_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params['response_code']

    void = gateway.void(response.params['transaction_id'])
    assert_instance_of Response, void
    assert_success void
    assert_equal '00', void.params['response_code']
  end

  def test_failed_void
    service = mock()
    service.stubs(:charge).returns(successful_charge_response)
    service.stubs(:void).raises(failed_void_response)
    HpsGateway.any_instance.stubs(:initialize_service).returns(service)

    gateway = HpsGateway.new({:secret_api_key => '12'})
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.params['response_code']

    void = gateway.void('Bad_Transaction_Id')
    assert_instance_of Response, void
    assert_failure void
    assert_equal nil , void.params['response_code']
  end

  private

  def successful_charge_response
      header = {
          "LicenseId" => '21229',
          "SiteId" => '21232',
          "DeviceId" => '1525997',
          "GatewayTxnId" => '15578618',
          "GatewayRspCode" => '0',
          "GatewayRspMsg" => 'Success',
          "RspDT" => '2014-02-28T15:52:52.6459775'
      }

      creditSaleRsp = {
          "AuthAmt" => '100',
          "AuthCode" => '00',
          "AVSRsltCode" => '00',
          "AVSRsltText" => 'AVS Not Requested',
          "CardType" => 'Visa',
          "CPCInd" => 0,
          "CVVRsltCode" => 'ACCEPT',
          "CVVRsltText" => 'Match',
          "RefNbr" => '405914102783',
          "RspCode" => '00',
          "RspText" => 'APPROVAL'
      }

      hpsTransactionHeader = Hps::HpsTransactionHeader.new
      hpsTransactionHeader.gateway_response_code = header["GatewayRspCode"]
      hpsTransactionHeader.gateway_response_message = header["GatewayRspMsg"]
      hpsTransactionHeader.response_dt = header["RspDT"]
      hpsTransactionHeader.client_txn_id = header["GatewayTxnId"]

      result = Hps::HpsCharge.new(hpsTransactionHeader)
      result.transaction_id = header["GatewayTxnId"]
      result.authorized_amount = creditSaleRsp["AuthAmt"]
      result.authorization_code = creditSaleRsp["AuthCode"]
      result.avs_result_code = creditSaleRsp["AVSRsltCode"]
      result.avs_result_text = creditSaleRsp["AVSRsltText"]
      result.card_type = creditSaleRsp["CardType"]
      result.cpc_indicator = creditSaleRsp["CPCInd"]
      result.cvv_result_code = creditSaleRsp["CVVRsltCode"]
      result.cvv_result_text = creditSaleRsp["CVVRsltText"]
      result.reference_number = creditSaleRsp["RefNbr"]
      result.response_code = creditSaleRsp["RspCode"]
      result.response_text = creditSaleRsp["RspText"]
      result
  end

  def failed_charge_response
    exception = Hps::CardException.new('transaction_id','card_declined','The card was declined')
    exception
  end

  def successful_authorize_response
    header = {
        "LicenseId" => '21229',
        "SiteId" => '21232',
        "DeviceId" => '1525997',
        "GatewayTxnId" => '15578618',
        "GatewayRspCode" => '0',
        "GatewayRspMsg" => 'Success',
        "RspDT" => '2014-02-28T15:52:52.6459775'
    }

    auth_response = {
        "AuthAmt" => nil,
        "AuthCode" => '23364A',
        "AVSRsltCode" => '0',
        "AVSRsltText" => 'AVS Not Requested',
        "CardType" => 'Visa',
        "CPCInd" => nil,
        "CVVRsltCode" => 'M',
        "CVVRsltText" => 'Match.',
        "RefNbr" => '405914102783',
        "RspCode" => '00',
        "RspText" => 'APPROVAL'
    }

    hpsTransactionHeader = Hps::HpsTransactionHeader.new
    hpsTransactionHeader.gateway_response_code = header["GatewayRspCode"]
    hpsTransactionHeader.gateway_response_message = header["GatewayRspMsg"]
    hpsTransactionHeader.response_dt = header["RspDT"]
    hpsTransactionHeader.client_txn_id = header["GatewayTxnId"]

    result = Hps::HpsAuthorization.new(hpsTransactionHeader)
    result.transaction_id = header["GatewayTxnId"]
    result.authorized_amount = auth_response["AuthAmt"]
    result.authorization_code = auth_response["AuthCode"]
    result.avs_result_code = auth_response["AVSRsltCode"]
    result.avs_result_text = auth_response["AVSRsltText"]
    result.card_type = auth_response["CardType"]
    result.cpc_indicator = auth_response["CPCInd"]
    result.cvv_result_code = auth_response["CVVRsltCode"]
    result.cvv_result_text = auth_response["CVVRsltText"]
    result.reference_number = auth_response["RefNbr"]
    result.response_code = auth_response["RspCode"]
    result.response_text = auth_response["RspText"]

    unless header["TokenData"].nil?
      result.token_data = HpsTokenData.new()
      result.token_data.response_code = header["TokenData"]["TokenRspCode"];
      result.token_data.response_message = header["TokenData"]["TokenRspMsg"]
      result.token_data.token_value = header["TokenData"]["TokenValue"]
    end

    result
  end

  def failed_authorize_response
    exception = Hps::CardException.new('transaction_id','card_declined','The card was declined')
    exception
  end

  def successful_capture_response
    header = {
        "LicenseId" => '21229',
        "SiteId" => '21232',
        "DeviceId" => '1525997',
        "GatewayTxnId" => '15578618',
        "GatewayRspCode" => '0',
        "GatewayRspMsg" => 'Success',
        "RspDT" => '2014-02-28T15:52:52.6459775'
    }

    detail = {
        "GatewayTxnId" => '15578618',
        "OriginalGatewayTxnId" => '0',
        "ServiceName" => '0',
        "Data" => {
            "AuthAmt" => '100.00',
            "AuthCode" => '23364A',
            "AVSRsltCode" => '0',
            "AVSRsltText" => 'AVS Not Requested',
            "CardType" => nil,
            "MaskedCardNbr" => '424242******4242',
            "CPCInd" => nil,
            "CVVRsltCode" => 'M',
            "CVVRsltText" => 'Match.',
            "RefNbr" => '405914102783',
            "RspCode" => '00',
            "RspText" => 'APPROVAL',
            "TokenizationMsg" => nil
        }
    }

    hpsTransactionHeader = Hps::HpsTransactionHeader.new
    hpsTransactionHeader.gateway_response_code = header["GatewayRspCode"]
    hpsTransactionHeader.gateway_response_message = header["GatewayRspMsg"]
    hpsTransactionHeader.response_dt = header["RspDT"]
    hpsTransactionHeader.client_txn_id = header["GatewayTxnId"]

    result = Hps::HpsReportTransactionDetails.new(hpsTransactionHeader)
    result.transaction_id = detail["GatewayTxnId"]
    result.original_transaction_id = detail["OriginalGatewayTxnId"]
    result.authorized_amount = detail["Data"]["AuthAmt"]
    result.authorization_code = detail["Data"]["AuthCode"]
    result.avs_result_code = detail["Data"]["AVSRsltCode"]
    result.avs_result_text = detail["Data"]["AVSRsltText"]
    result.card_type = detail["Data"]["CardType"]
    result.masked_card_number = detail["Data"]["MaskedCardNbr"]
    result.transaction_type = detail["ServiceName"]
    result.transaction_date = detail["RspUtcDT"]
    result.cpc_indicator = detail["Data"]["CPCInd"]
    result.cvv_result_code = detail["Data"]["CVVRsltCode"]
    result.cvv_result_text = detail["Data"]["CVVRsltText"]
    result.reference_number = detail["Data"]["RefNbr"]
    result.response_code = detail["Data"]["RspCode"]
    result.response_text = detail["Data"]["RspText"]

    tokenization_message = detail["Data"]["TokenizationMsg"]

    unless tokenization_message.nil?
      result.token_data = Hps::HpsTokenData.new(tokenization_message)
    end

    result
  end

  def failed_capture_response
    exception = Hps::ApiConnectionException.new('Unable to process the payment transaction.',0,'sdk_exception')
    exception
  end

  def successful_refund_response
    header = {
        "LicenseId" => '21229',
        "SiteId" => '21232',
        "DeviceId" => '1525997',
        "GatewayTxnId" => '15578618',
        "GatewayRspCode" => '0',
        "GatewayRspMsg" => 'Success',
        "RspDT" => '2014-02-28T15:52:52.6459775'
    }
    hpsTransactionHeader = Hps::HpsTransactionHeader.new
    hpsTransactionHeader.gateway_response_code = header["GatewayRspCode"]
    hpsTransactionHeader.gateway_response_message = header["GatewayRspMsg"]
    hpsTransactionHeader.response_dt = header["RspDT"]
    hpsTransactionHeader.client_txn_id = header["GatewayTxnId"]

    result = Hps::HpsRefund.new(hpsTransactionHeader)
    result.transaction_id = header["GatewayTxnId"]
    result.response_code = "00"
    result.response_text = ""

    result
  end

  def failed_refund_response
    exception = Hps::ApiConnectionException.new('Unable to process the payment transaction.',0,'sdk_exception')
    exception
  end

  def successful_void_response
    header = {
        "LicenseId" => '21229',
        "SiteId" => '21232',
        "DeviceId" => '1525997',
        "GatewayTxnId" => '15578618',
        "GatewayRspCode" => '0',
        "GatewayRspMsg" => 'Success',
        "RspDT" => '2014-02-28T15:52:52.6459775'
    }
    hpsTransactionHeader = Hps::HpsTransactionHeader.new
    hpsTransactionHeader.gateway_response_code = header["GatewayRspCode"]
    hpsTransactionHeader.gateway_response_message = header["GatewayRspMsg"]
    hpsTransactionHeader.response_dt = header["RspDT"]
    hpsTransactionHeader.client_txn_id = header["GatewayTxnId"]

    result = Hps::HpsVoid.new(hpsTransactionHeader)
    result.transaction_id = header["GatewayTxnId"]
    result.response_code = "00"
    result.response_text = ""
    result
  end

  def failed_void_response
    exception = Hps::ApiConnectionException.new('Unable to process the payment transaction.',0,'sdk_exception')
    exception
  end
end
