require 'test_helper'

class RemotePacNetRavenGatewayTest < Test::Unit::TestCase
  def setup
    @gateway = PacNetRavenGateway.new(fixtures(:raven_pac_net))

    @amount = 100
    @credit_card = credit_card('4000000000000028')
    @declined_card = credit_card('5100000000000040')

    @options = {
      billing_address: address
    }
  end

  def test_successful_purchase
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.params['ApprovalCode']
    assert purchase.params['TrackingNumber']
    assert_nil purchase.params['ErrorCode']
    assert_equal 'Approved', purchase.params['Status']
    assert_equal 'ok', purchase.params['RequestResult']
    assert_nil purchase.params['Message']
    assert_equal 'This transaction has been approved', purchase.message
  end

  def test_invalid_credit_card_number_purchese
    @credit_card = credit_card('0000')
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure purchase
    assert_nil purchase.params['ApprovalCode']
    assert purchase.params['TrackingNumber']
    assert_equal 'invalid:cardNumber', purchase.params['ErrorCode']
    assert_equal 'Invalid:CardNumber', purchase.params['Status']
    assert_equal 'ok', purchase.params['RequestResult']
    assert_equal "Error processing transaction because CardNumber \"0000\" is not between 12 and 19 in length.", purchase.params['Message']
  end

  def test_expired_credit_card_purchese
    @credit_card.month = 9
    @credit_card.year = 2012
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure purchase
    assert_nil purchase.params['ApprovalCode']
    assert purchase.params['TrackingNumber']
    assert_equal 'invalid:CustomerCardExpiryDate', purchase.params['ErrorCode']
    assert_equal 'Invalid:CustomerCardExpiryDate', purchase.params['Status']
    assert_equal 'ok', purchase.params['RequestResult']
    assert_equal "Invalid because the card expiry date (mmyy) \"0912\" is not a date in the future", purchase.params['Message']
  end

  def test_declined_purchese
    assert purchase = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure purchase
    assert_equal 'RepeatDeclined', purchase.message
  end

  def test_successful_authorization
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.params['ApprovalCode']
    assert auth.params['TrackingNumber']
    assert_nil auth.params['ErrorCode']
    assert_nil auth.params['Message']
    assert_equal 'Approved', auth.params['Status']
    assert_equal 'ok', auth.params['RequestResult']
    assert_equal 'This transaction has been approved', auth.message
  end

  def test_invalid_credit_card_number_authorization
    @credit_card = credit_card('0000')
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
    assert_nil auth.params['ApprovalCode']
    assert auth.params['TrackingNumber']
    assert_equal 'invalid:cardNumber', auth.params['ErrorCode']
    assert_equal 'Invalid:CardNumber', auth.params['Status']
    assert_equal 'ok', auth.params['RequestResult']
    assert_equal "Error processing transaction because CardNumber \"0000\" is not between 12 and 19 in length.", auth.params['Message']
  end

  def test_expired_credit_card_authorization
    @credit_card.month = 9
    @credit_card.year = 2012
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
    assert_nil auth.params['ApprovalCode']
    assert auth.params['TrackingNumber']
    assert_equal 'invalid:CustomerCardExpiryDate', auth.params['ErrorCode']
    assert_equal 'Invalid:CustomerCardExpiryDate', auth.params['Status']
    assert_equal 'ok', auth.params['RequestResult']
    assert_equal "Invalid because the card expiry date (mmyy) \"0912\" is not a date in the future", auth.params['Message']
  end

  def test_declined_authorization
    assert auth = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure auth
    assert_equal 'RepeatDeclined', auth.message
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert refund.params['ApprovalCode']
    assert refund.params['TrackingNumber']
    assert_nil refund.params['ErrorCode']
    assert_equal 'Approved', refund.params['Status']
    assert_equal 'ok', refund.params['RequestResult']
    assert_nil refund.params['Message']
    assert_equal 'This transaction has been approved', refund.message
  end

  def test_amount_greater_than_original_amount_refund
    assert purchase = @gateway.purchase(100, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(200, purchase.authorization)
    assert_failure refund
    assert_nil refund.params['ApprovalCode']
    assert refund.params['TrackingNumber']
    assert_equal 'invalid:RefundAmountGreaterThanOriginalAmount', refund.params['ErrorCode']
    assert_equal 'Invalid:RefundAmountGreaterThanOriginalAmount', refund.params['Status']
    assert_equal 'ok', refund.params['RequestResult']
    assert_equal "Invalid because the payment amount cannot be greater than the original charge.", refund.params['Message']
    assert_equal 'Invalid because the payment amount cannot be greater than the original charge.', refund.message
  end

  def test_purchase_and_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert void = @gateway.void(purchase.authorization, {:pymt_type =>  purchase.params['PymtType']})
    assert_success void
    assert void.params['ApprovalCode']
    assert void.params['TrackingNumber']
    assert_nil void.params['ErrorCode']
    assert_equal 'ok', void.params['RequestResult']
    assert_nil void.params['Message']
    assert_equal 'Voided', void.params['Status']
    assert_equal "This transaction has been voided", void.message
  end

  def test_authorize_and_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert void = @gateway.void(auth.authorization)
    assert_failure void
    assert void.params['ApprovalCode']
    assert void.params['TrackingNumber']
    assert_equal 'error:canNotBeVoided', void.params['ErrorCode']
    assert_equal 'ok', void.params['RequestResult']
    assert_equal "Error processing transaction because the payment may not be voided.", void.params['Message']
    assert_equal 'Approved', void.params['Status']
    assert_equal "Error processing transaction because the payment may not be voided.", void.message
  end

  def test_authorize_capture_and_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert void = @gateway.void(capture.authorization, {:pymt_type =>  capture.params['PymtType']})
    assert_failure void
    assert void.params['ApprovalCode']
    assert void.params['TrackingNumber']
    assert_equal 'error:canNotBeVoided', void.params['ErrorCode']
    assert_equal 'ok', void.params['RequestResult']
    assert_equal "Error processing transaction because the payment may not be voided.", void.params['Message']
    assert_equal 'Approved', void.params['Status']
    assert_equal "Error processing transaction because the payment may not be voided.", void.message
  end

  def test_successful_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert capture.params['ApprovalCode']
    assert capture.params['TrackingNumber']
    assert_nil capture.params['ErrorCode']
    assert_equal 'Approved', capture.params['Status']
    assert_equal 'ok', capture.params['RequestResult']
    assert_nil capture.params['Message']
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_invalid_preauth_number_capture
    assert capture = @gateway.capture(@amount, '')
    assert_failure capture
    assert_nil capture.params['ApprovalCode']
    assert capture.params['TrackingNumber']
    assert_equal 'invalid:PreAuthNumber', capture.params['ErrorCode']
    assert_equal 'Invalid:PreauthNumber', capture.params['Status']
    assert_equal 'ok', capture.params['RequestResult']
    assert_equal "Error processing transaction because the pre-auth number \"0\" does not correspond to a pre-existing payment.", capture.params['Message']
    assert capture.message.include?('Error processing transaction because the pre-auth number')
  end

  def test_insufficient_preauth_amount_capture
    auth = @gateway.authorize(100, @credit_card, @options)
    assert capture = @gateway.capture(200, auth.authorization)
    assert_failure capture
    assert_nil capture.params['ApprovalCode']
    assert capture.params['TrackingNumber']
    assert_equal 'rejected:PreauthAmountInsufficient', capture.params['ErrorCode']
    assert_equal 'Rejected:PreauthAmountInsufficient', capture.params['Status']
    assert_equal 'ok', capture.params['RequestResult']
    assert_equal "Invalid because the preauthorization amount 100 is insufficient", capture.params['Message']
    assert_equal 'Invalid because the preauthorization amount 100 is insufficient', capture.message
  end
end
