require 'test_helper'

class RemoteEwayRapidTest < Test::Unit::TestCase
  def setup
    @gateway = EwayRapidGateway.new(fixtures(:eway_rapid))

    @amount = 100
    @failed_amount = -100
    @credit_card = credit_card("4444333322221111")

    @options = {
      :order_id => "1",
      :billing_address => address,
      :description => "Store Purchase",
      :redirect_url => "http://bogus.com"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved Successful", response.message
  end

  def test_fully_loaded_purchase
    assert response = @gateway.purchase(@amount, @credit_card,
      :redirect_url => "http://awesomesauce.com",
      :ip => "0.0.0.0",
      :application_id => "Woohoo",
      :transaction_type => "Purchase",
      :description => "Description",
      :order_id => "orderid1",
      :currency => "AUD",
      :email => "jim@example.com",
      :billing_address => {
        :title    => "Mr.",
        :name     => "Jim Awesome Smith",
        :company  => "Awesome Co",
        :address1 => "1234 My Street",
        :address2 => "Apt 1",
        :city     => "Ottawa",
        :state    => "ON",
        :zip      => "K1C2N6",
        :country  => "CA",
        :phone    => "(555)555-5555",
        :fax      => "(555)555-6666"
      },
      :shipping_address => {
        :title    => "Ms.",
        :name     => "Baker",
        :company  => "Elsewhere Inc.",
        :address1 => "4321 Their St.",
        :address2 => "Apt 2",
        :city     => "Chicago",
        :state    => "IL",
        :zip      => "60625",
        :country  => "US",
        :phone    => "1115555555",
        :fax      => "1115556666"
      }
    )
    assert_success response
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@failed_amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid Payment TotalAmount", response.message
  end

  def test_successful_refund
    # purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved Successful", response.message

    # refund
    assert response = @gateway.refund(@amount, response.authorization, @options)
    assert_success response
    assert_equal "Transaction Approved Successful", response.message
  end

  def test_failed_refund
    assert response = @gateway.refund(@amount, 'fakeid', @options)
    assert_failure response
    assert_equal "System Error", response.message
  end

  def test_successful_store
    @options[:billing_address].merge!(:title => "Dr.")
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved Successful", response.message
  end

  def test_failed_store
    @options[:billing_address].merge!(:country => nil)
    assert response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal "V6044", response.params["Errors"]
    assert_equal "Customer CountryCode Required", response.message
  end

  def test_successful_update
    @options[:billing_address].merge!(:title => "Dr.")
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved Successful", response.message
    assert response = @gateway.update(response.authorization, @credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved Successful", response.message
  end

  def test_successful_store_purchase
    @options[:billing_address].merge!(:title => "Dr.")
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved Successful", response.message

    assert response = @gateway.purchase(@amount, response.authorization, {transaction_type: 'MOTO'})
    assert_success response
    assert_equal "Transaction Approved Successful", response.message
  end

  def test_invalid_login
    gateway = EwayRapidGateway.new(
                :login => "bogus",
                :password => "bogus"
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Unauthorized", response.message
  end
end
