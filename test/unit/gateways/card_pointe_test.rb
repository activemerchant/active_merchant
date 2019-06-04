require 'test_helper'

class CardPointeTest < Test::Unit::TestCase
  def setup
    @gateway = CardPointeGateway.new(username: 'login', password: 'password', merchid: 'merchid123')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
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

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '155949252515', response.authorization
    assert response.test?
  end

  def test_failed_authorize
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_capture
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, '155949252515', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_refund
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(@amount, '155949252515', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_void
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert response.params['amount'] = '0.00'
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '14231315860667805749', response.params['profileid']
    assert_equal '1', response.params['acctid']
  end

  def test_successful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)

    response = @gateway.update('13752085791902707729/1', @credit_card, @options)
    assert_success response
    assert_equal '13752085791902707729', response.params['profileid']
    assert_equal '1', response.params['acctid']
  end

  def test_successful_unstore
    @gateway.expects(:ssl_request).returns(successful_unstore_response)

    response = @gateway.unstore('13752085791902707729/1', @options)
    assert_success response
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
        test/remote/gateways/remote_card_pointe_test.rb \
        -n test_successful_purchase
    )
    <<-RESPONSE
    {\"amount\":\"1.00\",\"resptext\":\"Approval\",\"commcard\":\"   \",\"cvvresp\":\"X\",\"respcode\":\"00\",\"batchid\":\"1900942457\",\"avsresp\":\" \",\"entrymode\":\"Keyed\",\"merchid\":\"496160873888\",\"token\":\"9605849968916668\",\"authcode\":\"PPS935\",\"respproc\":\"FNOR\",\"bintype\":\"\",\"retref\":\"155748247575\",\"respstat\":\"A\",\"account\":\"9605849968916668\"}
    RESPONSE
  end

  def failed_purchase_response
  end

  def successful_authorize_response
    <<-RESPONSE
      {\"amount\":\"1.00\",\"resptext\":\"Approval\",\"commcard\":\" C \",\"cvvresp\":\"X\",\"respcode\":\"00\",\"avsresp\":\" \",\"entrymode\":\"Keyed\",\"merchid\":\"496160873888\",\"token\":\"9422925921134242\",\"authcode\":\"PPS915\",\"respproc\":\"FNOR\",\"bintype\":\"\",\"retref\":\"155949252515\",\"respstat\":\"A\",\"account\":\"9422925921134242\"}
    RESPONSE
  end

  def failed_authorize_response
  end

  def successful_capture_response
    <<-RESPONSE
      {\"amount\":\"1.00\",\"resptext\":\"Approval\",\"setlstat\":\"Queued for Capture\",\"commcard\":\" C \",\"respcode\":\"00\",\"batchid\":\"1900942460\",\"merchid\":\"496160873888\",\"token\":\"9422925921134242\",\"authcode\":\"PPS540\",\"respproc\":\"FNOR\",\"retref\":\"155859171266\",\"respstat\":\"A\",\"account\":\"9422925921134242\"}
    RESPONSE
  end

  def failed_capture_response
  end

  def successful_refund_response
    <<-RESPONSE
      {\"respproc\":\"PPS\",\"amount\":\"1.00\",\"resptext\":\"Approval\",\"retref\":\"155671152780\",\"respstat\":\"A\",\"respcode\":\"00\",\"merchid\":\"496160873888\"}
    RESPONSE
  end

  def failed_refund_response
  end

  def successful_void_response
    <<-RESPONSE
      {\"authcode\":\"REVERS\",\"respproc\":\"FNOR\",\"amount\":\"0.00\",\"resptext\":\"Approval\",\"currency\":\"USD\",\"retref\":\"155061253175\",\"respstat\":\"A\",\"respcode\":\"00\",\"merchid\":\"496160873888\"}
    RESPONSE
  end

  def failed_void_response
  end

  def successful_verify_response
    <<-RESPONSE
      {\"amount\":\"0.00\",\"resptext\":\"Approval\",\"commcard\":\" C \",\"cvvresp\":\"X\",\"respcode\":\"00\",\"avsresp\":\"Z\",\"entrymode\":\"Keyed\",\"merchid\":\"496160873888\",\"token\":\"9422925921134242\",\"authcode\":\"PPS670\",\"respproc\":\"FNOR\",\"bintype\":\"\",\"retref\":\"155098253457\",\"respstat\":\"A\",\"account\":\"9422925921134242\"}
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
      {\"country\":\"CA\",\"address\":\"456 My Street\",\"resptext\":\"Profile Saved\",\"city\":\"Ottawa\",\"acctid\":\"1\",\"respcode\":\"09\",\"defaultacct\":\"Y\",\"accttype\":\"VISA\",\"token\":\"9422925921134242\",\"respproc\":\"PPS\",\"profileid\":\"14231315860667805749\",\"auoptout\":\"N\",\"postal\":\"K1C2N6\",\"expiry\":\"0920\",\"region\":\"ON\",\"respstat\":\"A\"}
    RESPONSE
  end

  def successful_update_response
    <<-RESPONSE
      {\"country\":\"CA\",\"address\":\"456 My Street\",\"resptext\":\"Profile Saved\",\"city\":\"Ottawa\",\"acctid\":\"1\",\"respcode\":\"09\",\"defaultacct\":\"Y\",\"accttype\":\"VISA\",\"token\":\"9477257372660010\",\"respproc\":\"PPS\",\"profileid\":\"13752085791902707729\",\"auoptout\":\"N\",\"postal\":\"K1C2N6\",\"expiry\":\"0920\",\"region\":\"ON\",\"respstat\":\"A\"}
    RESPONSE
  end

  def successful_unstore_response
    <<-RESPONSE
      {\"respproc\":\"PPS\",\"resptext\":\"Profile Deleted\",\"respstat\":\"A\",\"respcode\":\"08\"}
    RESPONSE
  end
end
