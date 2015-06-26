require 'test_helper'

class MercuryEncryptedTest < Test::Unit::TestCase
  def setup
    @gateway = MercuryEncryptedGateway.new(some_credential: 'login', another_credential: 'password')
    @credit_card = "%B4003000050006781^TEST/MPS^19120000000000000?;4003000050006781=19120000000000000000?|0600|7EFC7CD505B74493DC4B01B8506E7B927B947ED2EDBF34E8DB470909238BC1ABAB007BFBB5395A730A48BFC2CD021260|9EF440CE67CAD230A307B5581F063AB8B8971E32F26F7CC64C2C15A274B8BD0E220334C8E964E719||61401000|C95DAB4041E723946C54A63066108634DD24A93E587BDDCF49A0459C5649464B6ABFE8CB714AEB4B3B7F7F803E22548B7E23292200F92D74|B29C0D1120214AA|8BCE84619C673F4F|9012090B29C0D1000003|D860||1000"
    @amount = 100

    @options = {
      invoice_no: "1",
      ref_no: "1",
      memo: "MPS Example JSON v1.0"
    }
  end

  def test_successful_purchase
#    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response.authorization.present?
    assert response.test?
  end

  def test_failed_purchase
#    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    @credit_card = "%B4003000050006781^TEST/MPS^19120000000000000?;4003000050006781=19120000000000000000?|0600|7EFC7CD505B74493DC4B01B8506E7B927B947ED2EDBF34E8DB470909238BC1ABAB007BFBB5395A730A48BFC2CD021260|9EF440CE67CAD230A307B5581F063AB8B8971E32F26F7CC64C2C15A274B8ABD0E223334C8E964E719||61401000|C95DAB4041E723946C54A63066108634DD24A93E587BDDCF49A0459C5649464B6ABFE8CB714AEB4B3B7F7F803E22548B7E23292200F92D74|B29C0D1120214AA|8BCE84619C673F4F|9012090B29C0D1000003|D860||1000"
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

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
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_mercury_encrypted_test.rb \
        -n test_successful_purchase
    )
  end

  def failed_purchase_response
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
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
