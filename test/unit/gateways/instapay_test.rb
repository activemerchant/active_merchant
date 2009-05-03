require File.dirname(__FILE__) + '/../../test_helper'

class InstapayTest < Test::Unit::TestCase
  def setup
    @gateway = InstapayGateway.new(
                 :acctid => 'TEST0'
               )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of  Response, response
    assert_success response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card)
       assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_auth
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of  Response, response
    assert_success response
  end

  def test_unsuccessful_auth
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card)
       assert_instance_of Response, response
    assert_failure response
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
       '<html><body><plaintext>
Accepted=SALE:TEST:::118583850:::
historyid=118583850
orderid=92886714
Accepted=SALE:TEST:::118583850:::
ACCOUNTNUMBER=************5454
authcode=TEST
AuthNo=SALE:TEST:::118583850:::
historyid=118583850
orderid=92886714
recurid=0
refcode=118583850-TEST
result=1
Status=Accepted
transid=0
'
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
  '<html><body><plaintext>
Declined=DECLINED:0720930009:CVV2 MISMATCH:N7
historyid=118583848
orderid=92886713
ACCOUNTNUMBER=************2220
Declined=DECLINED:0720930009:CVV2 MISMATCH:N7
historyid=118583848
orderid=92886713
rcode=0720930009
Reason=DECLINED:0720930009:CVV2 MISMATCH:N7
recurid=0
result=0
Status=Declined
transid=80410586
'
  end
  def successful_auth_response
   '<html><body><plaintext>
Accepted=AUTH:TEST:::118585994:::
historyid=118585994
orderid=92888143
Accepted=AUTH:TEST:::118585994:::
ACCOUNTNUMBER=************5454
authcode=TEST
AuthNo=AUTH:TEST:::118585994:::
historyid=118585994
orderid=92888143
recurid=0
refcode=118585994-TEST
result=1
Status=Accepted
transid=0
'
  end

  def failed_auth_response
  '<html><body><plaintext>
Declined=DECLINED:0720930009:CVV2 MISMATCH:N7
historyid=118585991
orderid=92888142
ACCOUNTNUMBER=************2220
Declined=DECLINED:0720930009:CVV2 MISMATCH:N7
historyid=118585991
orderid=92888142
rcode=0720930009
Reason=DECLINED:0720930009:CVV2 MISMATCH:N7
recurid=0
result=0
Status=Declined
transid=80412271
'
  end
end
