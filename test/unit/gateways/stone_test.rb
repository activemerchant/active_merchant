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
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '56cd29e0-e9bb-41c5-b77a-53013fa74cf5', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    auth_params = {
      request_key: '0000',
      credit_card_transaction_result_collection: [{
        transaction_key: '123123',
        transaction_reference: '123123'
      }],
      order_result: {
        order_key: '123123'
      }
    }

    assert capture = @gateway.capture(@amount, auth_params)
    assert_success capture
    assert_equal 'Transação de simulação capturada com sucesso', capture.message
  end

  # def test_failed_capture
  # end

  # def test_successful_refund
  # end

  # def test_failed_refund
  # end

  # def test_successful_void
  # end

  # def test_failed_void
  # end

  # def test_successful_verify
  # end

  # def test_successful_verify_with_failed_void
  # end

  # def test_failed_verify
  # end

  # def test_scrub
  #   assert @gateway.supports_scrubbing?
  #   assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  # end

  private

  def pre_scrubbed
    %q(
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    )
  end

  def post_scrubbed
    %q(
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    )
  end

  def successful_purchase_response
    "{\"ErrorReport\":null,\"InternalTime\":209,\"MerchantKey\":\"dummy\",\"RequestKey\":\"1e46c866-2902-4d4b-b74e-0570a42c50f0\",\"BoletoTransactionResultCollection\":[],\"BuyerKey\":\"00000000-0000-0000-0000-000000000000\",\"CreditCardTransactionResultCollection\":[{\"AcquirerMessage\":\"Simulator|Transa\xC3\xA7\xC3\xA3o de simula\xC3\xA7\xC3\xA3o autorizada com sucesso\",\"AcquirerName\":\"Simulator\",\"AcquirerReturnCode\":\"0\",\"AffiliationCode\":\"000000000\",\"AmountInCents\":10000,\"AuthorizationCode\":\"654149\",\"AuthorizedAmountInCents\":10000,\"CapturedAmountInCents\":10000,\"CapturedDate\":\"2016-04-21T21:57:22\",\"CreditCard\":{\"CreditCardBrand\":\"Visa\",\"InstantBuyKey\":\"63c1eb62-aab9-4036-a4a8-a6229a031be2\",\"IsExpiredCreditCard\":false,\"MaskedCreditCardNumber\":\"400010****2224\"},\"CreditCardOperation\":\"AuthAndCapture\",\"CreditCardTransactionStatus\":\"Captured\",\"DueDate\":null,\"EstablishmentCode\":null,\"ExternalTime\":0,\"PaymentMethodName\":\"Simulator\",\"RefundedAmountInCents\":null,\"Success\":true,\"TransactionIdentifier\":\"843672\",\"TransactionKey\":\"56cd29e0-e9bb-41c5-b77a-53013fa74cf5\",\"TransactionKeyToAcquirer\":\"56cd29e0e9bb41c5\",\"TransactionReference\":\"123123\",\"UniqueSequentialNumber\":\"243104\",\"VoidedAmountInCents\":null}],\"OrderResult\":{\"CreateDate\":\"2016-04-21T21:57:22\",\"OrderKey\":\"106dff3d-9436-43ff-b33e-3d354f851083\",\"OrderReference\":\"a70438e4\"}}"
  end

  def failed_purchase_response
    "{\"ErrorReport\":null,\"InternalTime\":578,\"MerchantKey\":\"8a2dd57f-1ed9-4153-b4ce-69683efadad5\",\"RequestKey\":\"845e40e9-99f0-460b-844a-86b8fe85e31f\",\"BoletoTransactionResultCollection\":[],\"BuyerKey\":\"00000000-0000-0000-0000-000000000000\",\"CreditCardTransactionResultCollection\":[{\"AcquirerMessage\":\"Simulator|Transa\xC3\xA7\xC3\xA3o de simula\xC3\xA7\xC3\xA3o n\xC3\xA3o autorizada\",\"AcquirerName\":\"Simulator\",\"AcquirerReturnCode\":\"1\",\"AffiliationCode\":\"000000000\",\"AmountInCents\":150100,\"AuthorizationCode\":\"\",\"AuthorizedAmountInCents\":null,\"CapturedAmountInCents\":null,\"CapturedDate\":null,\"CreditCard\":{\"CreditCardBrand\":\"Visa\",\"InstantBuyKey\":\"63c1eb62-aab9-4036-a4a8-a6229a031be2\",\"IsExpiredCreditCard\":false,\"MaskedCreditCardNumber\":\"400010****2224\"},\"CreditCardOperation\":\"AuthAndCapture\",\"CreditCardTransactionStatus\":\"NotAuthorized\",\"DueDate\":null,\"EstablishmentCode\":null,\"ExternalTime\":0,\"PaymentMethodName\":\"Simulator\",\"RefundedAmountInCents\":null,\"Success\":false,\"TransactionIdentifier\":\"\",\"TransactionKey\":\"9b473da4-313d-4e1a-92ed-eb4469ccb928\",\"TransactionKeyToAcquirer\":\"9b473da4313d4e1a\",\"TransactionReference\":\"123123\",\"UniqueSequentialNumber\":\"\",\"VoidedAmountInCents\":null}],\"OrderResult\":{\"CreateDate\":\"2016-05-03T21:13:35\",\"OrderKey\":\"0887b505-b232-423d-96b1-c684dcc179ef\",\"OrderReference\":\"5be2971a\"}}"
  end

  def successful_authorize_response
    "{\"ErrorReport\":null,\"InternalTime\":359,\"MerchantKey\":\"8a2dd57f-1ed9-4153-b4ce-69683efadad5\",\"RequestKey\":\"9c49d396-5dc4-4c7c-8b54-f2a5acf19fb8\",\"BoletoTransactionResultCollection\":[],\"BuyerKey\":\"00000000-0000-0000-0000-000000000000\",\"CreditCardTransactionResultCollection\":[{\"AcquirerMessage\":\"Simulator|Transa\xC3\xA7\xC3\xA3o de simula\xC3\xA7\xC3\xA3o autorizada com sucesso\",\"AcquirerName\":\"Simulator\",\"AcquirerReturnCode\":\"0\",\"AffiliationCode\":\"000000000\",\"AmountInCents\":10000,\"AuthorizationCode\":\"728419\",\"AuthorizedAmountInCents\":10000,\"CapturedAmountInCents\":null,\"CapturedDate\":null,\"CreditCard\":{\"CreditCardBrand\":\"Visa\",\"InstantBuyKey\":\"63c1eb62-aab9-4036-a4a8-a6229a031be2\",\"IsExpiredCreditCard\":false,\"MaskedCreditCardNumber\":\"400010****2224\"},\"CreditCardOperation\":\"AuthOnly\",\"CreditCardTransactionStatus\":\"AuthorizedPendingCapture\",\"DueDate\":null,\"EstablishmentCode\":null,\"ExternalTime\":0,\"PaymentMethodName\":\"Simulator\",\"RefundedAmountInCents\":null,\"Success\":true,\"TransactionIdentifier\":\"175996\",\"TransactionKey\":\"05a0bfcc-4657-4790-9c43-9400770076a6\",\"TransactionKeyToAcquirer\":\"05a0bfcc46574790\",\"TransactionReference\":\"123123\",\"UniqueSequentialNumber\":\"14948\",\"VoidedAmountInCents\":null}],\"OrderResult\":{\"CreateDate\":\"2016-05-03T21:18:31\",\"OrderKey\":\"6ad53681-24e7-4162-97af-d921552451c9\",\"OrderReference\":\"5c1b61f0\"}}"
  end

  def successful_capture_response
    "{\"ErrorReport\":null,\"InternalTime\":187,\"MerchantKey\":\"8a2dd57f-1ed9-4153-b4ce-69683efadad5\",\"RequestKey\":\"d632c4a8-8787-4401-9b0e-52ced4da22f4\",\"CreditCardTransactionResultCollection\":[{\"AcquirerMessage\":\"Simulator|Transa\xC3\xA7\xC3\xA3o de simula\xC3\xA7\xC3\xA3o capturada com sucesso\",\"AcquirerName\":\"Simulator\",\"AcquirerReturnCode\":\"0\",\"AffiliationCode\":\"000000000\",\"AmountInCents\":10000,\"AuthorizationCode\":\"745784\",\"AuthorizedAmountInCents\":10000,\"CapturedAmountInCents\":10000,\"CapturedDate\":\"2016-05-03T21:22:08\",\"CreditCard\":{\"CreditCardBrand\":\"Visa\",\"InstantBuyKey\":\"63c1eb62-aab9-4036-a4a8-a6229a031be2\",\"IsExpiredCreditCard\":false,\"MaskedCreditCardNumber\":\"400010****2224\"},\"CreditCardOperation\":\"AuthOnly\",\"CreditCardTransactionStatus\":\"Captured\",\"DueDate\":null,\"EstablishmentCode\":null,\"ExternalTime\":0,\"PaymentMethodName\":\"Simulator\",\"RefundedAmountInCents\":null,\"Success\":true,\"TransactionIdentifier\":\"833684\",\"TransactionKey\":\"312c173e-df9e-49cb-8537-4525fb1d12a6\",\"TransactionKeyToAcquirer\":\"312c173edf9e49cb\",\"TransactionReference\":\"123123\",\"UniqueSequentialNumber\":\"864134\",\"VoidedAmountInCents\":null}]}"
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
