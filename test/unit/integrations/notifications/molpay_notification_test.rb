#MOLPay notification test
require 'test_helper'

class MolpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @molpay = Molpay::Notification.new(http_raw_data, :credential2 => '1a2d20c7150f42e37cfe1b87879fe5cb')
  end

  def test_accessors
    assert @molpay.complete?
    assert_equal "", @molpay.status
    assert_equal "", @molpay.transaction_id
    assert_equal "", @molpay.item_id
    assert_equal "", @molpay.gross
    assert_equal "", @molpay.currency
    assert_equal "", @molpay.received_at
    assert @molpay.test?
  end

  def test_successful_return
    params = parameterize(payload)
    Molpay::Notification.any_instance.expects(:ssl_post).with(Molpay.service_url, params,
      { "Content-Length" => params.size.to_s, "User-Agent" => "Active Merchant -- http://activemerchant.org" }
    ).returns("00")

    assert @molpay.success?
  end

  def test_unsuccessful_return_due_to_payment_failed
    params = parameterize(payload)
    Molpay::Notification.any_instance.expects(:ssl_post).with(Molpay.service_url, params,
      { "Content-Length" => params.size.to_s, "User-Agent" => "Active Merchant -- http://activemerchant.org" }
    ).returns("11")
    molpay = build_return(http_raw_data(:payment_failed))
    assert @molpay.success?
  end

  private
  def http_raw_data(mode=:success)
    base = { "domain" 	    =>  "test5620",
             "orderid"      =>  "6",
             "amount"       =>  "5.00",
             "currency"     =>  "RM",
             "tranID"       =>  "1234567",
             "appcode"      =>  "auth123",
             "skey"         =>  '2541c99f9fa3cd9971637f5f67bdf02a',
             "status"       =>  '00',
             "paydate"	    =>  "2013-11-28 09:43:34",
             "channel"      =>  "Trial" }

    case mode
      when :success
        parameterize(base.merge("status" => '00'))
      when :payment_failed
        parameterize(base.merge("status" => '11'))
      else
        ""
    end
  end

  def payload
    { "domain" => "test5620", "RefNo" => "6", "Amount" => "5.00" }
  end

  def parameterize(params)
    params.reject{|k, v| v.blank?}.keys.sort.collect { |key| "#{key}=#{CGI.escape(params[key].to_s)}" }.join("&")
  end
end
