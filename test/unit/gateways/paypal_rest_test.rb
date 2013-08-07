require "test_helper"

class PayPalRESTTest < Test::Unit::TestCase

  def setup
    @gateway = PaypalRestGateway.new({
      :mode => "sandbox",
      :client_id => ENV["TEST_PAYPAL_CLIENT_ID"] || "CLIENT_ID",
      :client_secret => ENV["TEST_PAYPAL_CLIENT_SECRET"] || "CLIENT_SECRET"
    })

    @amount = 1 * 100
    @credit_card = credit_card('4417119669820331')
    @credit_card_token = "CARD-9WF44094V8439724WKH5D3DI"

    @address = {
      :line1 => "52 N Main ST",
      :city => "Johnstown",
      :country_code => "US",
      :postal_code => "43210",
      :state => "OH" }
    @shipping_address = @address.merge( :recipient_name => "Testing" )

    @item = {
      :name => "item",
      :sku => "item",
      :price => 100,
      :quantity => 1 }
  end

  def test_user_agent
    assert_match /PayPalSDK\/rest-sdk-activemerchant/, @gateway.api.class.user_agent
  end

  def test_no_funding_instrument
    assert_raise(ArgumentError){ @gateway.purchase(@amount) }
  end

  def test_with_credit_card
    @gateway.api.expects(:post).
      with("v1/payments/payment", request_data[:payment_with_credit_card]).
      returns(create_payment_with_credit_card_response) unless sandbox_test?

    response = @gateway.purchase(@amount, @credit_card)
    assert(response.success?, "Should be success")
    assert_equal("approved", response.state)
  end

  def test_with_credit_card_token
    @gateway.api.expects(:post).
      with("v1/payments/payment", request_data[:payment_with_credit_card_token]).
      returns(create_payment_with_token_response) unless sandbox_test?

    response = @gateway.purchase(@amount, @credit_card_token)
    assert(response.success?, "Should be success")
    assert_equal("approved", response.state)
  end

  def test_with_billing_address
    @gateway.api.expects(:post).
      with("v1/payments/payment", request_data[:payment_with_billing_address]).
      returns(create_payment_with_credit_card_response) unless sandbox_test?

    response = @gateway.purchase(@amount, @credit_card, :billing_address => @address )
    assert(response.success?, "Should be success")
  end

  def test_with_items
    @gateway.api.expects(:post).
      with("v1/payments/payment", request_data[:payment_with_items]).
      returns(create_payment_with_credit_card_response) unless sandbox_test?

    response = @gateway.purchase(@amount, @credit_card, :items => [ @item ], :shipping_address => @shipping_address )
    assert(response.success?, "Should be success")
  end

  def test_with_items_and_amount
    @gateway.api.expects(:post).
      with("v1/payments/payment", request_data[:payment_with_items]).
      returns(create_payment_with_credit_card_response) unless sandbox_test?

    response = @gateway.purchase(@amount, @credit_card,
      :items => [ { :amount => 1 * 100, :name => @item[:name], :quantity => @item[:quantity], :sku => 'item' } ],
      :shipping_address => @shipping_address )
    assert(response.success?, "Should be success")
  end

  def test_with_invalid_items
    assert_raise(ArgumentError) {
      @gateway.purchase(@amount, @credit_card, :items => [ { :name => "incomplete item" } ])
    }
  end

  def test_with_invalid_address
    assert_raise(ArgumentError) {
      @gateway.purchase(@amount, @credit_card, :shipping_address => { :line1 => "incomplete address" } )
    }
    assert_raise(ArgumentError) {
      @gateway.purchase(@amount, @credit_card, :address => { :line1 => "incomplete address" } )
    }
    assert_raise(ArgumentError) {
      @gateway.purchase(@amount, @credit_card, :billing_address => { :line1 => "incomplete address" } )
    }
  end

  def test_with_amount_details
    @gateway.api.expects(:post).
      with("v1/payments/payment", request_data[:payment_with_credit_card].merge({
        :transactions => [{
          :amount  => request_data[:amount].merge({
            :details => { :tax => "0.50", :subtotal => "0.50" }}) }]})).
      returns(create_payment_with_credit_card_response) unless sandbox_test?

    response = @gateway.purchase(@amount, @credit_card, :tax => 50, :subtotal => 50)
    assert(response.success?, "Should be success")
  end

  def test_with_request_id
    @gateway.api.expects(:post).
      with("v1/payments/payment", request_data[:payment_with_credit_card], "PayPal-Request-Id" => "unique-id" ).
      returns(create_payment_with_credit_card_response)

    response = @gateway.purchase(@amount, @credit_card, :request_id => "unique-id" )
    assert(response.success?, "Should be success")
  end


  def test_with_paypal
    @gateway.api.expects(:post).
      with("v1/payments/payment", request_data[:payment_with_paypal]).
      returns(create_payment_with_paypal_response) unless sandbox_test?

    response = @gateway.purchase(@amount,
      :return_url => "http://return.url",
      :cancel_url => "http://cancel.url" )
    assert(response.success?, "Should be success")
  end

  def test_with_payment_id
    @gateway.api.expects(:post).
      with("v1/payments/payment/PAY-2YB28071MB744303AKH5DMWA/execute",
        { :payer_id => "123", :transactions => [ request_data[:transaction][:amount] ] }).
      returns(create_payment_with_paypal_response)

    assert_raise(ArgumentError){ @gateway.purchase(@amount, :payment_id => "PAY-2YB28071MB744303AKH5DMWA") }

    response = @gateway.purchase(@amount, :payment_id => "PAY-2YB28071MB744303AKH5DMWA", :payer_id => "123")
    assert(response.success?, "Should be success")
  end

  def test_execute
    @gateway.api.expects(:post).
      with("v1/payments/payment/PAY-2YB28071MB744303AKH5DMWA/execute",
        { :payer_id => "123", :transactions => [ request_data[:transaction][:amount] ] }).
      returns(create_payment_with_paypal_response)

    response = @gateway.execute(@amount, :payment_id => "PAY-2YB28071MB744303AKH5DMWA", :payer_id => "123")
    assert(response.success?, "Should be success")
  end


  def test_execute_with_no_values
    assert_raise(ArgumentError){ @gateway.execute(@amount) }
    assert_raise(ArgumentError){ @gateway.execute(@amount, :payment_id => "PAY-123") }
    assert_raise(ArgumentError){ @gateway.execute(@amount, :payer_id   => "123") }
  end

  def test_authorize
    @gateway.api.expects(:post).
      with("v1/payments/payment",
        request_data[:payment_with_credit_card].merge(:intent => "authorize") ).
      returns(create_authorize_response) unless sandbox_test?

    response = @gateway.authorize(@amount, @credit_card)
    assert(response.success?, "Should be success")
  end

  def test_reauthorize
    @gateway.api.expects(:post).
      with("v1/payments/authorization/1J319028U3903480V/reauthorize",
        { :amount => request_data[:amount] }).
      returns(create_authorize_response)

    response = @gateway.reauthorize(@amount, :authorization_id => "1J319028U3903480V")
    assert(response.success?, "Should be success")
  end

  def test_capture
    @gateway.api.expects(:post).
      with("v1/payments/authorization/1J319028U3903480V/capture",
        { :amount => request_data[:amount], :is_final_capture => false }).
      returns({})

    response = @gateway.capture(@amount, :authorization_id => "1J319028U3903480V", :is_final_capture => false)
    assert(response.success?, "Should be success")
  end

  def test_refund_for_sale
    @gateway.api.expects(:post).
      with("v1/payments/sale/28H16906173986239/refund", request_data[:transaction]).
      returns({})

    refund = @gateway.refund(@amount, :sale_id => "28H16906173986239")
    assert(refund.success?, "Should be success")
  end

  def test_refund_for_capture
    @gateway.api.expects(:post).
      with("v1/payments/capture/123/refund", request_data[:transaction]).
      returns({})

    refund = @gateway.refund(@amount, :capture_id => "123")
    assert(refund.success?, "Should be success")
  end

  def test_store_credit_card
    @gateway.api.expects(:post).
      with("v1/vault/credit-card", request_data[:credit_card]).
      returns(store_credit_card_response) unless sandbox_test?

    response = @gateway.store_credit_card(@credit_card)
    assert(response.success?, "Should be success")
    assert_not_nil(response.params["id"])
  end

  def test_get_credit_card
    @gateway.api.expects(:get).
      with("v1/vault/credit-card/CARD-9WF44094V8439724WKH5D3DI", {}).
      returns(store_credit_card_response)

    response = @gateway.get_credit_card("CARD-9WF44094V8439724WKH5D3DI")
    assert(response.success?, "Should be success")
    assert_equal("CARD-9WF44094V8439724WKH5D3DI", response.params["id"])
  end

  def test_delete_credit_card
    @gateway.api.expects(:delete).
      with("v1/vault/credit-card/CARD-9WF44094V8439724WKH5D3DI", {}).
      returns(store_credit_card_response)

    response = @gateway.delete_credit_card("CARD-9WF44094V8439724WKH5D3DI")
    assert(response.success?, "Should be success")
    assert_equal("CARD-9WF44094V8439724WKH5D3DI", response.params["id"])
  end

  def test_payment_history
    @gateway.api.expects(:get).
      with("v1/payments/payment", :count => 1 ).
      returns( "payments" => [ create_payment_with_paypal_response ] ) unless sandbox_test?

    response = @gateway.payment_history( :count => 1 )
    assert(response.success?, "Should be success")
    assert_not_nil(response.params["payments"])
  end

  def test_not_found_exception
    http_response = Struct.new(:code, :message).new( 400, "Not Found")
    @gateway.api.expects(:get).
      raises(PayPal::SDK::Core::Exceptions::ResourceNotFound.new(http_response))

    response = @gateway.get_payment("PAY-invalid")
    assert_false(response.success?)
    assert_equal("Failed.  Response code = 400.  Response message = Not Found.", response.message)
  end

  def test_get_payment
    @gateway.api.expects(:get).
      with("v1/payments/payment/PAY-2YB28071MB744303AKH5DMWA", {}).
      returns(create_payment_with_paypal_response)

    response = @gateway.get_payment("PAY-2YB28071MB744303AKH5DMWA")
    assert(response.success?, "Should be success")
    assert_equal("PAY-2YB28071MB744303AKH5DMWA", response.params["id"])
  end

  def test_get_sale
    @gateway.api.expects(:get).
      with("v1/payments/sale/28H16906173986239", {}).
      returns({ "id" => "28H16906173986239" })

    response = @gateway.get_sale("28H16906173986239")
    assert(response.success?, "Should be success")
    assert_equal("28H16906173986239", response.params["id"])
  end

  def test_get_authorization
    @gateway.api.expects(:get).
      with("v1/payments/authorization/123", {}).
      returns({ "id" => "123" })

    response = @gateway.get_authorization("123")
    assert(response.success?, "Should be success")
    assert_equal("123", response.params["id"])
  end

  def test_void_authorization
    @gateway.api.expects(:post).
      with("v1/payments/authorization/123/void", {}).
      returns({ "id" => "123" })

    response = @gateway.void_authorization("123")
    assert(response.success?, "Should be success")
    assert_equal("123", response.params["id"])
  end

  def test_get_refund
    @gateway.api.expects(:get).
      with("v1/payments/refund/123", {}).
      returns({ "id" => "123" })

    response = @gateway.get_refund("123")
    assert(response.success?, "Should be success")
    assert_equal("123", response.params["id"])
  end

  def test_get_capture
    @gateway.api.expects(:get).
      with("v1/payments/capture/123", {}).
      returns({ "id" => "123" })

    response = @gateway.get_capture("123")
    assert(response.success?, "Should be success")
    assert_equal("123", response.params["id"])
  end

  private

  def sandbox_test?
    ENV["TEST_PAYPAL_CLIENT_ID"] and ENV["TEST_PAYPAL_CLIENT_SECRET"]
  end

  def request_data
    @request_data ||=
      begin
        examples = {}
        examples[:credit_card] = {
          :type         => "visa",
          :number       => @credit_card.number,
          :expire_month => "09",
          :expire_year  => @credit_card.year.to_s,
          :cvv2         => @credit_card.verification_value,
          :first_name   => @credit_card.first_name,
          :last_name    => @credit_card.last_name }
        examples[:credit_card_with_billing_address] = examples[:credit_card].merge({:billing_address => @address})
        examples[:amount] = {
          :total    => '1.00',
          :currency => 'USD' }
        examples[:transaction] = {
          :amount => examples[:amount] }
        examples[:payment_with_credit_card] = {
          :intent => "sale",
          :payer  => {
            :payment_method => 'credit_card',
            :funding_instruments => [{ :credit_card => examples[:credit_card] }] },
          :transactions => [ examples[:transaction] ] }
        examples[:payment_with_billing_address] = {
          :intent => "sale",
          :payer  => {
            :payment_method => 'credit_card',
            :funding_instruments => [{
              :credit_card => examples[:credit_card_with_billing_address] }] },
          :transactions => [ examples[:transaction] ] }
        examples[:payment_with_items] = {
          :intent => "sale",
          :payer  => {
            :payment_method => 'credit_card',
            :funding_instruments => [{
              :credit_card => examples[:credit_card] }] },
          :transactions => [ examples[:transaction].merge({
            :item_list => { :items => [ @item.merge({ :currency => 'USD', :price => '1.00' }) ],
            :shipping_address => @shipping_address } }) ] }
        examples[:payment_with_credit_card_token] = {
          :intent => "sale",
          :payer  => {
            :payment_method => 'credit_card',
            :funding_instruments => [{ :credit_card_token => {
              :credit_card_id =>  @credit_card_token } }] },
          :transactions => [ examples[:transaction] ] }
        examples[:payment_with_paypal] = {
          :intent => 'sale',
          :payer => { :payment_method => 'paypal' },
          :redirect_urls => {
            :return_url => "http://return.url",
            :cancel_url => "http://cancel.url" },
          :transactions => [ examples[:transaction] ] }
        examples
      end
  end

  def create_payment_with_credit_card_response
    {"id"=>"PAY-82Y62416AP059732MKH5DJZA", "create_time"=>"2013-08-01T10:13:56Z", "update_time"=>"2013-08-01T10:14:00Z", "state"=>"approved", "intent"=>"sale", "payer"=>{"payment_method"=>"credit_card", "funding_instruments"=>[{"credit_card"=>{"type"=>"visa", "number"=>"xxxxxxxxxxxx0331", "expire_month"=>"9", "expire_year"=>"2014", "first_name"=>"Longbob", "last_name"=>"Longsen"}}]}, "transactions"=>[{"amount"=>{"total"=>"1.00", "currency"=>"USD", "details"=>{"subtotal"=>"1.00"}}, "related_resources"=>[{"sale"=>{"id"=>"28H16906173986239", "create_time"=>"2013-08-01T10:13:56Z", "update_time"=>"2013-08-01T10:14:00Z", "state"=>"completed", "amount"=>{"total"=>"1.00", "currency"=>"USD"}, "parent_payment"=>"PAY-82Y62416AP059732MKH5DJZA", "links"=>[{"href"=>"https://api.sandbox.paypal.com/v1/payments/sale/28H16906173986239", "rel"=>"self", "method"=>"GET"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/sale/28H16906173986239/refund", "rel"=>"refund", "method"=>"POST"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/payment/PAY-82Y62416AP059732MKH5DJZA", "rel"=>"parent_payment", "method"=>"GET"}]}}]}], "links"=>[{"href"=>"https://api.sandbox.paypal.com/v1/payments/payment/PAY-82Y62416AP059732MKH5DJZA", "rel"=>"self", "method"=>"GET"}]}
  end

  def store_credit_card_response
    {"id"=>"CARD-9WF44094V8439724WKH5D3DI", "valid_until"=>"2014-10-01T00:00:00Z", "state"=>"ok", "type"=>"visa", "number"=>"xxxxxxxxxxxx0331", "expire_month"=>"9", "expire_year"=>"2014", "first_name"=>"Longbob", "last_name"=>"Longsen", "links"=>[{"href"=>"https://api.sandbox.paypal.com/v1/vault/credit-card/CARD-9WF44094V8439724WKH5D3DI", "rel"=>"self", "method"=>"GET"}, {"href"=>"https://api.sandbox.paypal.com/v1/vault/credit-card/CARD-9WF44094V8439724WKH5D3DI", "rel"=>"delete", "method"=>"DELETE"}]}
  end

  def create_payment_with_token_response
    {"id"=>"PAY-4FV42180KK157272TKH5D47Q", "create_time"=>"2013-08-01T10:54:54Z", "update_time"=>"2013-08-01T10:54:57Z", "state"=>"approved", "intent"=>"authorize", "payer"=>{"payment_method"=>"credit_card", "funding_instruments"=>[{"credit_card_token"=>{"credit_card_id"=>"CARD-9WF44094V8439724WKH5D3DI", "last4"=>"0331", "type"=>"visa", "expire_month"=>"9", "expire_year"=>"2014"}}]}, "transactions"=>[{"amount"=>{"total"=>"1.00", "currency"=>"USD", "details"=>{"subtotal"=>"1.00"}}, "related_resources"=>[{"authorization"=>{"id"=>"55F69542AJ956661W", "create_time"=>"2013-08-01T10:54:54Z", "update_time"=>"2013-08-01T10:54:57Z", "state"=>"authorized", "amount"=>{"total"=>"1.00", "currency"=>"USD", "details"=>{"subtotal"=>"1.00"}}, "parent_payment"=>"PAY-4FV42180KK157272TKH5D47Q", "valid_until"=>"2013-08-30T10:54:54Z", "links"=>[{"href"=>"https://api.sandbox.paypal.com/v1/payments/authorization/55F69542AJ956661W", "rel"=>"self", "method"=>"GET"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/authorization/55F69542AJ956661W/capture", "rel"=>"capture", "method"=>"POST"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/authorization/55F69542AJ956661W/void", "rel"=>"void", "method"=>"POST"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/payment/PAY-4FV42180KK157272TKH5D47Q", "rel"=>"parent_payment", "method"=>"GET"}]}}]}], "links"=>[{"href"=>"https://api.sandbox.paypal.com/v1/payments/payment/PAY-4FV42180KK157272TKH5D47Q", "rel"=>"self", "method"=>"GET"}]}
  end

  def create_payment_with_paypal_response
    {"id"=>"PAY-2YB28071MB744303AKH5DMWA", "create_time"=>"2013-08-01T10:20:08Z", "update_time"=>"2013-08-01T10:20:08Z", "state"=>"created", "intent"=>"sale", "payer"=>{"payment_method"=>"paypal"}, "transactions"=>[{"amount"=>{"total"=>"1.00", "currency"=>"USD", "details"=>{"subtotal"=>"1.00"}}}], "links"=>[{"href"=>"https://api.sandbox.paypal.com/v1/payments/payment/PAY-2YB28071MB744303AKH5DMWA", "rel"=>"self", "method"=>"GET"}, {"href"=>"https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=EC-6T619957819203415", "rel"=>"approval_url", "method"=>"REDIRECT"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/payment/PAY-2YB28071MB744303AKH5DMWA/execute", "rel"=>"execute", "method"=>"POST"}]}
  end

  def create_authorize_response
    {"id"=>"PAY-2HB837024R788941JKH5DLJY", "create_time"=>"2013-08-01T10:17:11Z", "update_time"=>"2013-08-01T10:17:15Z", "state"=>"approved", "intent"=>"authorize", "payer"=>{"payment_method"=>"credit_card", "funding_instruments"=>[{"credit_card"=>{"type"=>"visa", "number"=>"xxxxxxxxxxxx0331", "expire_month"=>"9", "expire_year"=>"2014", "first_name"=>"Longbob", "last_name"=>"Longsen"}}]}, "transactions"=>[{"amount"=>{"total"=>"1.00", "currency"=>"USD", "details"=>{"subtotal"=>"1.00"}}, "related_resources"=>[{"authorization"=>{"id"=>"1J319028U3903480V", "create_time"=>"2013-08-01T10:17:11Z", "update_time"=>"2013-08-01T10:17:15Z", "state"=>"authorized", "amount"=>{"total"=>"1.00", "currency"=>"USD", "details"=>{"subtotal"=>"1.00"}}, "parent_payment"=>"PAY-2HB837024R788941JKH5DLJY", "valid_until"=>"2013-08-30T10:17:11Z", "links"=>[{"href"=>"https://api.sandbox.paypal.com/v1/payments/authorization/1J319028U3903480V", "rel"=>"self", "method"=>"GET"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/authorization/1J319028U3903480V/capture", "rel"=>"capture", "method"=>"POST"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/authorization/1J319028U3903480V/void", "rel"=>"void", "method"=>"POST"}, {"href"=>"https://api.sandbox.paypal.com/v1/payments/payment/PAY-2HB837024R788941JKH5DLJY", "rel"=>"parent_payment", "method"=>"GET"}]}}]}], "links"=>[{"href"=>"https://api.sandbox.paypal.com/v1/payments/payment/PAY-2HB837024R788941JKH5DLJY", "rel"=>"self", "method"=>"GET"}]}
  end

end
