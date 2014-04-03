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
  end

  def test_add_address_outsite_north_america
    @gateway.send(:add_address, @transaction, :billing_address => {:address1 => '164 Waverley Street', :country => 'DE', :state => ''})

    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], @transaction.fields.stringify_keys.keys.sort
    assert_equal 'n/a', @transaction.fields[:state]
    assert_equal '164 Waverley Street', @transaction.fields[:address]
    assert_equal 'DE', @transaction.fields[:country]
  end

  def test_add_address
    @gateway.send(:add_address, @transaction, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'})

    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], @transaction.fields.stringify_keys.keys.sort
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
    anet_credit_card = @gateway.send(:add_creditcard, @credit_card)

    assert_instance_of AuthorizeNet::CreditCard, anet_credit_card
    assert_equal '4242424242424242', anet_credit_card.card_number
    assert_equal "#{sprintf("%.2i", @credit_card.month)}#{sprintf("%.4i", @credit_card.year)[-2..-1]}", anet_credit_card.expiration
    assert_equal @credit_card.verification_value, anet_credit_card.card_code
  end

  def test_add_swipe_data_with_bad_data
    @credit_card.track_data = '%B378282246310005LONGSONLONGBOB1705101130504392?'
    anet_credit_card = @gateway.send(:add_creditcard, @credit_card)
    anet_credit_card = @gateway.send(:add_swipe_data, @credit_card, anet_credit_card)

    assert_instance_of AuthorizeNet::CreditCard, anet_credit_card
    assert_equal nil, anet_credit_card.track_1
    assert_equal nil, anet_credit_card.track_2
  end

  def test_add_swipe_data_with_track_1
    @credit_card.track_data = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
    anet_credit_card = @gateway.send(:add_creditcard, @credit_card)
    anet_credit_card = @gateway.send(:add_swipe_data, @credit_card, anet_credit_card)

    assert_instance_of AuthorizeNet::CreditCard, anet_credit_card
    assert_equal '%B378282246310005^LONGSON/LONGBOB^1705101130504392?', anet_credit_card.track_1
    assert_equal nil, anet_credit_card.track_2
  end

  def test_add_swipe_data_with_track_2
    @credit_card.track_data = ';4111111111111111=1803101000020000831?'
    anet_credit_card = @gateway.send(:add_creditcard, @credit_card)
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

  def test_supported_countries
    assert_equal ['US', 'CA', 'GB'], AuthorizeNetGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb], AuthorizeNetGateway.supported_cardtypes
  end

  # ARB Unit Tests
  def test_successful_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)

    response = @gateway.recurring(@amount, @credit_card,
      :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
      :interval => {
        :length => 10,
        :unit => :days
      },
      :duration => {
        :start_date => Time.now.strftime("%Y-%m-%d"),
        :occurrences => 30
      }
   )

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @subscription_id, response.authorization
  end

  def test_successful_update_recurring
    @gateway.expects(:ssl_post).returns(successful_update_recurring_response)

    response = @gateway.update_recurring(:subscription_id => @subscription_id, :amount => @amount * 2)

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @subscription_id, response.authorization
  end

  def test_successful_cancel_recurring
    @gateway.expects(:ssl_post).returns(successful_cancel_recurring_response)

    response = @gateway.cancel_recurring(@subscription_id)

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @subscription_id, response.authorization
  end

  def test_successful_status_recurring
    @gateway.expects(:ssl_post).returns(successful_status_recurring_response)

    response = @gateway.status_recurring(@subscription_id)
    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @subscription_status, response.params['status']
  end

  def test_expdate_formatting
    assert_equal '2009-09', @gateway.send(:arb_expdate, credit_card('4111111111111111', :month => "9", :year => "2009"))
    assert_equal '2013-11', @gateway.send(:arb_expdate, credit_card('4111111111111111', :month => "11", :year => "2013"))
  end

  private

  def successful_recurring_response
    <<-XML
<ARBCreateSubscriptionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
  <refId>Sample</refId>
  <messages>
    <resultCode>Ok</resultCode>
    <message>
      <code>I00001</code>
      <text>Successful.</text>
    </message>
  </messages>
  <subscriptionId>#{@subscription_id}</subscriptionId>
</ARBCreateSubscriptionResponse>
    XML
  end

  def successful_update_recurring_response
    <<-XML
<ARBUpdateSubscriptionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
  <refId>Sample</refId>
  <messages>
    <resultCode>Ok</resultCode>
    <message>
      <code>I00001</code>
      <text>Successful.</text>
    </message>
  </messages>
  <subscriptionId>#{@subscription_id}</subscriptionId>
</ARBUpdateSubscriptionResponse>
    XML
  end

  def successful_cancel_recurring_response
    <<-XML
<ARBCancelSubscriptionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
  <refId>Sample</refId>
  <messages>
    <resultCode>Ok</resultCode>
    <message>
      <code>I00001</code>
      <text>Successful.</text>
    </message>
  </messages>
  <subscriptionId>#{@subscription_id}</subscriptionId>
</ARBCancelSubscriptionResponse>
    XML
  end

  def successful_status_recurring_response
    <<-XML
<ARBGetSubscriptionStatusResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
  <refId>Sample</refId>
  <messages>
    <resultCode>Ok</resultCode>
    <message>
      <code>I00001</code>
      <text>Successful.</text>
    </message>
  </messages>
  <Status>#{@subscription_status}</Status>
</ARBGetSubscriptionStatusResponse>
    XML
  end
end
