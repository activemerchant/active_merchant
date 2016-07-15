require 'test_helper'
require 'net/http'

class RemoteMigsTest < Test::Unit::TestCase
  include ActiveMerchant::NetworkConnectionRetries
  include ActiveMerchant::PostsData

  def setup
    @gateway = MigsGateway.new(fixtures(:migs))

    @amount = 100
    @declined_amount = 105
    @visa   = credit_card('4005550000000001', :month => 5, :year => 2017, :brand => 'visa')
    @master = credit_card('5123456789012346', :month => 5, :year => 2017, :brand => 'master')
    @amex   = credit_card('371449635311004',  :month => 5, :year => 2017, :brand => 'american_express')
    @diners = credit_card('30123456789019',   :month => 5, :year => 2017, :brand => 'diners_club')
    @credit_card = @visa

    @options = {
      :order_id => '1',
      :currency => 'SAR'
    }
  end

  def test_server_purchase_url
    options = {
      :order_id   => 1,
      :unique_id  => 9,
      :return_url => 'http://localhost:8080/payments/return',
      :currency => 'SAR'
    }

    choice_url = @gateway.purchase_offsite_url(@amount, options)

    assert_response_match /Pay securely .* by clicking on the card logo below/, choice_url

    responses = {
      'visa'             => /You have chosen .*VISA.*/,
      'master'           => /You have chosen .*MasterCard.*/,
      'diners_club'      => /You have chosen .*Diners Club.*/,
      'american_express' => /You have chosen .*American Express.*/
    }

    responses.each_pair do |card_type, response_text|
      url = @gateway.purchase_offsite_url(@amount, options.merge(:card_type => card_type))
      assert_response_match response_text, url
    end
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_refund
    assert payment_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success payment_response
    assert response = @gateway.refund(@amount, payment_response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_status
    purchase_response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert response = @gateway.status(purchase_response.params['MerchTxnRef'])
    assert_equal 'Y', response.params['DRExists']
    assert_equal 'N', response.params['FoundMultipleDRs']
  end

  def test_invalid_login
    gateway = MigsGateway.new(:login => '', :password => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Required field vpc_Merchant was not present in the request', response.message
  end

  private

  def assert_response_match(regexp, url)
    response = https_response(url)
    assert_match regexp, response.body
  end

  def https_response(url, cookie = nil)
    retry_exceptions do
      headers = cookie ? {'Cookie' => cookie} : {}
      response = raw_ssl_request(:get, url, nil, headers)
      if response.is_a?(Net::HTTPRedirection)
        new_cookie = [cookie, response['Set-Cookie']].compact.join(';')
        response = https_response(response['Location'], new_cookie)
      end
      response
    end
  end
end
