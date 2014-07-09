require 'test_helper'

class EwayTest < Test::Unit::TestCase
  def setup
    @gateway = EwayGateway.new(
      :login => '87654321'
    )

    @amount = 100

    @credit_card = credit_card('4646464646464646')

    @options = {
      :order_id => '1230123',
      :email => 'bob@testbob.com',
      :billing_address => {
        :address1 => '1234 First St.',
        :address2 => 'Apt. 1',
        :city     => 'Melbourne',
        :state    => 'ACT',
        :country  => 'AU',
        :zip      => '12345'
      },
      :description => 'purchased items'
    }
  end

  def test_purchase_without_billing_address
    @options.delete(:billing_address)
    assert_raise(ArgumentError) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '11292', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(40, purchase.authorization)
    assert_success response
    assert_equal '40', response.params['ewayreturnamount']
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(200, purchase.authorization)
    assert_failure response
    assert_equal '200', response.params['ewayreturnamount']
  end

  def test_amount_style
   assert_equal '1034', @gateway.send(:amount, 1034)

   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end

  def test_ensure_does_not_respond_to_authorize
    assert !@gateway.respond_to?(:authorize)
  end

  def test_ensure_does_not_respond_to_capture
    assert !@gateway.respond_to?(:capture) || @gateway.method(:capture).owner != @gateway.class
  end

  def test_add_address
    post = {}
    @gateway.send(:add_address, post, @options)
    assert_equal '1234 First St., Apt. 1, Melbourne, ACT, AU', post[:CustomerAddress]
    assert_equal @options[:billing_address][:zip], post[:CustomerPostcode]
  end

  private
  def successful_purchase_response
    <<-XML
      <?xml version="1.0"?>
      <ewayResponse>
        <ewayTrxnStatus>True</ewayTrxnStatus>
        <ewayTrxnNumber>11292</ewayTrxnNumber>
        <ewayTrxnReference/>
        <ewayTrxnOption1/>
        <ewayTrxnOption2/>
        <ewayTrxnOption3/>
        <ewayAuthCode>123456</ewayAuthCode>
        <ewayReturnAmount>100</ewayReturnAmount>
        <ewayTrxnError>00,Transaction Approved(Test CVN Gateway)</ewayTrxnError>
      </ewayResponse>
    XML
  end

  def failed_purchase_response
    <<-XML
      <?xml version="1.0"?>
      <ewayResponse>
        <ewayTrxnStatus>False</ewayTrxnStatus>
        <ewayTrxnNumber>11290</ewayTrxnNumber>
        <ewayTrxnReference/>
        <ewayTrxnOption1/>
        <ewayTrxnOption2/>
        <ewayTrxnOption3/>
        <ewayAuthCode/>
        <ewayReturnAmount>100</ewayReturnAmount>
        <ewayTrxnError>eWAY Error: Invalid Expiry Date. Your credit card has not been billed for this transaction.(Test CVN Gateway)</ewayTrxnError>
      </ewayResponse>
    XML
  end

  def successful_refund_response
    <<-XML
      <ewayResponse>
        <ewayTrxnStatus>True</ewayTrxnStatus>
        <ewayTrxnNumber>9953564</ewayTrxnNumber>
        <ewayTrxnOption1/>
        <ewayTrxnOption2/>
        <ewayTrxnOption3/>
        <ewayAuthCode>254313</ewayAuthCode>
        <ewayReturnAmount>40</ewayReturnAmount>
        <ewayTrxnError>00,Transaction Approved (Sandbox)</ewayTrxnError>
      </ewayResponse>
    XML
  end

  def failed_refund_response
    <<-XML
      <ewayResponse>
        <ewayTrxnStatus>False</ewayTrxnStatus>
        <ewayTrxnNumber/>
        <ewayTrxnOption1/>
        <ewayTrxnOption2/>
        <ewayTrxnOption3/>
        <ewayAuthCode/>
        <ewayReturnAmount>200</ewayReturnAmount>
        <ewayTrxnError>Error: You are requesting an amount greater than the remaining amount to be refunded. Your refund could not be processed.</ewayTrxnError>
      </ewayResponse>
    XML
  end
end
