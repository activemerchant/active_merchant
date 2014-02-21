require 'test_helper'

class MaxipagoTest < Test::Unit::TestCase
  def setup
    @gateway = MaxipagoGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '123456789', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  #def test_successful_purchase
  #  @gateway.expects(:ssl_post).returns(successful_purchase_response)

  #  assert response = @gateway.purchase(@amount, @credit_card, @options)
  #  assert_instance_of Response, response
  #  assert_success response

  #  # Replace with authorization number from the successful response
  #  assert_equal '', response.authorization
  #  assert response.test?
  #end

  #def test_unsuccessful_request
  #  @gateway.expects(:ssl_post).returns(failed_purchase_response)

  #  assert response = @gateway.purchase(@amount, @credit_card, @options)
  #  assert_failure response
  #  assert response.test?
  #end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-XML
<transaction-response>
  <authCode>555555</authCode>
  <orderID>123456789</orderID>
  <referenceNum>123456789</referenceNum>
  <transactionID>123456789</transactionID>
  <transactionTimestamp>123456789</transactionTimestamp>
  <responseCode>0</responseCode>
  <responseMessage>CAPTURED</responseMessage>
  <avsResponseCode/>
  <cvvResponseCode/>
  <processorCode>0</processorCode>
  <processorMessage>APPROVED</processorMessage>
  <errorMessage/>
  <processorTransactionID>123456789</processorTransactionID>
  <processorReferenceNumber>123456789</processorReferenceNumber>
  <fraudScore>29</fraudScore>
</transaction-response>
    XML
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-XML
<transaction-response>
  <authCode/>
  <orderID>123456789</orderID>
  <referenceNum>123456789</referenceNum>
  <transactionID>123456789</transactionID>
  <transactionTimestamp>123456789</transactionTimestamp>
  <responseCode>1</responseCode>
  <responseMessage>DECLINED</responseMessage>
  <avsResponseCode>NNN</avsResponseCode>
  <cvvResponseCode>N</cvvResponseCode>
  <processorCode>D</processorCode>
  <processorMessage>DECLINED</processorMessage>
  <errorMessage/>
</transaction-response>
    XML
  end
end
