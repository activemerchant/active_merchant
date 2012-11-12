require 'test_helper'

class EwayRefundTest < Test::Unit::TestCase
  def setup
    @gateway = EwayRefundGateway.new(
      :login => '87654321',
      :password => '12321312'
    )

    @reference = '1230123'

    @options = {
      :month => 5,
      :year => 13
    }
  end

  def test_refund_without_month
    @options.delete(:month)
    assert_raise(ArgumentError) do
      @gateway.refund(@amount, @reference, @options)
    end
  end

  def test_refund_without_year
    @options.delete(:year)
    assert_raise(ArgumentError) do
      @gateway.refund(@amount, @reference, @options)
    end
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, @reference, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '123456', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, @reference, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_amount_style
   assert_equal '1034', @gateway.send(:amount, 1034)

   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end

  def test_test_url
    assert_equal EwayRefundGateway.test_url, @gateway.send(:gateway_url, true)
  end

  def test_live_url
    assert_equal EwayRefundGateway.live_url, @gateway.send(:gateway_url, false)
  end

  private
  def successful_refund_response
    <<-XML
<?xml version="1.0"?>
<ewayResponse>
<ewayTrxnError></ewayTrxnError>
<ewayTrxnStatus>True</ewayTrxnStatus>
<ewayTrxnNumber>10002</ewayTrxnNumber>
<ewayTrxnOption1></ewayTrxnOption1>
<ewayTrxnOption2></ewayTrxnOption2>
<ewayTrxnOption3></ewayTrxnOption3>
<ewayReturnAmount>10</ewayReturnAmount>
<ewayAuthCode>123456</ewayAuthCode>
<ewayTrxnReference>987654321</ewayTrxnReference>
</ewayResponse>
    XML
  end

  def failed_refund_response
    <<-XML
<?xml version="1.0"?>
<ewayResponse>
<ewayTrxnError>Error: Invalid Customer ID for Refunds. Your refund could not be processed.</ewayTrxnError>
<ewayTrxnStatus>False</ewayTrxnStatus>
<ewayTrxnNumber></ewayTrxnNumber>
<ewayTrxnOption1></ewayTrxnOption1>
<ewayTrxnOption2></ewayTrxnOption2>
<ewayTrxnOption3></ewayTrxnOption3>
<ewayReturnAmount>10</ewayReturnAmount>
<ewayAuthCode></ewayAuthCode>
<ewayTrxnReference></ewayTrxnReference>
</ewayResponse>
    XML
  end
end

