require "test_helper"

class PayPalRESTTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaypalRestGateway.new({
      :mode => "sandbox",
      :client_id => "CLIENT_ID",
      :client_secret => "CLIENT_SECRET"
    })

    @amount = 1 * 100
    @credit_card = credit_card('4242424242424242')
    @credit_card_token = "CARD-123"

    @gateway.api.expects(:post).returns({ "id" => "123" })
  end

  def test_with_credit_card
    response = @gateway.purchase(@amount, @credit_card)
    assert(response.success?, "Should be success")
  end

  def test_with_credit_card_token
    response = @gateway.purchase(@amount, @credit_card_token)
    assert(response.success?, "Should be success")
  end

  def test_with_billing_address
    response = @gateway.purchase(@amount, @credit_card_token, :billing_address => {
      :line1 => "52 N Main ST",
      :city => "Johnstown",
      :country_code => "US",
      :postal_code => "43210",
      :state => "OH" } )
    assert(response.success?, "Should be success")
  end

  def test_with_items
    response = @gateway.purchase(@amount, @credit_card_token, :items => [{
      :name => "item",
      :sku => "item",
      :price => "1.00",
      :currency => "USD",
      :quantity => 1 }])
    assert(response.success?, "Should be success")
  end

  def test_with_amount_details
    response = @gateway.purchase(@amount, @credit_card_token, :tax => 1 * 100, :subtotal => 1 * 100)
    assert(response.success?, "Should be success")
  end

  def test_with_paypal
    response = @gateway.purchase(@amount,
      :return_url => "http://localhost/return",
      :cancel_url => "http://localhost/cancel" )
    assert(response.success?, "Should be success")
  end

  def test_execute
    response = @gateway.execute(@amount, :payment_id => "PAY-123", :payer_id => "123")
    assert(response.success?, "Should be success")
  end

  def test_authorize
    response = @gateway.authorize(@amount, @credit_card_token)
    assert(response.success?, "Should be success")
  end

  def test_capture
    response = @gateway.capture(@amount, :authorization_id => "123", :is_final_capture => true)
    assert(response.success?, "Should be success")
  end

  def test_refund_for_sale
    refund = @gateway.refund(@amount, :sale_id => "123")
    assert(refund.success?, "Should be success")
  end

  def test_refund_for_capture
    refund = @gateway.refund(@amount, :capture_id => "123")
    assert(refund.success?, "Should be success")
  end

end
