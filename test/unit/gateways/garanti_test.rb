require 'test_helper'

class GarantiTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    @gateway = GarantiGateway.new(fixtures(:garanti))

    @credit_card = credit_card
    @amount = 1000 #1000 cents, 10$

    @options = {
      :order_id => 'db4af18c5222503d845180350fbda516',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'db4af18c5222503d845180350fbda516', response.authorization
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
   <<-EOF
<CC5Response>
  <OrderId>db4af18c5222503d845180350fbda516</OrderId>
  <GroupId>db4af18c5222503d845180350fbda516</GroupId>
  <Response>Approved</Response>
  <AuthCode>853030</AuthCode>
  <HostRefNum></HostRefNum>
  <ProcReturnCode></ProcReturnCode>
  <TransId>4bd864bb-e506-3000-002d-00144f7c9514</TransId>
  <ErrMsg></ErrMsg>
  <Extra>
    <TRXDATE>20100428 21:27:32</TRXDATE>
    <NUMCODE>00000099999999</NUMCODE>
  </Extra>
</CC5Response>

EOF
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
     <<-EOF
<?xml version="1.0" encoding="ISO-8859-9"?>
<CC5Response>
  <OrderId>97a1afb1ccc3aeaffa683e86ede62269</OrderId>
  <GroupId>97a1afb1ccc3aeaffa683e86ede62269</GroupId>
  <Response>Declined</Response>
  <AuthCode></AuthCode>
  <HostRefNum></HostRefNum>
  <ProcReturnCode></ProcReturnCode>
  <TransId>4bd864bb-e4fd-3000-002d-00144f7c9514</TransId>
  <ErrMsg></ErrMsg>
  <Extra>
    <TRXDATE>20100428 21:27:30</TRXDATE>
    <NUMCODE>00100099999999</NUMCODE>
  </Extra>
</CC5Response>

    EOF
  end
end
