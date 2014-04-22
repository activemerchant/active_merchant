require 'test_helper'

class AuthorizeNetTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AuthorizeNetXmlGateway.new(
        :login => 'X',
        :password => 'Y'
    )

    @transaction = @gateway.send(:get_transaction)
    @amount = 100
    @credit_card = credit_card
    @subscription_id = '100748'
    @subscription_status = 'active'
    @check = check

    @recurring_options = {
        :amount => 23.67,
        :subscription_name => 'Test Subscription 1',
        :credit_card => @credit_card,
        :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
        :interval => {
            :length => 2,
            :unit => :months
        },
        :duration => {
            :start_date => Date.today,
            :occurrences => 1
        },
        :invoice_number => rand,
        :subscription_id => 12345
    }

  end

  def test_add_address_outsite_north_america
    @gateway.send(:add_address, @transaction, :billing_address => {:address1 => '164 Waverley Street', :country => 'DE', :state => ''})

    assert_equal ["address", "city", "company", "country", "fax", "phone", "state", "zip"], @transaction.fields.stringify_keys.keys.sort
    assert_equal 'n/a', @transaction.fields[:state]
    assert_equal '164 Waverley Street', @transaction.fields[:address]
    assert_equal 'DE', @transaction.fields[:country]
  end

  def test_add_address
    @gateway.send(:add_address, @transaction, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'})

    assert_equal ["address", "city", "company", "country", "fax", "phone", "state", "zip"], @transaction.fields.stringify_keys.keys.sort
    assert_equal 'CO', @transaction.fields[:state]
    assert_equal '164 Waverley Street', @transaction.fields[:address]
    assert_equal 'US', @transaction.fields[:country]
  end

  def test_add_invoice
    @gateway.send(:add_invoice, @transaction, :order_id => '#1001', :description => 'My Purchase is great')

    assert_equal '#1001', @transaction.fields[:invoice_num]
    assert_equal 'My Purchase is great', @transaction.fields[:description]
  end

  def test_add_duplicate_window_without_duplicate_window
    @gateway.class.duplicate_window = nil
    @gateway.send(:add_duplicate_window, @transaction)

    assert_nil @transaction.fields[:duplicate_window]
  end

  def test_add_duplicate_window_with_duplicate_window
    @gateway.class.duplicate_window = 0
    @gateway.send(:add_duplicate_window, @transaction)

    assert_equal 0, @transaction.fields[:duplicate_window]
  end

  def test_add_customer_data
    options = {:cardholder_authentication_value => 'E0Mvq8AAABEiMwARIjNEVWZ3iJk=',
               :authentication_indicator => '2',
               :ip => 'what is this?',
               :customer => 7.5,
               :email => 'none@noway.com'}
    @gateway.send(:add_customer_data, @transaction, options)

    assert_equal 'E0Mvq8AAABEiMwARIjNEVWZ3iJk=', @transaction.fields[:cardholder_authentication_value]
    assert_equal '2', @transaction.fields[:authentication_indicator]
    assert_equal 'what is this?', @transaction.fields[:customer_ip]
    assert_equal 7.5, @transaction.fields[:cust_id]
    assert_equal 'none@noway.com', @transaction.fields[:email]
    assert_equal false, @transaction.fields[:email_customer]
  end

  def test_add_customer_data_with_bad_data
    options = {:customer => 'x'}
    @gateway.send(:add_customer_data, @transaction, options)

    assert_equal nil, @transaction.fields[:cust_id]
  end

  def test_add_credit_card
    anet_credit_card = @gateway.send(:add_credit_card, @credit_card)

    assert_instance_of AuthorizeNet::CreditCard, anet_credit_card
    assert_equal '4242424242424242', anet_credit_card.card_number
    assert_equal "#{sprintf("%.2i", @credit_card.month)}#{sprintf("%.4i", @credit_card.year)[-2..-1]}", anet_credit_card.expiration
    assert_equal @credit_card.verification_value, anet_credit_card.card_code
  end

  def test_add_swipe_data_with_bad_data
    @credit_card.track_data = '%B378282246310005LONGSONLONGBOB1705101130504392?'
    anet_credit_card = @gateway.send(:add_credit_card, @credit_card)
    anet_credit_card = @gateway.send(:add_swipe_data, @credit_card, anet_credit_card)

    assert_instance_of AuthorizeNet::CreditCard, anet_credit_card
    assert_equal nil, anet_credit_card.track_1
    assert_equal nil, anet_credit_card.track_2
  end

  def test_add_swipe_data_with_track_1
    @credit_card.track_data = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
    anet_credit_card = @gateway.send(:add_credit_card, @credit_card)
    anet_credit_card = @gateway.send(:add_swipe_data, @credit_card, anet_credit_card)

    assert_instance_of AuthorizeNet::CreditCard, anet_credit_card
    assert_equal '%B378282246310005^LONGSON/LONGBOB^1705101130504392?', anet_credit_card.track_1
    assert_equal nil, anet_credit_card.track_2
  end

  def test_add_swipe_data_with_track_2
    @credit_card.track_data = ';4111111111111111=1803101000020000831?'
    anet_credit_card = @gateway.send(:add_credit_card, @credit_card)
    anet_credit_card = @gateway.send(:add_swipe_data, @credit_card, anet_credit_card)

    assert_instance_of AuthorizeNet::CreditCard, anet_credit_card
    assert_equal ';4111111111111111=1803101000020000831?', anet_credit_card.track_2
    assert_equal nil, anet_credit_card.track_1
  end

  def test_add_check
    anet_check = @gateway.send(:add_check, @check)

    assert_instance_of AuthorizeNet::ECheck, anet_check
    assert_equal check.routing_number, anet_check.routing_number
    assert_equal check.account_number, anet_check.account_number
    assert_equal check.bank_name, anet_check.bank_name
    assert_equal check.name, anet_check.account_holder_name
    assert_equal check.account_type.upcase, anet_check.account_type
    assert_equal check.number, anet_check.check_number
  end

  # ARB Unit Tests
  def test_update_recurring_data_mapping

    subscription = @gateway.send(:update_recurring_data, @recurring_options)
    assert_instance_of AuthorizeNet::ARB::Subscription, subscription

    assert_equal 12345, subscription.subscription_id
    assert_equal 23.67, subscription.amount
    assert_equal @recurring_options[:subscription_name], subscription.name
    assert_equal @recurring_options[:interval][:length], subscription.length
    assert_equal "months", subscription.unit
    assert_equal @recurring_options[:duration][:start_date], subscription.start_date
    assert_equal @recurring_options[:duration][:occurrences], subscription.total_occurrences
    assert_equal @recurring_options[:invoice_number], subscription.invoice_number

    assert_instance_of AuthorizeNet::CreditCard, subscription.credit_card

    #attr_accessor :card_number, :expiration, :card_code, :card_type, :track_1, :track_2
    assert_equal @recurring_options[:credit_card].card_number, subscription.credit_card.card_number
    assert_equal 'visa', subscription.credit_card.card_type

    assert_instance_of AuthorizeNet::Address, subscription.billing_address
    assert_equal @recurring_options[:billing_address].first_name, subscription.billing_address.first_name
    assert_equal 'Smith', subscription.billing_address.last_name
  end
=begin
  def test_build_active_merchant_subscription_response
    transaction = AuthorizeNet::ARB::Transaction.new("login_key","transaction_key")

    anet_subscription_response = AuthorizeNet::ARB::Response.new("raw_transaction", transaction)

    #<ActiveMerchant::Billing::Response:0x00000003630738>
    nil
    Hash (4 element(s))
    Hash (2 element(s))
    nil
    "The credit card has expired."
    Hash (9 element(s))
    #<Net::HTTPOK:0x000000036840e0>
    #<AuthorizeNet::ARB::Transaction:0x000000036ab4d8>
    <ARBCreateSubscriptionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">   <messages>     <resultCode>Error</resultCode>     <message>       <code>E00013</code>       <text>The credit card has expired.</text>     </message>     <message>       <code>E00018</code>       <text>Credit Card expires before the start of the subscription.</text>     </message>   </messages> </ARBCreateSubscriptionResponse>
Error
E00013
The credit card has expired.
nil
nil
nil
false
true

    response = @gateway.send(:build_active_merchant_subscription_response, anet_subscription_response)

    assert_instance_of ActiveMerchant::Billing::Response, response
    #assert_equals

  end
=end
end