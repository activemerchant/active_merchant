require 'test_helper'

class MolpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @amount = "10.00"
    @secret_key = "molpay_skey"
    @account = "molpaytest"
    @orderid = 'order-10.00'

    @molpay = Molpay::Notification.new(http_raw_data(:success), :credential2 => @secret_key)
  end

  def test_accessors
    assert @molpay.complete?, "should be marked complete"
    assert_equal "Completed",           @molpay.status
    assert_equal "12345",               @molpay.transaction_id
    assert_equal @orderid,              @molpay.item_id
    assert_equal @amount,               @molpay.gross
    assert_equal "MYR",                 @molpay.currency
    assert_equal "2014-04-04 08:12:00", @molpay.received_at
    assert_equal @account,              @molpay.account
    assert_equal "maybank2u",           @molpay.channel
    assert_equal "auth123",             @molpay.auth_code
    assert_equal nil,                   @molpay.error_code
    assert_equal nil,                   @molpay.error_desc
    assert_equal generate_signature,    @molpay.security_key
    assert !@molpay.test?
  end

  def test_transaction_test
    molpay = Molpay::Notification.new(http_raw_data(:test), :credential2 => @secret_key)
    assert molpay.test?
  end
  
  def test_acknowledgement
    assert @molpay.acknowledge
  end

  def test_unsuccessful_acknowledge_due_to_signature
    molpay = Molpay::Notification.new(http_raw_data(:invalid_skey), :credential2 => @secret_key)
    assert !molpay.acknowledge
  end

  def test_unsuccessful_acknowledge_due_to_missing_amount
    molpay = Molpay::Notification.new(http_raw_data(:missing_amount), :credential2 => @secret_key)
    assert !molpay.acknowledge
  end

  def test_unsuccessful_acknowledge_due_to_payment_failed
    molpay = Molpay::Notification.new(http_raw_data(:payment_failed), :credential2 => @secret_key)
    assert !molpay.acknowledge
  end


  private

  def http_raw_data(mode=:success)
    basedata = { 'amount'   => @amount,
                 'orderid'  => @orderid,
                 'appcode'  => 'auth123',
                 'tranID'   => '12345',
                 'domain'   => @account,
                 'currency' => 'MYR',
                 'paydate'  => '2014-04-04 08:12:00',
                 'channel'  => 'maybank2u',
                 'status'   => '00',
                 'skey'     => generate_signature
               }

    case mode
    when :success
      basedata.collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
    when :payment_failed
      basedata.merge("status" => "11", "error_code" => "404", "error_desc" => "Payment Failed").collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
    when :invalid_skey
      basedata.merge('skey' => 'hoax').collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
    when :missing_amount
      basedata.reject{|k| k=='amount'}.collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
    when :test
      r = ['amount','appcode','error_code', 'error_desc', 'skey']
      basedata.reject{|k| r.include?(k)}.collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
    end
    
  end

  def generate_signature
    Digest::MD5.hexdigest("#{@amount}#{@account}#{@orderid}#{@secret_key}")
  end
end
