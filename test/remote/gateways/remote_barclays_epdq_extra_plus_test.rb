# coding: utf-8
require 'test_helper'

class RemoteBarclaysEpdqExtraPlusTest < Test::Unit::TestCase
  def setup
    @gateway = BarclaysEpdqExtraPlusGateway.new(fixtures(:barclays_epdq_extra_plus))
    @amount = 100
    @credit_card     = credit_card('4000100011112224')
    @declined_card   = credit_card('1111111111111111')
    @credit_card_d3d = credit_card('4000000000000002', :verification_value => '111')
    @options = {
      :order_id => generate_unique_id[0...30],
      :billing_address => address,
      :description => 'Store Purchase',
      :currency => fixtures(:barclays_epdq_extra_plus)[:currency] || 'GBP'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
    assert_equal @options[:currency], response.params["currency"]
    assert_equal @options[:order_id], response.order_id
  end

  def test_successful_purchase_with_minimal_info
    @options.delete(:billing_address)
    @options.delete(:description)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
    assert_equal @options[:currency], response.params["currency"]
    assert_equal @options[:order_id], response.order_id
  end

  def test_successful_purchase_with_utf8_encoding_1
    assert response = @gateway.purchase(@amount, credit_card('4000100011112224', :first_name => "Rémy", :last_name => "Fröåïør"), @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_purchase_with_utf8_encoding_2
    assert response = @gateway.purchase(@amount, credit_card('4000100011112224', :first_name => "ワタシ", :last_name => "ёжзийклмнопрсуфхцч"), @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
  end

  # NOTE: You have to set the "Hash algorithm" to "SHA-1" in the "Technical information"->"Global security parameters"
  #       section of your account admin before running this test
  def test_successful_purchase_with_signature_encryptor_to_sha1
    gateway = BarclaysEpdqExtraPlusGateway.new(fixtures(:barclays_epdq_extra_plus).merge(:signature_encryptor => 'sha1'))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
  end

  # NOTE: You have to set the "Hash algorithm" to "SHA-256" in the "Technical information"->"Global security parameters"
  #       section of your account admin before running this test
  def test_successful_purchase_with_signature_encryptor_to_sha256
    gateway = BarclaysEpdqExtraPlusGateway.new(fixtures(:barclays_epdq_extra_plus).merge(:signature_encryptor => 'sha256'))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
  end

  # NOTE: You have to set the "Hash algorithm" to "SHA-512" in the "Technical information"->"Global security parameters"
  #       section of your account admin before running this test
  def test_successful_purchase_with_signature_encryptor_to_sha512
    gateway = BarclaysEpdqExtraPlusGateway.new(fixtures(:barclays_epdq_extra_plus).merge(:signature_encryptor => 'sha512'))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_with_non_numeric_order_id
    @options[:order_id] = "##{@options[:order_id][0...26]}.12"
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_purchase_without_explicit_order_id
    @options.delete(:order_id)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'No brand', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_unsuccessful_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'No card no, no exp date, no brand', response.message
  end

  def test_successful_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, auth.message
    assert_success void
  end

=begin Enable if/when fully enabled account is available to test
  def test_reference_transactions
    # Setting an alias
    assert response = @gateway.purchase(@amount, credit_card('4000100011112224'), @options.merge(:billing_id => "awesomeman", :order_id=>Time.now.to_i.to_s+"1"))
    assert_success response
    # Updating an alias
    assert response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(:billing_id => "awesomeman", :order_id=>Time.now.to_i.to_s+"2"))
    assert_success response
    # Using an alias (i.e. don't provide the credit card)
    assert response = @gateway.purchase(@amount, "awesomeman", @options.merge(:order_id => Time.now.to_i.to_s + "3"))
    assert_success response
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, :billing_id => 'test_alias')
    assert_success response
    assert purchase = @gateway.purchase(@amount, 'test_alias')
    assert_success purchase
  end

  def test_successful_store_generated_alias
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert purchase = @gateway.purchase(@amount, response.billing_id)
    assert_success purchase
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, :billing_id => 'test_alias')
    assert_success response
    assert purchase = @gateway.purchase(@amount, 'test_alias')
    assert_success purchase
  end

  def test_successful_unreferenced_credit
    assert credit = @gateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert credit.authorization
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, credit.message
  end

  # NOTE: You have to allow USD as a supported currency in the "Account"->"Currencies"
  #       section of your account admin before running this test
  def test_successful_purchase_with_custom_currency_at_the_gateway_level
    gateway = BarclaysEpdqExtraPlusGateway.new(fixtures(:barclays_epdq_extra_plus).merge(:currency => 'USD'))
    assert response = gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
    assert_equal "USD", response.params["currency"]
  end

  # NOTE: You have to allow USD as a supported currency in the "Account"->"Currencies"
  #       section of your account admin before running this test
  def test_successful_purchase_with_custom_currency
    gateway = BarclaysEpdqExtraPlusGateway.new(fixtures(:barclays_epdq_extra_plus).merge(:currency => 'EUR'))
    assert response = gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'USD'))
    assert_success response
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
    assert_equal "USD", response.params["currency"]
  end

  # NOTE: You have to contact Barclays to make sure your test account allow 3D Secure transactions before running this test
  def test_successful_purchase_with_3d_secure
    assert response = @gateway.purchase(@amount, @credit_card_d3d, @options.merge(:d3d => true))
    assert_success response
    assert_equal '46', response.params["STATUS"]
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, response.message
    assert response.params["HTML_ANSWER"]
  end
=end

  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert refund.authorization
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, refund.message
  end

  def test_unsuccessful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert refund = @gateway.refund(@amount+1, purchase.authorization, @options) # too much refund requested
    assert_failure refund
    assert refund.authorization
    assert_equal 'Overflow in refunds requests', refund.message
  end

  def test_invalid_login
    gateway = BarclaysEpdqExtraPlusGateway.new(
                :login => '',
                :user => '',
                :password => '',
                :signature_encryptor => "none"
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Some of the data entered is incorrect. please retry.', response.message
  end
end
