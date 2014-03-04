require 'test_helper'

class KlarnaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @order_id = 1
    @credential1 = "Example Merchant ID"
    @options = {
      :amount           =>  Money.new(10.00),
      :currency         => 'EUR',
      :country          => 'SE',
      :account_name     => 'Example Shop Name',
      :credential2      => 'Example shared secret',
      :test             => false
    }

    @helper = Klarna::Helper.new(@order_id, @credential1, @options)
  end

  def test_mandatory_helper_fields
    assert_field 'purchase_country', @options[:country]
    assert_field 'purchase_currency', @options[:currency]

    assert_field 'locale', "Sv Se"
    STDERR.puts "Need to implement Klarna locale addition to helper options"
    
    assert_field 'merchant_id', @credential1

    example_cancel_url = "http://example-cancel-url"
    @helper.cancel_return_url("http://example-cancel-url")

    assert_field 'merchant_terms_uri', example_cancel_url
    assert_field 'merchant_checkout_uri', example_cancel_url
    assert_field 'merchant_base_uri', example_cancel_url
    assert_field 'merchant_confirmation_uri', example_cancel_url
    
    assert_field 'merchant_digest', 'd342717715b0550263290c604eb775ca024eafa3c675ba0d6d5c230a794427c7'
  end

  def test_platform_type
    skip

    platform_type = "some unknown klarna platform type"
    assert_field 'platform_type', platform_type
  end
end
