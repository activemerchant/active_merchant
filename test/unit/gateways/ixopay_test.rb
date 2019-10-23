require 'test_helper'

class IxopayTest < Test::Unit::TestCase
  def setup
    @gateway = IxopayGateway.new(username: 'username', password: 'password', secret: 'secret')

    @declined_card = credit_card('4000300011112220')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      ip: '192.168.1.1'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'FINISHED', response.message
    assert_equal 'b2bef23a30b537b90fbe|20191016-b2bef23a30b537b90fbe', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'The transaction was declined', response.message
    assert_equal '2003', response.error_code
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
    # assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
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
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>true</success>
        <referenceId>b2bef23a30b537b90fbe</referenceId>
        <purchaseId>20191016-b2bef23a30b537b90fbe</purchaseId>
        <returnType>FINISHED</returnType>
        <paymentMethod>Creditcard</paymentMethod>
        <returnData type="creditcardData">
          <creditcardData>
            <type>visa</type>
            <cardHolder>Longbob Longsen</cardHolder>
            <expiryMonth>09</expiryMonth>
            <expiryYear>2020</expiryYear>
            <firstSixDigits>411111</firstSixDigits>
            <lastFourDigits>1111</lastFourDigits>
          </creditcardData>
        </returnData>
        <extraData key="captureId">5da76cc5ce84b</extraData>
      </result>
    XML
  end

  def failed_purchase_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>false</success>
        <referenceId>d74211aa7d0ba8294b4d</referenceId>
        <purchaseId>20191016-d74211aa7d0ba8294b4d</purchaseId>
        <returnType>ERROR</returnType>
        <paymentMethod>Creditcard</paymentMethod>
        <returnData type="creditcardData">
          <creditcardData>
            <type>visa</type>
            <cardHolder>Longbob Longsen</cardHolder>
            <expiryMonth>09</expiryMonth>
            <expiryYear>2020</expiryYear>
            <firstSixDigits>400030</firstSixDigits>
            <lastFourDigits>2220</lastFourDigits>
          </creditcardData>
        </returnData>
        <errors>
          <error>
            <message>The transaction was declined</message>
            <code>2003</code>
            <adapterMessage>Test decline</adapterMessage>
            <adapterCode>transaction_declined</adapterCode>
          </error>
        </errors>
      </result>
    XML
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
