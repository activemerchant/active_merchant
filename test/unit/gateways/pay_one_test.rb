require 'test_helper'

class PayOneTest < Test::Unit::TestCase
  def setup
    @gateway = PayOneGateway.new mid: '1234', portalid: '1234', aid: '1234'

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '19779424', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-RESPONSE
status=APPROVED
txid=19779424
userid=6202532
clearing_bankcode=10070024
clearing_bankaccount=130066402
clearing_bankcountry=
clearing_bankname=Deutsche Bank PGK AG
clearing_bankaccountholder=HR New Media GmbH
clearing_bankcity=
clearing_bankiban=DE68100700240130066400
clearing_bankbic=DEUTDEDBBER
    RESPONSE
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-RESPONSE
status=ERROR
errorcode=1300
errormessage=Parameter {customerid} incorrect
customermessage=An error occured while processing this transaction (wrong parameters).
    RESPONSE
  end
end
