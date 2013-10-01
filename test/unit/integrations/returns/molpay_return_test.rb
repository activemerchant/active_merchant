require "test_helper"

class MolpayReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @molpay = build_return(http_raw_data)
  end

  def test_accessors
    assert_equal "test5620",           	 				 			@molpay.account
    assert_equal 6,                              			@molpay.order
    assert_equal "5.00",                         			@molpay.amount
    assert_equal "MYR",                          			@molpay.currency
    assert_equal "12345",                        			@molpay.transaction
    assert_equal "2541c99f9fa3cd9971637f5f67bdf02a",  @molpay.auth_code
    assert_equal "1",                            			@molpay.status
		assert_equal "11245",												 			@molpay.appcode
		assert_equal "2013/09/30",									 			@molpay.paydate
		assert_equal "m2u",			 										 			@molpay.channel
  end

  def test_successful_return
    params = parameterize(payload)
    Molpay::Return.any_instance.expects(:ssl_post).with(Molpay.service_url, params,
      { "Content-Length" => params.size.to_s, "User-Agent" => "Active Merchant -- http://activemerchant.org" }
    ).returns("00")

    assert @molpay.success?
  end

  def test_unsuccessful_return_due_to_payment_failed
    params = parameterize(payload)
    Molpay::Return.any_instance.expects(:ssl_post).with(Molpay.service_url, params,
      { "Content-Length" => params.size.to_s, "User-Agent" => "Active Merchant -- http://activemerchant.org" }
    ).returns("11")
    molpay = build_return(http_raw_data(:payment_failed))
    assert molpay.success?
  end

  private
  def http_raw_data(mode=:success)
    base = { "domain" 			=>  "test5620",
             "orderid"      =>  "6",
             "amount"       =>  "5.00",
             "currency"     =>  "MYR",
             "tranID"       =>  "12345",
						 "appcode"			=>  "auth123",
             "skey"     	  =>  "2541c99f9fa3cd9971637f5f67bdf02a",
             "status"       =>  00,
						 "paydate"			=>  "2013/09/30",
             "channel"      =>  "m2u" }

    case mode
    when :success
      parameterize(base.merge("status" => 00))
    when :payment_failed
      parameterize(base.merge("status" => 11))
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

  def build_return(data)
    Molpay::Return.new(data, :credential2 => "molpay")
  end
end
