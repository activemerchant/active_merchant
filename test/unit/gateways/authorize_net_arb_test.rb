require 'test_helper'

class AuthorizeNetArbTest < Test::Unit::TestCase
  include CommStub

  def setup
    AuthorizeNetArbGateway.any_instance.expects(:deprecated).with("ARB functionality in ActiveMerchant is deprecated and will be removed in a future version. Please contact the ActiveMerchant maintainers if you have an interest in taking ownership of a separate gem that continues support for it.")
    @gateway = AuthorizeNetArbGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    @amount = 100
    @credit_card = credit_card
    @subscription_id = '100748'
    @subscription_status = 'active'
  end

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
    assert_equal '2009-09', @gateway.send(:expdate, credit_card('4111111111111111', :month => "9", :year => "2009"))
    assert_equal '2013-11', @gateway.send(:expdate, credit_card('4111111111111111', :month => "11", :year => "2013"))
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
