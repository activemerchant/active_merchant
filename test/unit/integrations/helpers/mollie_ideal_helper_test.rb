require 'test_helper'

class MollieIdealHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  FETCH_XML_RESPONSE = <<-XML
      <?xml version="1.0"?>
      <response>
          <order>
              <transaction_id>482d599bbcc7795727650330ad65fe9b</transaction_id>
              <amount>123</amount>
              <currency>EUR</currency>
              <URL>https://mijn.postbank.nl/internetbankieren/SesamLoginServlet?sessie=ideal&amp;trxid=003123456789123&amp;random=123456789abcdefgh</URL>
              <message>Your iDEAL-payment has succesfuly been setup. Your customer should visit the given URL to make the payment</message>
          </order>
      </response>
  XML

  def setup
    @required_options = {
      :account_name => "My shop",
      :amount => 500,
      :currency => 'EUR',
      :redirect_param => 9999,
      :return_url => 'https://return.com',
      :notify_url => 'https://notify.com'
    }

    @helper = MollieIdeal::Helper.new('order-500','1234567', @required_options)
  end

  def test_request_redirect_uri
    MollieIdeal.expects(:mollie_api_request).returns(REXML::Document.new(FETCH_XML_RESPONSE))
    uri = @helper.request_redirect_uri
    assert_equal "https://mijn.postbank.nl/internetbankieren/SesamLoginServlet?sessie=ideal&trxid=003123456789123&random=123456789abcdefgh", uri.to_s
  end

  def test_credential_based_url
    MollieIdeal.expects(:mollie_api_request).returns(REXML::Document.new(FETCH_XML_RESPONSE))
    uri = @helper.credential_based_url
    assert_equal 'https://mijn.postbank.nl/internetbankieren/SesamLoginServlet', uri
    assert_equal({"sessie" => "ideal", "trxid" => "003123456789123", "random" => "123456789abcdefgh"}, @helper.fields)
  end

  def test_raises_without_required_options
    assert_raises(ArgumentError) { MollieIdeal::Helper.new('order-500','1234567', @required_options.merge(:redirect_param => nil)) }
    assert_raises(ArgumentError) { MollieIdeal::Helper.new('order-500','1234567', @required_options.merge(:return_url => nil)) }
    assert_raises(ArgumentError) { MollieIdeal::Helper.new('order-500','1234567', @required_options.merge(:notify_url => nil)) }
    assert_raises(ArgumentError) { MollieIdeal::Helper.new('order-500','1234567', @required_options.merge(:account_name => nil)) }
  end

  def test_append_get_parameter
    new_uri = @helper.append_get_parameter('http://example.com', :test, 123)
    assert_equal "http://example.com?test=123", new_uri

    new_uri = @helper.append_get_parameter('http://example.com?a=b', :test, '&')
    assert_equal "http://example.com?a=b&test=%26", new_uri
  end
end
