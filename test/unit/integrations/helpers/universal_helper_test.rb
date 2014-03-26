require 'test_helper'

class UniversalHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @order = 'order-500'
    @account = 'zork'
    @key = 'TO78ghHCfBQ6ZBw2Q2fJ3wRwGkWkUHVs'
    @amount = 12345
    @currency = 'USD'
    @test = false
    @country = 'US'
    @account_name = 'Widgets Inc'
    @transaction_type = 'sale'
    @forward_url = 'https://bork.com/pay'
    @options = {
                :amount => @amount,
                :currency => @currency,
                :test => @test,
                :credential2 => @key,
                :country => @country,
                :account_name => @account_name,
                :transaction_type => @transaction_type,
                :forward_url => @forward_url,
              }
    @helper = Universal::Helper.new(@order, @account, @options)
    @helper.form_fields # initialize some additional fields
  end

  def test_core_fields
    @helper.shipping 678
    @helper.tax 90
    @helper.description 'Box of Red Wine'
    @helper.invoice 'Invoice #1A'

    assert_field 'x-id', @account
    assert_field 'x-currency', @currency
    assert_field 'x-amount', @amount.to_s
    assert_field 'x-amount-shipping', '678'
    assert_field 'x-amount-tax', '90'
    assert_field 'x-reference', @order
    assert_field 'x-shop-country', @country
    assert_field 'x-shop-name', @account_name
    assert_field 'x-transaction-type', @transaction_type
    assert_field 'x-description', 'Box of Red Wine'
    assert_field 'x-invoice', 'Invoice #1A'
    assert_field 'x-test', @test.to_s
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', :phone => '(123) 456-7890'
    assert_field 'x-customer-first-name', 'Cody'
    assert_field 'x-customer-last-name', 'Fauser'
    assert_field 'x-customer-email', 'cody@example.com'
    assert_field 'x-customer-phone', '(123) 456-7890'
  end

  def test_address_fields
    @helper.billing_address :city => 'Leeds',
                            :company => 'Shopify Inc',
                            :address1 => '1 My Street',
                            :address2 => '2nd floor',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country => 'CA',
                            :phone => '(987) 645-3210'

    assert_field 'x-customer-city', 'Leeds'
    assert_field 'x-customer-company', 'Shopify Inc'
    assert_field 'x-customer-address1', '1 My Street'
    assert_field 'x-customer-address2', '2nd floor'
    assert_field 'x-customer-state', 'Yorkshire'
    assert_field 'x-customer-zip', 'LS2 7EE'
    assert_field 'x-customer-country', 'CA'
    assert_field 'x-customer-phone', '(987) 645-3210'
  end

  def test_url_fields
    @helper.notify_url 'https://zork.com/notify'
    @helper.return_url 'https://zork.com/return'
    @helper.cancel_return_url 'https://zork.com/cancel'

    assert_field 'x-url-callback', 'https://zork.com/notify'
    assert_field 'x-url-complete', 'https://zork.com/return'
    assert_field 'x-url-cancel', 'https://zork.com/cancel'
  end

end
