require 'test_helper'

class RemoteMercuryEncryptedTest < Test::Unit::TestCase
  def setup
    @gateway = MercuryEncryptedGateway.new(fixtures(:mercury_encrypted))
    @amount = 100
    @swiper_output = "%B4003000050006781^TEST/MPS^19120000000000000?;4003000050006781=19120000000000000000?|0600|7EFC7CD505B74493DC4B01B8506E7B927B947ED2EDBF34E8DB470909238BC1ABAB007BFBB5395A730A48BFC2CD021260|9EF440CE67CAD230A307B5581F063AB8B8971E32F26F7CC64C2C15A274B8BD0E220334C8E964E719||61401000|C95DAB4041E723946C54A63066108634DD24A93E587BDDCF49A0459C5649464B6ABFE8CB714AEB4B3B7F7F803E22548B7E23292200F92D74|B29C0D1120214AA|8BCE84619C673F4F|9012090B29C0D1000003|D860||1000"
    @declined_card = credit_card('4000300011112220')
    @options = {
      invoice_no: "1",
      ref_no: "1",
      description: "ActiveMerchant Mercury E2E Remote Test",
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success response

    assert response.authorization.present?
    assert_equal "1.00", response.params["Purchase"]
    assert response.test?
  end

  def test_failed_purchase
    pending
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @swiper_output, @options)
    assert_success auth
    assert_equal "PreAuth", auth.params["TranCode"]
    assert_equal "1.00", auth.params["Authorize"]

    opts = @options.merge({ auth_code: auth.params["AuthCode"], acq_ref_data: auth.params["AcqRefData"] })
    assert capture = @gateway.capture(@amount, auth.authorization, opts)
    assert_success capture
    assert_equal "Captured", capture.params["CaptureStatus"]
    assert_equal "1.00", capture.params["Authorize"]
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'REPLACE WITH FAILED AUTHORIZE MESSAGE', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @swiper_output, @options)
    assert_success auth

    opts = @options.merge({ auth_code: auth.params["AuthCode"], acq_ref_data: auth.params["AcqRefData"] })
    assert capture = @gateway.capture(@amount-1, auth.authorization, opts)
    assert_success capture
    assert_equal "Captured", capture.params["CaptureStatus"]
    assert_equal "0.99", capture.params["Authorize"]
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED CAPTURE MESSAGE', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal "Return", refund.params["TranCode"]
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options)
    assert_success refund
    assert_equal "Return", refund.params["TranCode"]
    assert_equal "0.99", refund.params["Purchase"]
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
  end

  def test_successful_void
    sale = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success sale

    opts = @options.merge({
        auth_code: sale.params["AuthCode"],
        ref_no: sale.params["RefNo"],
        purchase: @amount })
    assert void = @gateway.void(sale.authorization, opts)
    assert_success void
    assert_equal "VOIDED", void.params["AuthCode"]
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  end

  def test_invalid_login
    gateway = MercuryEncryptedGateway.new(login: '', password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{REPLACE WITH FAILED LOGIN MESSAGE}, response.message
  end
end
