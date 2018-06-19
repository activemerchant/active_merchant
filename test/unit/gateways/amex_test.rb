require 'test_helper'

class AmexTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AmexGateway.new(
      currency: 'USD',
      username: 'TESTusername',
      password: 'password',
      api_version: 47
    )

    @credit_card = ActiveMerchant::Billing::CreditCard.new(first_name:         'Bob',
                                                           last_name:          'Bobsen',
                                                           number:             '345678901234564',
                                                           month:              '5',
                                                           year:               '21',
                                                           verification_value: '0000')
  end

  def test_gateway_requires_parameters
    assert_raises(ArgumentError, 'Missing required parameter: currency') do
      AmexGateway.new
    end
  end

  def test_successful_purchase_response_with_token
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(12, '9739586533803075', order_id: 'xxxxx', transaction_id: 'xxxxx')
    assert response.success?
    assert_equal 12.0, response.params['order']['amount']
    assert_equal 'xxxxx', response.params['order']['id']
    assert_equal 12.0, response.params['transaction']['amount']
    assert_equal 'xxxxx', response.params['transaction']['id']
    assert_equal 'CAPTURE', response.params['transaction']['type']
    assert response.test?
  end

  def test_successful_purchase_response_with_credit_card
    @gateway.expects(:store).returns(build_response(successful_store_response))
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(12, @credit_card, order_id: 'xxxxx', transaction_id: 'xxxxx')
    assert response.success?
    assert_equal 12.0, response.params['order']['amount']
    assert_equal 'xxxxx', response.params['order']['id']
    assert_equal 12.0, response.params['transaction']['amount']
    assert_equal 'xxxxx', response.params['transaction']['id']
    assert_equal 'CAPTURE', response.params['transaction']['type']
    assert response.test?
  end

  def test_successful_refund_response
    @gateway.expects(:ssl_request).returns(successful_refund_response)
    response = @gateway.refund(12, order_id: 'xxxxx', transaction_id: 'xxxxx')
    assert response.success?
    assert_equal 12.0, response.params['order']['amount']
    assert_equal 'xxxxx', response.params['order']['id']
    assert_equal 12.0, response.params['transaction']['amount']
    assert_equal 'xxxxx', response.params['transaction']['id']
    assert_equal 'REFUND', response.params['transaction']['type']
    assert response.test?
  end

  def test_successful_store_response
    @gateway.expects(:ssl_request).returns(successful_store_response)
    response = @gateway.store(@credit_card)
    assert response.success?
    assert_equal '9855696296999511', response.params['token']
    assert response.test?
  end

  def test_successful_update_card_response
    @gateway.expects(:store).returns(build_response(successful_store_response))
    @gateway.expects(:ssl_request).returns(successful_update_response)
    response = @gateway.update_card(@credit_card)
    assert response.success?
    assert_equal '9739586533803075', response.params['token']
    assert response.test?
  end

  # def test_successful_authorize_response
  #   response = @gateway.authorize(12, "9739586533803075", order_id: "aabbccddzyaabb", transaction_id: "aabbccddzyzaabb")
  # end

  # def test_successful_capture_response
  #   # @gateway.expects(:ssl_request).returns(successful_refund_response)
  #   response = @gateway.capture(12, order_id: "aabbccddzy", transaction_id: "aabbccddzyzaa")
  # end

  def test_successful_void_response
    @gateway.expects(:ssl_request).returns(successful_void_response)
    response = @gateway.void('xxxxx', order_id: 'xxxxx', transaction_id: 'newtransactionid')
    assert response.success?
    assert response.test?
    assert_equal 'xxxxx', response.params['order']['id']
    assert_equal 'newtransactionid', response.params['transaction']['id']
    assert_equal 'xxxxx', response.params['transaction']['targetTransactionId']
    assert_equal 'VOID_CAPTURE', response.params['transaction']['type']
  end

  def test_successful_verify_response
    @gateway.expects(:ssl_request).returns(successful_verify_response)
    response = @gateway.verify(token: '9739586533803075', order_id: 'xxxxx', transaction_id: 'xxxxx')
    assert response.success?
    assert_equal 'xxxxx', response.params['order']['id']
    assert_equal 'xxxxx', response.params['transaction']['id']
    assert response.test?
  end

  def test_successful_find_transaction_response
    @gateway.expects(:ssl_request).returns(successful_find_transaction_response)
    response = @gateway.find_transaction(order_id: 'xxxxx', transaction_id: 'xxxxx')
    assert response.success?
    assert_equal 'xxxxx', response.params['transaction']['id']
    assert_equal 'xxxxx', response.params['order']['id']
    assert response.test?
  end

  def test_successful_delete_token_response
    @gateway.expects(:ssl_request).returns(successful_delete_token_response)
    response = @gateway.delete_token('9943618748371663')
    assert response.success?
    assert response.test?
  end

  def successful_update_response
    <<-RESPONSE
    {\"repositoryId\":\"TESTusername_0618\",\"response\":{\"gatewayCode\":\"BASIC_VERIFICATION_SUCCESSFUL\"},\"result\":\"SUCCESS\",\"sourceOfFunds\":{\"provided\":{\"card\":{\"brand\":\"AMEX\",\"expiry\":\"0521\",\"fundingMethod\":\"CREDIT\",\"number\":\"345678xxxxx4564\",\"scheme\":\"AMEX\"}},\"type\":\"CARD\"},\"status\":\"VALID\",\"token\":\"9739586533803075\",\"usage\":{\"lastUpdated\":\"2018-06-26T20:26:33.623Z\",\"lastUpdatedBy\":\"TESTusername\",\"lastUsed\":\"2018-06-26T20:22:56.573Z\"},\"verificationStrategy\":\"BASIC\"}
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {\"authorizationResponse\":{\"posData\":\"xxx\",\"transactionIdentifier\":\"AmexTidTest\"},\"gatewayEntryPoint\":\"WEB_SERVICES_API\",\"merchant\":\"TESTusername\",\"order\":{\"amount\":12.0,\"chargeback\":{\"amount\":0,\"currency\":\"USD\"},\"creationTime\":\"2018-06-26T17:33:54.534Z\",\"currency\":\"USD\",\"id\":\"xxxxx\",\"merchantCategoryCode\":\"7399\",\"status\":\"REFUNDED\",\"totalAuthorizedAmount\":12.0,\"totalCapturedAmount\":12.0,\"totalRefundedAmount\":12.0},\"response\":{\"acquirerCode\":\"000\",\"acquirerMessage\":\"Successful request\",\"gatewayCode\":\"APPROVED\"},\"result\":\"SUCCESS\",\"risk\":{\"response\":{\"gatewayCode\":\"NOT_CHECKED\",\"review\":{\"decision\":\"NOT_REQUIRED\"}}},\"sourceOfFunds\":{\"provided\":{\"card\":{\"brand\":\"AMEX\",\"expiry\":{\"month\":\"5\",\"year\":\"21\"},\"fundingMethod\":\"CREDIT\",\"number\":\"345678xxxxx4564\",\"scheme\":\"AMEX\"}},\"token\":\"9739586533803075\",\"type\":\"CARD\"},\"timeOfRecord\":\"2018-06-26T18:18:46.334Z\",\"transaction\":{\"acquirer\":{\"batch\":123,\"id\":\"AMEXGWS\",\"merchantId\":\"username\"},\"amount\":12.0,\"currency\":\"USD\",\"frequency\":\"SINGLE\",\"id\":\"xxxxx\",\"receipt\":\"180626271\",\"source\":\"MOTO\",\"terminal\":\"00001\",\"type\":\"REFUND\"},\"version\":\"47\"}
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {\"authorizationResponse\":{\"posData\":\"xxx\",\"transactionIdentifier\":\"AmexTidTest\"},\"gatewayEntryPoint\":\"AUTO\",\"merchant\":\"TESTusername\",\"order\":{\"amount\":12.0,\"chargeback\":{\"amount\":0,\"currency\":\"USD\"},\"creationTime\":\"2018-06-26T17:33:54.534Z\",\"currency\":\"USD\",\"id\":\"xxxxx\",\"merchantCategoryCode\":\"7399\",\"status\":\"CAPTURED\",\"totalAuthorizedAmount\":12.0,\"totalCapturedAmount\":12.0,\"totalRefundedAmount\":0.0},\"response\":{\"acquirerCode\":\"000\",\"acquirerMessage\":\"Successful request\",\"gatewayCode\":\"APPROVED\"},\"result\":\"SUCCESS\",\"risk\":{\"response\":{\"gatewayCode\":\"NOT_CHECKED\",\"review\":{\"decision\":\"NOT_REQUIRED\"}}},\"sourceOfFunds\":{\"provided\":{\"card\":{\"brand\":\"AMEX\",\"expiry\":{\"month\":\"5\",\"year\":\"21\"},\"fundingMethod\":\"CREDIT\",\"number\":\"345678xxxxx4564\",\"scheme\":\"AMEX\"}},\"token\":\"9739586533803075\",\"type\":\"CARD\"},\"timeOfRecord\":\"2018-06-26T17:33:54.627Z\",\"transaction\":{\"acquirer\":{\"batch\":123,\"id\":\"AMEXGWS\",\"merchantId\":\"username\"},\"amount\":12.0,\"authorizationCode\":\"012299\",\"currency\":\"USD\",\"frequency\":\"SINGLE\",\"id\":\"xxxxx\",\"receipt\":\"180626270\",\"source\":\"MOTO\",\"taxAmount\":0.0,\"terminal\":\"00001\",\"type\":\"CAPTURE\"},\"version\":\"47\"}
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
    {\"repositoryId\":\"TESTusername_0618\",\"response\":{\"gatewayCode\":\"BASIC_VERIFICATION_SUCCESSFUL\"},\"result\":\"SUCCESS\",\"sourceOfFunds\":{\"provided\":{\"card\":{\"brand\":\"VISA\",\"expiry\":\"0818\",\"fundingMethod\":\"CREDIT\",\"issuer\":\"JPMORGAN CHASE BANK, N.A.\",\"number\":\"411111xxxxxx1111\",\"scheme\":\"VISA\"}},\"type\":\"CARD\"},\"status\":\"VALID\",\"token\":\"9855696296999511\",\"usage\":{\"lastUpdated\":\"2018-06-25T21:32:03.013Z\",\"lastUpdatedBy\":\"TESTusername\",\"lastUsed\":\"2018-06-01T18:11:39.423Z\"},\"verificationStrategy\":\"BASIC\"}
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
    {\"gatewayEntryPoint\":\"WEB_SERVICES_API\",\"merchant\":\"TESTusername\",\"order\":{\"amount\":0.0,\"chargeback\":{\"amount\":0,\"currency\":\"USD\"},\"creationTime\":\"2018-06-26T20:08:22.976Z\",\"currency\":\"USD\",\"id\":\"xxxxx\",\"merchantCategoryCode\":\"7399\",\"status\":\"VERIFIED\",\"totalAuthorizedAmount\":0.0,\"totalCapturedAmount\":0.0,\"totalRefundedAmount\":0.0},\"response\":{\"acquirerCode\":\"000\",\"gatewayCode\":\"APPROVED\"},\"result\":\"SUCCESS\",\"risk\":{\"response\":{\"gatewayCode\":\"NOT_CHECKED\",\"review\":{\"decision\":\"NOT_REQUIRED\"}}},\"sourceOfFunds\":{\"provided\":{\"card\":{\"brand\":\"AMEX\",\"expiry\":{\"month\":\"5\",\"year\":\"21\"},\"fundingMethod\":\"CREDIT\",\"number\":\"345678xxxxx4564\",\"scheme\":\"AMEX\"}},\"token\":\"9739586533803075\",\"type\":\"CARD\"},\"timeOfRecord\":\"2018-06-26T20:08:22.976Z\",\"transaction\":{\"acquirer\":{\"id\":\"AMEXGWS\",\"merchantId\":\"username\"},\"amount\":0.0,\"currency\":\"USD\",\"frequency\":\"SINGLE\",\"id\":\"xxxxx\",\"receipt\":\"180626279\",\"source\":\"MOTO\",\"terminal\":\"00001\",\"type\":\"VERIFICATION\"},\"version\":\"47\"}
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {\"authorizationResponse\":{\"posData\":\"xxx\",\"transactionIdentifier\":\"AmexTidTest\"},\"gatewayEntryPoint\":\"WEB_SERVICES_API\",\"merchant\":\"TESTusername\",\"order\":{\"amount\":12.0,\"chargeback\":{\"amount\":0,\"currency\":\"USD\"},\"creationTime\":\"2018-06-26T20:22:56.473Z\",\"currency\":\"USD\",\"id\":\"xxxxx\",\"merchantCategoryCode\":\"7399\",\"status\":\"CANCELLED\",\"totalAuthorizedAmount\":0.0,\"totalCapturedAmount\":0.0,\"totalRefundedAmount\":0.0},\"response\":{\"acquirerCode\":\"000\",\"acquirerMessage\":\"Successful request\",\"gatewayCode\":\"APPROVED\"},\"result\":\"SUCCESS\",\"risk\":{\"response\":{\"gatewayCode\":\"NOT_CHECKED\",\"review\":{\"decision\":\"NOT_REQUIRED\"}}},\"sourceOfFunds\":{\"provided\":{\"card\":{\"brand\":\"AMEX\",\"expiry\":{\"month\":\"5\",\"year\":\"21\"},\"fundingMethod\":\"CREDIT\",\"number\":\"345678xxxxx4564\",\"scheme\":\"AMEX\"}},\"token\":\"9739586533803075\",\"type\":\"CARD\"},\"timeOfRecord\":\"2018-06-27T15:14:20.782Z\",\"transaction\":{\"acquirer\":{\"batch\":124,\"id\":\"AMEXGWS\",\"merchantId\":\"username\"},\"amount\":12.0,\"currency\":\"USD\",\"frequency\":\"SINGLE\",\"id\":\"newtransactionid\",\"receipt\":\"180627352\",\"source\":\"MOTO\",\"targetTransactionId\":\"xxxxx\",\"taxAmount\":0.0,\"terminal\":\"00001\",\"type\":\"VOID_CAPTURE\"},\"version\":\"47\"}
    RESPONSE
  end

  def successful_find_transaction_response
    <<-RESPONSE
    {\"authorizationResponse\":{\"posData\":\"1605S0100130\",\"transactionIdentifier\":\"AmexTidTest\"},\"gatewayEntryPoint\":\"AUTO\",\"merchant\":\"TESTusername\",\"order\":{\"amount\":12.0,\"creationTime\":\"2018-07-26T13:56:30.317Z\",\"currency\":\"USD\",\"id\":\"xxxxx\",\"status\":\"CAPTURED\",\"totalAuthorizedAmount\":12.0,\"totalCapturedAmount\":12.0,\"totalRefundedAmount\":0.0},\"response\":{\"acquirerCode\":\"000\",\"acquirerMessage\":\"Successful request\",\"gatewayCode\":\"APPROVED\"},\"result\":\"SUCCESS\",\"risk\":{\"response\":{\"gatewayCode\":\"NOT_CHECKED\",\"review\":{\"decision\":\"NOT_REQUIRED\"}}},\"sourceOfFunds\":{\"provided\":{\"card\":{\"brand\":\"AMEX\",\"expiry\":{\"month\":\"5\",\"year\":\"21\"},\"fundingMethod\":\"CREDIT\",\"number\":\"345678xxxxx4564\",\"scheme\":\"AMEX\"}},\"token\":\"9943618748371663\",\"type\":\"CARD\"},\"timeOfRecord\":\"2018-07-26T13:56:30.348Z\",\"transaction\":{\"acquirer\":{\"batch\":153,\"id\":\"AMEXGWS\",\"merchantId\":\"xxxxxx\"},\"amount\":12.0,\"authorizationCode\":\"001813\",\"currency\":\"USD\",\"frequency\":\"SINGLE\",\"id\":\"xxxxx\",\"receipt\":\"1807261106\",\"source\":\"MOTO\",\"terminal\":\"00001\",\"type\":\"CAPTURE\"},\"version\":\"40\"}
    RESPONSE
  end

  def successful_delete_token_response
    <<-RESPONSE
    {\"result\":\"SUCCESS\"}
    RESPONSE
  end

  def build_response(response)
    response = JSON.parse(response)
    Response.new(response['result'],
                 response['response'],
                 response,
                 authorization: response['authorizationResponse'],
                 test: true,
                 error_code: response['result'])
  end
end
