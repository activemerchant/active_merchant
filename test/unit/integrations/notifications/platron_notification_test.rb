require 'test_helper'

class PlatronNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @correct_notification = Platron::Notification.new(http_raw_data_with_correct_signature, :secret => 'secret', :path => 'result')
    @notification_with_wrong_signature= Platron::Notification.new(http_raw_data_with_wrong_signature, :secret => 'secret',:path => 'result')
  end

  def test_accessors
    assert_equal '111', @correct_notification.order_id
    assert_equal '1023', @correct_notification.platron_payment_id
    assert_equal 'USD', @correct_notification.currency
    assert_equal '2013-01-02 10:14:20', @correct_notification.payment_date
    assert_equal '1', @correct_notification.complete?
    assert_equal 'Visa', @correct_notification.payment_system
    assert_equal 'VI', @correct_notification.card_brand
    assert_equal '990',@correct_notification.amount
  end

  def test_acknowledgement
    assert_equal @correct_notification.acknowledge, true
    assert_equal @notification_with_wrong_signature.acknowledge, false
  end

  def test_respond_to_acknowledge
    assert @correct_notification.respond_to?(:acknowledge)
  end

  def test_success_response
    xml_response = @correct_notification.success_response('result', 'secret')

    assert_nothing_raised do
      hash = Hash.from_xml(xml_response)
      assert_equal hash['response']['pg_status'],'ok'
      sign = Digest::MD5.hexdigest(
        [
          'result',
          {:pg_status => 'ok',:pg_salt => hash['response']['pg_salt']}.with_indifferent_access.sort.map{|ar|ar[1]},
          'secret'
        ].join(';')
      )
      assert_equal hash['response']['pg_sig'], sign
    end
  end

  private

  def test_response_params
    {
       :pg_result=>'1',:pg_order_id=>'111',:pg_payment_id=>'1023',:pg_amount=>'990',:pg_ps_currency=>'USD',
       :pg_payment_system=>'Visa',:pg_payment_date=>'2013-01-02 10:14:20',:pg_card_brand=>'VI',:pg_overpayment=>'0',
       :pg_salt=>'vfw87rb2vwevhj'
    }
  end

  def http_raw_data_with_correct_signature
    pg_sig= Digest::MD5.hexdigest(['result',test_response_params.with_indifferent_access.sort.map{|ar|ar[1]},'secret'].join(';'))
    test_response_params.merge({:pg_sig=>pg_sig}).to_param
  end

  def http_raw_data_with_wrong_signature
    pg_sig= 'wrong signature'
    test_response_params.merge({:pg_sig=>pg_sig}).to_param
  end

end
