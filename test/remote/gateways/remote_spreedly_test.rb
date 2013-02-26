require 'test_helper'
require 'crack'
require 'httparty'
require 'pry'

class RemoteSpreedlyTest < Test::Unit::TestCase
  include ActiveMerchant::PostsData

  def setup
    @spreedly_fixture = fixtures(:spreedly)
    @gateway = SpreedlyGateway.new(@spreedly_fixture)

    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('40003000111122')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }

    @invoice_request = @spreedly_fixture[:invoice_request].to_xml root: 'invoice'
  end

  def test_successful_purchase
    @options = generate_invoice
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_purchase
    @options = generate_invoice

    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  private

  def generate_invoice
    url = "#{@gateway.test_url}/api/v4/#{@spreedly_fixture[:short_site_name]}/invoices.xml"
    options = {
      basic_auth: {
        username: @spreedly_fixture[:api_key],
        password: 'X'
      },
      headers: {
        'Content-Type' => 'application/xml'
      },
      body: @invoice_request
    }
    
    response = HTTParty.post url, options
  end
end