require 'test_helper'

class RemotePayflowExpressTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = PayflowExpressGateway.new(fixtures(:payflow))

    @options = { :billing_address => { 
                                :name => 'Cody Fauser',
                                :address1 => '1234 Shady Brook Lane',
                                :city => 'Ottawa',
                                :state => 'ON',
                                :country => 'CA',
                                :zip => '90210',
                                :phone => '555-555-5555'
                             },
                 :email => 'cody@example.com'
               }
  end
  
  # Only works with a Payflow 2.0 account or by requesting the addition
  # of Express checkout to an existing Payflow Pro account.  This can be done
  # by contacting Payflow sales. The PayPal account used must be a business
  # account and the Payflow Pro account must be in Live mode in order for
  # the tests to work correctly
  def test_set_express_authorization
    @options.update(
      :return_url => 'http://example.com',
      :cancel_return_url => 'http://example.com',
      :email => 'Buyer1@paypal.com'
    )
    response = @gateway.setup_authorization(500, @options)
    assert response.success?
    assert response.test?
    assert !response.params['token'].blank?
  end
  
  def test_set_express_purchase
    @options.update(
      :return_url => 'http://example.com',
      :cancel_return_url => 'http://example.com',
      :email => 'Buyer1@paypal.com'
    )
    response = @gateway.setup_purchase(500, @options)
    assert response.success?
    assert response.test?
    assert !response.params['token'].blank?
  end

  def test_setup_authorization_discount_taxes_included_free_shipping
    amount = 2518
    options = {:ip=>"127.0.0.1",
      :return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?buyer_accepts_marketing=true&utm_nooverride=1",
      :cancel_return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?utm_nooverride=1",
      :customer=>"test6@test.com",
      :email=>"test6@test.com",
      :order_id=>"#1092",
      :currency=>"USD",
      :subtotal=>2798,
      :items => [
        {:name => "test4",
          :description => "test4",
          :quantity=>2 ,
          :amount=> 1399 ,
          :url=>"http://localhost:3000/products/test4"}],
      :discount=>280,
      :no_shipping=>true}
    response = @gateway.setup_authorization(amount, options)
    assert response.success?, response.message
  end

  def test_setup_authorization_with_discount_taxes_additional
    amount = 2518
    options = {:ip=>"127.0.0.1",
      :return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?buyer_accepts_marketing=true&utm_nooverride=1",
      :cancel_return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?utm_nooverride=1",
      :customer=>"test6@test.com",
      :email=>"test6@test.com",
      :order_id=>"#1092",
      :currency=>"USD",
      :subtotal=>2798,
      :items => [
        {:name => "test4",
          :description => "test4",
          :quantity=>2 ,
          :amount=> 1399 ,
          :url=>"http://localhost:3000/products/test4"}],
      :discount=>280,
      :no_shipping=>true}
    response = @gateway.setup_authorization(amount, options)
    assert response.success?, response.message
  end

  def test_setup_authorization_with_discount_taxes_and_shipping_addtiional
    amount = 2518
    options = {:ip=>"127.0.0.1",
      :return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?buyer_accepts_marketing=true&utm_nooverride=1",
      :cancel_return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?utm_nooverride=1",
      :customer=>"test6@test.com",
      :email=>"test6@test.com",
      :order_id=>"#1092",
      :currency=>"USD",
      :subtotal=>2798,
      :items => [
        {:name => "test4",
          :description => "test4",
          :quantity=>2 ,
          :amount=> 1399 ,
          :url=>"http://localhost:3000/products/test4"}],
      :discount=>280,
      :no_shipping=>false}
    response = @gateway.setup_authorization(amount, options)
    assert response.success?, response.message
  end
end

class RemotePayflowExpressUkTest < Test::Unit::TestCase

  def setup
    @gateway = PayflowExpressUkGateway.new(fixtures(:payflow_uk))
  end

  def test_setup_authorization_discount_taxes_included_free_shipping
    amount = 2518
    options = {:ip=>"127.0.0.1",
      :return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?buyer_accepts_marketing=true&utm_nooverride=1",
      :cancel_return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?utm_nooverride=1",
      :customer=>"test6@test.com",
      :email=>"test6@test.com",
      :order_id=>"#1092",
      :currency=>"GBP",
      :subtotal=>2798,
      :items=> [
        {:name=>"test4",
          :description=>"test4",
          :quantity=>2,
          :amount=>1399,
          :url=>"http://localhost:3000/products/test4"},
        ],
      :discount=>280,
      :no_shipping=>true}
    response = @gateway.setup_authorization(amount, options)
    assert response.success?, response.message
  end

  def test_setup_authorization_with_discount_taxes_additional
    amount = 2518
    options = {:ip=>"127.0.0.1",
      :return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?buyer_accepts_marketing=true&utm_nooverride=1",
      :cancel_return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?utm_nooverride=1",
      :customer=>"test6@test.com",
      :email=>"test6@test.com",
      :order_id=>"#1092",
      :currency=>"GBP",
      :subtotal=>2798,
      :items=> [
        {:name=>"test4",
          :description=>"test4",
          :quantity=>2,
          :amount=>1399,
          :url=>"http://localhost:3000/products/test4"},
        ],
      :discount=>280,
      :no_shipping=>true}
    response = @gateway.setup_authorization(amount, options)
    assert response.success?, response.message
  end

  def test_setup_authorization_with_discount_taxes_and_shipping_addtiional
    amount = 2518
    options = {:ip=>"127.0.0.1",
      :return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?buyer_accepts_marketing=true&utm_nooverride=1",
      :cancel_return_url=>"http://localhost:3000/orders/1/8e06ea26f8add7608671d433f13c2193/commit_paypal?utm_nooverride=1",
      :customer=>"test6@test.com",
      :email=>"test6@test.com",
      :order_id=>"#1092",
      :currency=>"GBP",
      :subtotal=>2798,
      :items=> [
        {:name=>"test4",
          :description=>"test4",
          :quantity=>2,
          :amount=>1399,
          :url=>"http://localhost:3000/products/test4"},
        ],
      :discount=>280,
      :no_shipping=>false}
    response = @gateway.setup_authorization(amount, options)
    assert response.success?, response.message
  end
end
