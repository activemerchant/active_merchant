require "test_helper"

class QvalentTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = QvalentGateway.new(
      username: "username",
      password: "password",
      merchant: "merchant"
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "5d53a33d960c46d00f5dc061947d998c", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Invalid card number (no such number)", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
    assert response.test?
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "5d53a33d960c46d00f5dc061947d998c", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match %r{5d53a33d960c46d00f5dc061947d998c}, data
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response

    assert_equal "RSL-20887450", response.authorization
    assert_equal "Succeeded", response.message
    assert response.test?
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal "Invalid card number (no such number)", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
    assert response.test?
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal "Unable to read error message", response.message
  end

  private

  def successful_purchase_response
    %(
      response.summaryCode=0\r\nresponse.responseCode=08\r\nresponse.text=Honour with identification\r\nresponse.referenceNo=723907124\r\nresponse.orderNumber=5d53a33d960c46d00f5dc061947d998c\r\nresponse.RRN=723907124   \r\nresponse.settlementDate=20150228\r\nresponse.transactionDate=28-FEB-2015 09:34:15\r\nresponse.cardSchemeName=VISA\r\nresponse.creditGroup=VI/BC/MC\r\nresponse.previousTxn=0\r\nresponse.end\r\n
    )
  end

  def failed_purchase_response
    %(
      response.summaryCode=1\r\nresponse.responseCode=14\r\nresponse.text=Invalid card number (no such number)\r\nresponse.referenceNo=723907125\r\nresponse.orderNumber=b6e50802b764df4ca3e25fbd581e13d2\r\nresponse.settlementDate=20150228\r\nresponse.cardSchemeName=VISA\r\nresponse.creditGroup=VI/BC/MC\r\nresponse.previousTxn=0\r\nresponse.end\r\n
    )
  end

  def successful_refund_response
    %(
      response.summaryCode=0\r\nresponse.responseCode=08\r\nresponse.text=Honour with identification\r\nresponse.referenceNo=723907127\r\nresponse.orderNumber=f1a65bfe-f95b-4e06-b800-6d3b3a771238\r\nresponse.RRN=723907127   \r\nresponse.settlementDate=20150228\r\nresponse.transactionDate=28-FEB-2015 09:37:20\r\nresponse.cardSchemeName=VISA\r\nresponse.creditGroup=VI/BC/MC\r\nresponse.previousTxn=0\r\nresponse.end\r\n
    )
  end

  def failed_refund_response
    %(
      response.summaryCode=1\r\nresponse.responseCode=14\r\nresponse.text=Invalid card number (no such number) - card.PAN: Required field\r\nresponse.previousTxn=0\r\nresponse.end\r\n
    )
  end

  def successful_store_response
    %(
      response.summaryCode=0\r\nresponse.responseCode=00\r\nresponse.text=Approved or completed successfully\r\nresponse.cardSchemeName=VISA\r\nresponse.creditGroup=VI/BC/MC\r\nresponse.accountAlias=400010...224\r\nresponse.preregistrationCode=RSL-20887450\r\nresponse.customerReferenceNumber=RSL-20887450\r\nresponse.previousTxn=0\r\nresponse.end\r\n
    )
  end

  def failed_store_response
    %(
      response.summaryCode=1\r\nresponse.responseCode=14\r\nresponse.text=Invalid card number (no such number)\r\nresponse.cardSchemeName=VISA\r\nresponse.creditGroup=VI/BC/MC\r\nresponse.previousTxn=0\r\nresponse.end\r\n
    )
  end

  def empty_purchase_response
    %(
    )
  end
end
