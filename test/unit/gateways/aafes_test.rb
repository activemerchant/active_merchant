require 'test_helper'

class AafesTest < Test::Unit::TestCase
  def setup
    @gateway = AafesGateway.new(identity_uuid: 'identity_uuid')

    # Amount field must be passed in as a decimal   
    @amount = 100.00
    @metadata = {
      :zip => 75236,
      :expiration => 2210
    }
    
    @milstar_card = ActiveMerchant::Billing::PaymentToken.new(
      '900PRPYIGCWDS4O2615',
      @metadata
    )

    #TODO: The RRN needs to be unique everytime - the RRN needs to be a base-64 12 character long string
    @options = {
      order_id: 'ONP3951033',
      billing_address: address,
      description: 'Store Purchase',
      plan_number: 10001,
      transaction_id: 6750,
      rrn: 'RRNPG1685262',
      term_id: 20,
      customer_id: 45017632990
    }
  end

  def test_successful_purchase_with_milstar_card
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @milstar_card, @options)
    # assert_success response

    # assert_equal 'REPLACE', response.authorization
    # assert response.test?
  end

  # def test_failed_purchase
  # end

  # def test_successful_authorize
  # end

  # def test_failed_authorize
  # end

  # def test_successful_capture
  # end

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
  #   # assert @gateway.supports_scrubbing?
  #   # assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
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
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_aafes_test.rb \
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
