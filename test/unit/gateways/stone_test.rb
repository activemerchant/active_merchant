require 'test_helper'

class StoneTest < Test::Unit::TestCase
  def setup
    @gateway = StoneGateway.new(merchant_key: 'dummy')

    @credit_card = credit_card('4000100011112224')

    @amount = 10000
    @declined_amount = 150100
    @timeout_amount = 105050

    @options = {
      order_id: '123123'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '56cd29e0-e9bb-41c5-b77a-53013fa74cf5', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_response)

    response = StoneResponse.new(successful_response)

    assert capture = @gateway.capture(@amount, response)
    assert_success capture
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_response)

    response = StoneResponse.new(successful_response)

    assert capture = @gateway.capture(@amount, response)
    assert_failure capture
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_response)

    response = StoneResponse.new(successful_response)

    assert refund = @gateway.refund(@amount, response)
    assert_success refund
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_response)

    response = StoneResponse.new(successful_response)

    assert refund = @gateway.refund(@amount, response)
    assert_failure refund
  end

  private
  def successful_response
    "{\"ErrorReport\":null,\"InternalTime\":209,\"MerchantKey\":\"dummy\",\"RequestKey\":\"1e46c866-2902-4d4b-b74e-0570a42c50f0\",\"BoletoTransactionResultCollection\":[],\"BuyerKey\":\"00000000-0000-0000-0000-000000000000\",\"CreditCardTransactionResultCollection\":[{\"AcquirerMessage\":\"Simulator|Transa\xC3\xA7\xC3\xA3o de simula\xC3\xA7\xC3\xA3o autorizada com sucesso\",\"AcquirerName\":\"Simulator\",\"AcquirerReturnCode\":\"0\",\"AffiliationCode\":\"000000000\",\"AmountInCents\":10000,\"AuthorizationCode\":\"654149\",\"AuthorizedAmountInCents\":10000,\"CapturedAmountInCents\":10000,\"CapturedDate\":\"2016-04-21T21:57:22\",\"CreditCard\":{\"CreditCardBrand\":\"Visa\",\"InstantBuyKey\":\"63c1eb62-aab9-4036-a4a8-a6229a031be2\",\"IsExpiredCreditCard\":false,\"MaskedCreditCardNumber\":\"400010****2224\"},\"CreditCardOperation\":\"AuthAndCapture\",\"CreditCardTransactionStatus\":\"Captured\",\"DueDate\":null,\"EstablishmentCode\":null,\"ExternalTime\":0,\"PaymentMethodName\":\"Simulator\",\"RefundedAmountInCents\":null,\"Success\":true,\"TransactionIdentifier\":\"843672\",\"TransactionKey\":\"56cd29e0-e9bb-41c5-b77a-53013fa74cf5\",\"TransactionKeyToAcquirer\":\"56cd29e0e9bb41c5\",\"TransactionReference\":\"123123\",\"UniqueSequentialNumber\":\"243104\",\"VoidedAmountInCents\":null}],\"OrderResult\":{\"CreateDate\":\"2016-04-21T21:57:22\",\"OrderKey\":\"106dff3d-9436-43ff-b33e-3d354f851083\",\"OrderReference\":\"a70438e4\"}}"
  end

  def failed_response
    "{\"ErrorReport\":null,\"InternalTime\":578,\"MerchantKey\":\"8a2dd57f-1ed9-4153-b4ce-69683efadad5\",\"RequestKey\":\"845e40e9-99f0-460b-844a-86b8fe85e31f\",\"BoletoTransactionResultCollection\":[],\"BuyerKey\":\"00000000-0000-0000-0000-000000000000\",\"CreditCardTransactionResultCollection\":[{\"AcquirerMessage\":\"Simulator|Transa\xC3\xA7\xC3\xA3o de simula\xC3\xA7\xC3\xA3o n\xC3\xA3o autorizada\",\"AcquirerName\":\"Simulator\",\"AcquirerReturnCode\":\"1\",\"AffiliationCode\":\"000000000\",\"AmountInCents\":150100,\"AuthorizationCode\":\"\",\"AuthorizedAmountInCents\":null,\"CapturedAmountInCents\":null,\"CapturedDate\":null,\"CreditCard\":{\"CreditCardBrand\":\"Visa\",\"InstantBuyKey\":\"63c1eb62-aab9-4036-a4a8-a6229a031be2\",\"IsExpiredCreditCard\":false,\"MaskedCreditCardNumber\":\"400010****2224\"},\"CreditCardOperation\":\"AuthAndCapture\",\"CreditCardTransactionStatus\":\"NotAuthorized\",\"DueDate\":null,\"EstablishmentCode\":null,\"ExternalTime\":0,\"PaymentMethodName\":\"Simulator\",\"RefundedAmountInCents\":null,\"Success\":false,\"TransactionIdentifier\":\"\",\"TransactionKey\":\"9b473da4-313d-4e1a-92ed-eb4469ccb928\",\"TransactionKeyToAcquirer\":\"9b473da4313d4e1a\",\"TransactionReference\":\"123123\",\"UniqueSequentialNumber\":\"\",\"VoidedAmountInCents\":null}],\"OrderResult\":{\"CreateDate\":\"2016-05-03T21:13:35\",\"OrderKey\":\"0887b505-b232-423d-96b1-c684dcc179ef\",\"OrderReference\":\"5be2971a\"}}"
  end
end
