require File.dirname(__FILE__) + '/../../../test_helper'

# Replace with the correct codes
$<%= file_name %>_success = Class.new do
  def body; "SUCCESS"; end
end

$<%= file_name %>_failure = Class.new do
  def body; "FAIL"; end
end


class <%= class_name %>NotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @<%= file_name %> = <%= class_name %>::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @<%= file_name %>.complete?
    assert_equal "", @<%= file_name %>.status
    assert_equal "", @<%= file_name %>.transaction_id
    assert_equal "", @<%= file_name %>.item_id
    assert_equal "", @<%= file_name %>.gross
    assert_equal "", @<%= file_name %>.currency
    assert_equal "", @<%= file_name %>.received_at
    assert @<%= file_name %>.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @<%= file_name %>.amount
  end

  def test_acknowledgement    
    Net::HTTP.mock_methods( :request => Proc.new { |r, b| $<%= file_name %>_success.new } ) do     
      assert @<%= file_name %>.acknowledge        
    end

    Net::HTTP.mock_methods( :request => Proc.new { |r, b| $<%= file_name %>_failure.new } ) do 
      assert !@<%= file_name %>.acknowledge
    end
  end

  def test_send_acknowledgement
    request, body = nil
    
    Net::HTTP.mock_methods( :request => Proc.new { |r, b| request = r; body = b; $<%= file_name %>_success.new } ) do     
      assert @<%= file_name %>.acknowledge        
    end

    assert_equal '', request.path
    assert_equal http_raw_data, body
  end

  def test_respond_to_acknowledge
    assert @<%= file_name %>.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end  
end
