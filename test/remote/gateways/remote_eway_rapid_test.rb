require 'test_helper'

class RemoteEwayRapidTest < Test::Unit::TestCase
  def setup
    @gateway = EwayRapidGateway.new(fixtures(:eway_rapid))

    @amount = 100
    @failed_amount = 105
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
    assert_equal "Transaction Approved", response.message
  end

  def test_fully_loaded_purchase
    assert response = @gateway.purchase(@amount, @credit_card,
      :redirect_url => "http://awesomesauce.com",
      :ip => "0.0.0.0",
      :application_id => "Woohoo",
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
    assert_equal "Do Not Honour", response.message
  end

  def test_failed_setup_purchase
    assert response = @gateway.setup_purchase(@amount, :redirect_url => "")
    assert_failure response
    assert_equal "V6047", response.message
  end

  def test_failed_run_purchase
    setup_response = @gateway.setup_purchase(@amount, @options)
    assert_success setup_response

    assert response = @gateway.send(:run_purchase, "bogus", @credit_card, setup_response.params["formactionurl"])
    assert_failure response
    assert_match(%r{Access Code Invalid}, response.message)
  end

  def test_failed_status
    setup_response = @gateway.setup_purchase(@failed_amount, @options)
    assert_success setup_response

    assert run_response = @gateway.send(:run_purchase, setup_response.authorization, @credit_card, setup_response.params["formactionurl"])
    assert_success run_response

    response = @gateway.status(run_response.authorization)
    assert_failure response
    assert_equal "Do Not Honour", response.message
    assert_equal run_response.authorization, response.authorization
  end

  def test_successful_store
    @options[:billing_address].merge!(:title => "Dr.")
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved", response.message
  end

  def test_failed_store
    @options[:billing_address].merge!(:country => nil)
    assert response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal "V6044", response.message
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
