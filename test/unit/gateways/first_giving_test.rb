require 'test_helper'

class FirstGivingTest < Test::Unit::TestCase
  def setup
    @gateway = FirstGivingGateway.new(:application_key => 'application_key',
                                  :security_token  => 'security_token')

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'a-a09bf64559e5824eb925f5', response.authorization
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_get).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, @transaction_id, @options)
    assert_instance_of Response, response
    assert_success response
    # Replace with authorization number from the successful response
    assert_equal 'a-a09bf64559e5824eb925f5', response.authorization
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_get).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, @transaction_id, @options)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?><firstGivingDonationApi xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><firstGivingResponse acknowledgement=\"Success\"><transactionId>a-a09bf64559e5824eb925f5</transactionId><donationId>0</donationId></firstGivingResponse></firstGivingDonationApi>"
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?><firstGivingDonationApi xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><firstGivingResponse acknowledgement=\"Failed\" friendlyErrorMessage=\"Unfortunately, we were unable to perform credit card number validation. The credit card number validator responded with the following message  ccNumber failed data validation for the following reasons :  creditcardChecksum: 4457010000000000 seems to contain an invalid checksum.\" verboseErrorMessage=\"ccNumber failed data validation for the following reasons :  creditcardChecksum: 4457010000000000 seems to contain an invalid checksum\" errorTarget=\"ccNumber\"/></firstGivingDonationApi>"
  end

  # TODO: Place raw successful response from gateway here
  def successful_refund_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?><firstGivingDonationApi xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><firstGivingResponse acknowledgement=\"Success\"><transactionId>a-a09bf64559e5824eb925f5</transactionId><donationId>0</donationId></firstGivingResponse></firstGivingDonationApi>"
  end

  # TODO: Place raw failed response from gateway here
  def failed_refund_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?><firstGivingDonationApi xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><firstGivingResponse acknowledgement=\"Failed\" verboseErrorMessage=\"Bad JG_APPLICATIONKEY and JG_SECURITYTOKEN.\" /></firstGivingDonationApi>"
  end

end
