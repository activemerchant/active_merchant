require 'test_helper'

class PayhubTest < Test::Unit::TestCase
  def setup
    @gateway = PayhubGateway.new(
                 :orgid => '10102',
                 :mode => 'staging'
               )
    
    @credit_card = credit_card
    @amount = 100
    @credit_card.verification_value = "999"

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

    assert_match /^[0-9A-Z]{6,8}$/, response.authorization
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
    %({
      "CARD_TOKEN_NO": "9999000000001698",
      "AVS_RESULT_CODE": "N",
      "TRANSACTION_ID": "18952",
      "CUSTOMER_ID": "",
      "VERIFICATION_RESULT_CODE": "M",
      "RESPONSE_CODE": "00",
      "RISK_STATUS_RESPONSE_CODE": "",
      "TRANSACTION_DATE_TIME": "2013-12-13 14:04:38",
      "RISK_STATUS_RESPONSE_TEXT": "",
      "APPROVAL_CODE": "TAS960",
      "BATCH_ID": "1042",
      "RESPONSE_TEXT": "SUCCESS",
      "CIS_NOTE": ""
    })
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    %({
      "CARD_TOKEN_NO": "9999000000001698",
      "AVS_RESULT_CODE": "N",
      "TRANSACTION_ID": "18947",
      "CUSTOMER_ID": "",
      "VERIFICATION_RESULT_CODE": "N",
      "RESPONSE_CODE": "N7",
      "RISK_STATUS_RESPONSE_CODE": "",
      "TRANSACTION_DATE_TIME": "2013-12-13 12:16:41",
      "RISK_STATUS_RESPONSE_TEXT": "",
      "APPROVAL_CODE": "      ",
      "BATCH_ID": "1042",
      "RESPONSE_TEXT": "Please retry the previous transaction or contact a PayHub Admin at 415-306-9476.",
      "CIS_NOTE": ""
    })
  end
end
