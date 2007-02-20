require File.dirname(__FILE__) + '/../../../test_helper'

$nochex_success = Class.new do
  def body; "AUTHORISED"; end
end

$nochex_failure = Class.new do
  def body; "DECLINED"; end
end


class NochexNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @nochex = Nochex::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @nochex.complete?
    assert_equal "Completed", @nochex.status
    assert_equal "91191", @nochex.transaction_id
    assert_equal "11", @nochex.item_id
    assert_equal "31.66", @nochex.gross
    assert_equal "GBP", @nochex.currency
    assert_equal Time.utc(2006, 9, 27, 22, 30, 53), @nochex.received_at
    assert @nochex.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'GBP'), @nochex.amount
  end

  def test_acknowledgement    
    Net::HTTP.mock_methods( :request => Proc.new { |r, b| $nochex_success.new } ) do     
      assert @nochex.acknowledge        
    end

    Net::HTTP.mock_methods( :request => Proc.new { |r, b| $nochex_failure.new } ) do 
      assert !@nochex.acknowledge
    end
  end

  def test_send_acknowledgement
    request, body = nil
    
    Net::HTTP.mock_methods( :request => Proc.new { |r, b| request = r; body = b; $nochex_success.new } ) do     
      assert @nochex.acknowledge        
    end

    assert_equal '/nochex.dll/apc/apc', request.path
    assert_equal http_raw_data, body
  end

  def test_respond_to_acknowledge
    assert @nochex.respond_to?(:acknowledge)
  end
  
  def test_nil_notification
    notification = Nochex::Notification.new(nil)
    
    Net::HTTP.mock_methods( :request => Proc.new { |r, b| request = r; body = b; $nochex_failure.new } ) do     
      assert !notification.acknowledge    
    end
  end

  private
  def http_raw_data
    "transaction_date=27/09/2006 22:30:53&transaction_id=91191&order_id=11&from_email=test2@nochex.com&to_email=test1@nochex.com&amount=31.66&security_key=L254524366479818252491366&status=test&custom="
  end  
end
