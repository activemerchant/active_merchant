# encoding: utf-8
require 'test_helper'

class IyzicoTest < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = IyzicoGateway.new(api_id: 'sandbox-aKksNes17V1KPuAA1xw3Y431INO9iU8P', secret: 'sandbox-c5mxNw5RsciXzwCp1Sw9Pm4IZUSweBcM')
    @credit_card = credit_card('5528790000000008')
    @declined_card = credit_card('42424242424242')
    @amount = 0.1

    @options = {
        order_id: '',
        billing_address: address,
        shipping_address: address,
        description: 'Store Purchase',
        ip: '127.0.0.1',
        customer: 'Jim Smith',
        email: 'dharmesh.vasani@multidots.in',
        phone: '9898912233',
        name: 'Jim',
        lastLoginDate: '2015-10-05 12:43:35',
        registrationDate: '2013-04-21 15:12:09',
        items: [{
                    :name => 'EDC Marka Usb',
                    :category1 => 'Elektronik',
                    :category2 => 'Usb / Cable',
                    :id => 'BI103',
                    :price => 0.38,
                    :itemType => 'PHYSICAL'
                }]
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
  end

  def test_failed_purchase_with_declined_credit_card
    @gateway.expects(:ssl_request).returns(failed_purchase_response_invalid_card_number)
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "12", response.params["errorCode"]
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_purchase_response_invalid_card_number)
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "12", response.params["errorCode"]
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)
    response = @gateway.void("123456")
    assert_instance_of Response, response
    assert_success response
  end

  def test_failed_void_with_empty_payment_id
    @gateway.expects(:ssl_request).returns(failed_void_response)
    response = @gateway.void("", options={})
    assert_instance_of Response, response
    assert_failure response
    assert_equal "5002", response.params["errorCode"]
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)
    authorization = 4374
    response = @gateway.void(authorization, options={})
    assert_instance_of Response, response
    assert_failure response
    assert_equal "5002", response.params["errorCode"]
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Transaction success", response.message
  end

  def test_failed_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "Gecersiz imza", response.message
  end

  def test_default_currency
    assert_equal 'TRY', @gateway.default_currency
  end

  def test_supported_countries
    assert_equal ['TR'], @gateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express], @gateway.supported_cardtypes
  end

  def test_display_name
    assert_equal 'Iyzico', @gateway.display_name
  end

  private

  def successful_purchase_response
    "{\"status\":\"success\",\"locale\":\"tr\",\"systemTime\":1465300344785,\"conversationId\":\"123456789\",\"price\":1.0,\"paidPrice\":1.1,\"installment\":1,\"paymentId\":\"363\",\"fraudStatus\":1,\"merchantCommissionRate\":10.00000000,\"merchantCommissionRateAmount\":0.1,\"iyziCommissionRateAmount\":0.03245000,\"iyziCommissionFee\":0.29500000,\"cardType\":\"CREDIT_CARD\",\"cardAssociation\":\"MASTER_CARD\",\"cardFamily\":\"Paraf\",\"binNumber\":\"552879\",\"basketId\":\"B67832\",\"currency\":\"TRY\",\"itemTransactions\":[{\"itemId\":\"BI101\",\"paymentTransactionId\":\"900\",\"transactionStatus\":2,\"price\":0.3,\"paidPrice\":0.33000000,\"merchantCommissionRate\":10.00000000,\"merchantCommissionRateAmount\":0.03000000,\"iyziCommissionRateAmount\":0.00973500,\"iyziCommissionFee\":0.08850000,\"blockageRate\":10.00000000,\"blockageRateAmountMerchant\":0.03300000,\"blockageRateAmountSubMerchant\":0,\"blockageResolvedDate\":\"2016-06-22 14:52:24\",\"subMerchantPrice\":0,\"subMerchantPayoutRate\":0E-8,\"subMerchantPayoutAmount\":0,\"merchantPayoutAmount\":0.19876500,\"convertedPayout\":{\"paidPrice\":0.33000000,\"iyziCommissionRateAmount\":0.00973500,\"iyziCommissionFee\":0.08850000,\"blockageRateAmountMerchant\":0.03300000,\"blockageRateAmountSubMerchant\":0E-8,\"subMerchantPayoutAmount\":0E-8,\"merchantPayoutAmount\":0.19876500,\"iyziConversionRate\":0,\"iyziConversionRateAmount\":0,\"currency\":\"TRY\"}},{\"itemId\":\"BI102\",\"paymentTransactionId\":\"901\",\"transactionStatus\":2,\"price\":0.5,\"paidPrice\":0.55000000,\"merchantCommissionRate\":10.00000000,\"merchantCommissionRateAmount\":0.05000000,\"iyziCommissionRateAmount\":0.01622500,\"iyziCommissionFee\":0.14750000,\"blockageRate\":10.00000000,\"blockageRateAmountMerchant\":0.05500000,\"blockageRateAmountSubMerchant\":0,\"blockageResolvedDate\":\"2016-06-22 14:52:24\",\"subMerchantPrice\":0,\"subMerchantPayoutRate\":0E-8,\"subMerchantPayoutAmount\":0,\"merchantPayoutAmount\":0.33127500,\"convertedPayout\":{\"paidPrice\":0.55000000,\"iyziCommissionRateAmount\":0.01622500,\"iyziCommissionFee\":0.14750000,\"blockageRateAmountMerchant\":0.05500000,\"blockageRateAmountSubMerchant\":0E-8,\"subMerchantPayoutAmount\":0E-8,\"merchantPayoutAmount\":0.33127500,\"iyziConversionRate\":0,\"iyziConversionRateAmount\":0,\"currency\":\"TRY\"}},{\"itemId\":\"BI103\",\"paymentTransactionId\":\"902\",\"transactionStatus\":2,\"price\":0.2,\"paidPrice\":0.22000000,\"merchantCommissionRate\":10.00000000,\"merchantCommissionRateAmount\":0.02000000,\"iyziCommissionRateAmount\":0.00649000,\"iyziCommissionFee\":0.05900000,\"blockageRate\":10.00000000,\"blockageRateAmountMerchant\":0.02200000,\"blockageRateAmountSubMerchant\":0,\"blockageResolvedDate\":\"2016-06-22 14:52:24\",\"subMerchantPrice\":0,\"subMerchantPayoutRate\":0E-8,\"subMerchantPayoutAmount\":0,\"merchantPayoutAmount\":0.13251000,\"convertedPayout\":{\"paidPrice\":0.22000000,\"iyziCommissionRateAmount\":0.00649000,\"iyziCommissionFee\":0.05900000,\"blockageRateAmountMerchant\":0.02200000,\"blockageRateAmountSubMerchant\":0E-8,\"subMerchantPayoutAmount\":0E-8,\"merchantPayoutAmount\":0.13251000,\"iyziConversionRate\":0,\"iyziConversionRateAmount\":0,\"currency\":\"TRY\"}}]}"
  end

  def failed_purchase_response_invalid_signature
    "{\"status\":\"failure\",\"errorCode\":\"1000\",\"errorMessage\":\"Gecersiz imza\",\"locale\":\"tr\",\"systemTime\":1465306093157,\"conversationId\":\"123456789\",\"paymentId\":\"\"}"
  end

  def failed_purchase_response_invalid_card_number
    "{\"status\":\"failure\",\"errorCode\":\"12\",\"errorMessage\":\"Kart numaras\xC4\xB1 ge\xC3\xA7ersizdir\",\"locale\":\"tr\",\"systemTime\":1465304881116,\"conversationId\":\"123456789\"}"
  end

  def successful_authorize_response
    "{\"status\":\"success\",\"locale\":\"tr\",\"systemTime\":1465300344785,\"conversationId\":\"123456789\",\"price\":1.0,\"paidPrice\":1.1,\"installment\":1,\"paymentId\":\"363\",\"fraudStatus\":1,\"merchantCommissionRate\":10.00000000,\"merchantCommissionRateAmount\":0.1,\"iyziCommissionRateAmount\":0.03245000,\"iyziCommissionFee\":0.29500000,\"cardType\":\"CREDIT_CARD\",\"cardAssociation\":\"MASTER_CARD\",\"cardFamily\":\"Paraf\",\"binNumber\":\"552879\",\"basketId\":\"B67832\",\"currency\":\"TRY\",\"itemTransactions\":[{\"itemId\":\"BI101\",\"paymentTransactionId\":\"900\",\"transactionStatus\":2,\"price\":0.3,\"paidPrice\":0.33000000,\"merchantCommissionRate\":10.00000000,\"merchantCommissionRateAmount\":0.03000000,\"iyziCommissionRateAmount\":0.00973500,\"iyziCommissionFee\":0.08850000,\"blockageRate\":10.00000000,\"blockageRateAmountMerchant\":0.03300000,\"blockageRateAmountSubMerchant\":0,\"blockageResolvedDate\":\"2016-06-22 14:52:24\",\"subMerchantPrice\":0,\"subMerchantPayoutRate\":0E-8,\"subMerchantPayoutAmount\":0,\"merchantPayoutAmount\":0.19876500,\"convertedPayout\":{\"paidPrice\":0.33000000,\"iyziCommissionRateAmount\":0.00973500,\"iyziCommissionFee\":0.08850000,\"blockageRateAmountMerchant\":0.03300000,\"blockageRateAmountSubMerchant\":0E-8,\"subMerchantPayoutAmount\":0E-8,\"merchantPayoutAmount\":0.19876500,\"iyziConversionRate\":0,\"iyziConversionRateAmount\":0,\"currency\":\"TRY\"}},{\"itemId\":\"BI102\",\"paymentTransactionId\":\"901\",\"transactionStatus\":2,\"price\":0.5,\"paidPrice\":0.55000000,\"merchantCommissionRate\":10.00000000,\"merchantCommissionRateAmount\":0.05000000,\"iyziCommissionRateAmount\":0.01622500,\"iyziCommissionFee\":0.14750000,\"blockageRate\":10.00000000,\"blockageRateAmountMerchant\":0.05500000,\"blockageRateAmountSubMerchant\":0,\"blockageResolvedDate\":\"2016-06-22 14:52:24\",\"subMerchantPrice\":0,\"subMerchantPayoutRate\":0E-8,\"subMerchantPayoutAmount\":0,\"merchantPayoutAmount\":0.33127500,\"convertedPayout\":{\"paidPrice\":0.55000000,\"iyziCommissionRateAmount\":0.01622500,\"iyziCommissionFee\":0.14750000,\"blockageRateAmountMerchant\":0.05500000,\"blockageRateAmountSubMerchant\":0E-8,\"subMerchantPayoutAmount\":0E-8,\"merchantPayoutAmount\":0.33127500,\"iyziConversionRate\":0,\"iyziConversionRateAmount\":0,\"currency\":\"TRY\"}},{\"itemId\":\"BI103\",\"paymentTransactionId\":\"902\",\"transactionStatus\":2,\"price\":0.2,\"paidPrice\":0.22000000,\"merchantCommissionRate\":10.00000000,\"merchantCommissionRateAmount\":0.02000000,\"iyziCommissionRateAmount\":0.00649000,\"iyziCommissionFee\":0.05900000,\"blockageRate\":10.00000000,\"blockageRateAmountMerchant\":0.02200000,\"blockageRateAmountSubMerchant\":0,\"blockageResolvedDate\":\"2016-06-22 14:52:24\",\"subMerchantPrice\":0,\"subMerchantPayoutRate\":0E-8,\"subMerchantPayoutAmount\":0,\"merchantPayoutAmount\":0.13251000,\"convertedPayout\":{\"paidPrice\":0.22000000,\"iyziCommissionRateAmount\":0.00649000,\"iyziCommissionFee\":0.05900000,\"blockageRateAmountMerchant\":0.02200000,\"blockageRateAmountSubMerchant\":0E-8,\"subMerchantPayoutAmount\":0E-8,\"merchantPayoutAmount\":0.13251000,\"iyziConversionRate\":0,\"iyziConversionRateAmount\":0,\"currency\":\"TRY\"}}]}"
  end

  def failed_authorize_response
    "{\"status\":\"failure\",\"errorCode\":\"1000\",\"errorMessage\":\"Gecersiz imza\",\"locale\":\"tr\",\"systemTime\":1465306093157,\"conversationId\":\"123456789\",\"paymentId\":\"\"}"
  end

  def successful_void_response
    "{\"status\":\"success\",\"locale\":\"tr\",\"systemTime\":1451901238711,\"paymentId\":\"4374\",\"price\":0.1}"
  end

  def failed_void_response
    "{\"status\":\"failure\",\"errorCode\":\"5002\",\"errorMessage\":\"paymentId g\xC3\xB6nderilmesi zorunludur\",\"locale\":\"tr\",\"systemTime\":1465306093157,\"conversationId\":\"123456789\",\"paymentId\":\"\"}"
  end
end
