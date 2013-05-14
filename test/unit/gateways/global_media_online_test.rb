require 'test_helper'

class GlobalMediaOnlineTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalMediaOnlineGateway.new(
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

  def test_successful_purchase
    @gateway.expects(:entry).returns(successful_entry_response)
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of(Response, response)
    assert_success response
    assert_equal successful_entry_response, response.authorization
  end

  def test_successful_authorize
    @gateway.expects(:entry).returns(successful_entry_response)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of(Response, response)
    assert_success response
    assert_equal successful_entry_response, response.authorization
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, successful_entry_response, @options)
    assert_instance_of(Response, response)
    assert_success response
    assert_equal successful_entry_response, response.authorization
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void(@amount, successful_entry_response, @options)
    assert_instance_of(Response, response)
    assert_success response
    assert_equal successful_entry_response, response.authorization
  end

  def test_post_data
    parameters = {
      "OrderID" => "1234-1234",
      "Amount"  => 1234,
    }

    assert result = @gateway.instance_eval{ post_data("AUTH", parameters) }
    assert_instance_of(String, result)
    assert_equal("Amount=1234&JobCd=AUTH&OrderID=1234-1234&ShopID=login&ShopPass=password", result)
  end

  def test_expdate
    @credit_card.year, @credit_card.month  = 2009, 2
    creditcard = @credit_card

    assert result = @gateway.instance_eval{ expdate(creditcard) }
    assert_instance_of(String, result)
    assert_equal("0902", result)
  end

  def test_parse
    body = "Amount=1234&JobCd=AUTH&OrderID=1234-1234&ShopID=login&ShopPass=password"

    assert result = @gateway.instance_eval{ parse(body) }
    assert_instance_of(Hash, result)
    assert_equal(result["ShopID"], "login")
    assert_equal(result["ShopPass"], "password")
    assert_equal(result["JobCd"], "AUTH")
    assert_equal(result["OrderID"], "1234-1234")
    assert_equal(result["Amount"], "1234")
  end

  def test_get_authorization
    @gateway.expects(:entry).returns(successful_entry_response)

    assert response = @gateway.instance_eval{ get_authorization({}, "AUTH") }
    assert_equal(successful_entry_response, response["Authorization"])
  end

  private

  def successful_entry_response
    "AccessID=3a6fd19290c7c919f09bbf18e691ff96&AccessPass=686b63fe141819d43464587322c874fe"
  end

  def successful_purchase_response
    "ACS=0&OrderID=20130514-062200&Forward=2a99662&Method=1&PayTimes=&Approve=6849056&TranID=1305140618111111111111193102&TranDate=20130514062200&CheckString=dc369976c3f797d5b0b2b74f1499b88a"
  end

  def successful_authorize_response
    "ACS=0&OrderID=20130514-062200&Forward=2a99662&Method=1&PayTimes=&Approve=6849056&TranID=1305140618111111111111193102&TranDate=20130514062200&CheckString=dc369976c3f797d5b0b2b74f1499b88a"
  end

    def successful_capture_response
    "AccessID=3a6fd19290c7c919f09bbf18e691ff96&AccessPass=686b63fe141819d43464587322c874fe&Forward=1234567&Approve=1234567&TranID=1234567890123456789012345678&TranDate=20130514113845"
  end

    def successful_void_response
    "AccessID=3a6fd19290c7c919f09bbf18e691ff96&AccessPass=686b63fe141819d43464587322c874fe&Forward=1234567&Approve=1234567&TranID=1234567890123456789012345678&TranDate=20130514113845"
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
  end
end
