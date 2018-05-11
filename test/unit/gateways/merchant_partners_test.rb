require "test_helper"
require "nokogiri"

class MerchantPartnersTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MerchantPartnersGateway.new(
      account_id: "TEST0",
      merchant_pin: "1234567890"
    )

    @credit_card = credit_card
    @amount = 100

    @request_root = "/interface_driver/trans_catalog/transaction/inputs"
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal @credit_card.name, root.at_xpath("//ccname").content
        assert_equal @credit_card.number, root.at_xpath("//ccnum").content
        assert_equal @credit_card.verification_value, root.at_xpath("//cvv2").content
        assert_equal "2", root.at_xpath("//service").content
        assert_equal "1.00", root.at_xpath("//amount").content
      end
    end.respond_with(successful_purchase_response)

    assert_success response
    assert response.test?
    assert_equal "398182213", response.authorization
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Invalid account number", response.message
    assert response.params["result"].start_with?("DECLINED")
    assert response.test?
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal @credit_card.name, root.at_xpath("//ccname").content
        assert_equal @credit_card.number, root.at_xpath("//ccnum").content
        assert_equal @credit_card.verification_value, root.at_xpath("//cvv2").content
        assert_equal "1", root.at_xpath("//service").content
        assert_equal "1.00", root.at_xpath("//amount").content
      end
    end.respond_with(successful_authorize_response)

    assert_success response
    assert response.test?
    assert_equal "398047747", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal response.authorization, root.at_xpath("//historykeyid").content
        assert_equal "3", root.at_xpath("//service").content
        assert_equal "1.00", root.at_xpath("//amount").content
      end
    end.respond_with(successful_capture_response)

    assert_success capture
    assert capture.test?
    assert_equal "398044113", capture.authorization
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Invalid account number", response.message
    assert response.params["result"].start_with?("DECLINED")
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, "")
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "398047747", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal response.authorization, root.at_xpath("//historykeyid").content
        assert_equal "5", root.at_xpath("//service").content
      end
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void("5d53a33d960c46d00f5dc061947d998c")
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal response.authorization, root.at_xpath("//historykeyid").content
        assert_equal "4", root.at_xpath("//service").content
        assert_equal "1.00", root.at_xpath("//amount").content
      end
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal @credit_card.name, root.at_xpath("//ccname").content
        assert_equal @credit_card.number, root.at_xpath("//ccnum").content
        assert_equal @credit_card.verification_value, root.at_xpath("//cvv2").content
        assert_equal "6", root.at_xpath("//service").content
        assert_equal "1.00", root.at_xpath("//amount").content
      end
    end.respond_with(successful_credit_response)

    assert_success response
    assert response.test?
  end

  def test_failed_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(failed_credit_response)

    assert_failure response
    assert_equal "Invalid account number", response.message
    assert response.params["result"].start_with?("DECLINED")
    assert response.test?
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "Invalid account number", response.message
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal @credit_card.name, root.at_xpath("//ccname").content
        assert_equal @credit_card.number, root.at_xpath("//ccnum").content
        assert_equal @credit_card.verification_value, root.at_xpath("//cvv2").content
        assert_equal "7", root.at_xpath("//service").content
      end
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal "Succeeded", response.message
    assert_equal "17522090|6781", response.authorization
    assert response.test?
  end

  def test_successful_stored_purchase
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal "Succeeded", response.message
    assert_equal "17522090|6781", response.authorization
    assert response.test?

    purchase = stub_comms do
      @gateway.purchase(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal response.params["userprofileid"], root.at_xpath("//userprofileid").content
        assert_equal response.params["last4digits"], root.at_xpath("//last4digits").content
        assert_equal "8", root.at_xpath("//service").content
        assert_equal "1.00", root.at_xpath("//amount").content
      end
    end.respond_with(successful_purchase_response)

    assert_success purchase
    assert purchase.test?
  end

  def test_successful_stored_credit
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal "Succeeded", response.message
    assert_equal "17522090|6781", response.authorization
    assert response.test?

    credit = stub_comms do
      @gateway.credit(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil root = doc.at_xpath(@request_root)
        assert_equal @gateway.options[:account_id], root.at_xpath("//acctid").content
        assert_equal @gateway.options[:merchant_pin], root.at_xpath("//merchantpin").content
        assert_equal response.params["userprofileid"], root.at_xpath("//userprofileid").content
        assert_equal response.params["last4digits"], root.at_xpath("//last4digits").content
        assert_equal "13", root.at_xpath("//service").content
        assert_equal "1.00", root.at_xpath("//amount").content
      end
    end.respond_with(successful_purchase_response)

    assert_success credit
    assert credit.test?
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal "Live Transactions Not Allowed", response.message
    assert response.params["result"].start_with?("DECLINED")
    assert response.test?
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def parse(data)
    Nokogiri::XML(data).tap do |doc|
      doc.remove_namespaces!
      yield(doc) if block_given?
    end
  end

  def successful_purchase_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Approved</status>
<accountname>Longbob Longsen</accountname>
<result>AVSSALE:TEST:::398182213:N::U</result>
<authcode>TEST</authcode>
<historyid>398182213</historyid>
<orderid>287915678</orderid>
<refcode>398182213</refcode>
<total>1.0</total>
<merchantordernumber>252e218a23e7b3af6d74b4f371e4a0a8</merchantordernumber>
<last4digits>6781</last4digits>
<avsresult>N</avsresult>
<cvv2result>U</cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def failed_purchase_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Declined</status>
<accountname>Longbob Longsen</accountname>
<result>DECLINED:1102140001:Invalid account number:</result>
<authcode></authcode>
<historyid>398045105</historyid>
<orderid>287819971</orderid>
<refcode>398045105</refcode>
<total>1.0</total>
<merchantordernumber>cf704493db5e5c8ba3f6c91a3fd2105c</merchantordernumber>
<last4digits>6782</last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def successful_authorize_response
    %(<?xml version="1.0"?>
<interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Approved</status>
<accountname>Longbob Longsen</accountname>
<result>AVSAUTH:TEST:::398047747:N::U</result>
<authcode>TEST</authcode>
<historyid>398047747</historyid>
<orderid>287809633</orderid>
<refcode>398047747</refcode>
<total>1.0</total>
<merchantordernumber>06002c1fd9d98a8101eb70484a033ae2</merchantordernumber>
<last4digits>6781</last4digits>
<avsresult>N</avsresult>
<cvv2result>U</cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def failed_authorize_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Declined</status>
<accountname>Longbob Longsen</accountname>
<result>DECLINED:1102140001:Invalid account number:</result>
<authcode></authcode>
<historyid>398049530</historyid>
<orderid>287811302</orderid>
<refcode>398049530</refcode>
<total>1.0</total>
<merchantordernumber>5dcbd6b4af0ef5b3391aebe2489b83ae</merchantordernumber>
<last4digits>6782</last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def successful_capture_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Approved</status>
<accountname>Longbob Longsen</accountname>
<result>AVSPOST:TEST:::398044113:::</result>
<authcode>TEST</authcode>
<historyid>398044113</historyid>
<orderid>287810629</orderid>
<refcode>398044113</refcode>
<total>1.0</total>
<merchantordernumber>bcb384e495bcc61b7ecddc74511916b7</merchantordernumber>
<last4digits>6781</last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def failed_capture_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Declined</status>
<accountname></accountname>
<result>DECLINED:1102010009:Missing account number:</result>
<authcode></authcode>
<historyid>0</historyid>
<orderid>0</orderid>
<refcode>0</refcode>
<total>0.00</total>
<merchantordernumber></merchantordernumber>
<last4digits></last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype></paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def successful_void_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Approved</status>
<accountname>Longbob Longsen</accountname>
<result>VOID:TEST:::398050218:::</result>
<authcode>TEST</authcode>
<historyid>398050218</historyid>
<orderid>287820429</orderid>
<refcode>398050218</refcode>
<total>1.0</total>
<merchantordernumber>f170b6e6773fc1e9e840a4561c0562cd</merchantordernumber>
<last4digits>6781</last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def failed_void_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Declined</status>
<accountname></accountname>
<result>DECLINED:3101810001:Invalid acct type:</result>
<authcode></authcode>
<historyid>0</historyid>
<orderid>0</orderid>
<refcode>0</refcode>
<total>0.00</total>
<merchantordernumber></merchantordernumber>
<last4digits></last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype></paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def successful_refund_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Approved</status>
<accountname>Longbob Longsen</accountname>
<result>CREDIT:TEST:::398045843:::</result>
<authcode>TEST</authcode>
<historyid>398045843</historyid>
<orderid>287822169</orderid>
<refcode>398045843</refcode>
<total>1.0</total>
<merchantordernumber>20eda293fcab33cd69fc22d662c08a1a</merchantordernumber>
<last4digits>6781</last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def failed_refund_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Declined</status>
<accountname></accountname>
<result>DECLINED:1101700009:Missing account number:</result>
<authcode></authcode>
<historyid>0</historyid>
<orderid>0</orderid>
<refcode>0</refcode>
<total>0.00</total>
<merchantordernumber></merchantordernumber>
<last4digits></last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype></paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def successful_credit_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Approved</status>
<accountname>Default Name</accountname>
<result>CREDIT:TEST:::398041091:::</result>
<authcode>TEST</authcode>
<historyid>398041091</historyid>
<orderid>287816362</orderid>
<refcode>398041091</refcode>
<total>1.0</total>
<merchantordernumber>8e36e7e5dedd21e3c5a2dc76b886b2e1</merchantordernumber>
<last4digits>6781</last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def failed_credit_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Declined</status>
<accountname>Default Name</accountname>
<result>DECLINED:1102140001:Invalid account number:</result>
<authcode></authcode>
<historyid>398056981</historyid>
<orderid>287823604</orderid>
<refcode>398056981</refcode>
<total>1.0</total>
<merchantordernumber>18a6d240b6df82cf1fa4638088321473</merchantordernumber>
<last4digits>6782</last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype>Visa</paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end


  def successful_store_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Approved</status>
<accountname></accountname>
<result>PROFILEADD:Success:::0:::</result>
<authcode></authcode>
<historyid>0</historyid>
<orderid>0</orderid>
<userprofileid>17522090</userprofileid>
<refcode>0</refcode>
<total>0.00</total>
<merchantordernumber></merchantordernumber>
<last4digits>6781</last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype></paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def failed_store_response
    %(<?xml version="1.0"?><interface_driver>
<trans_catalog>
<transaction>
<outputs>
<status>Declined</status>
<accountname></accountname>
<result>DECLINED:1000390009:Live Transactions Not Allowed:</result>
<authcode></authcode>
<historyid>0</historyid>
<orderid>0</orderid>
<refcode>0</refcode>
<total>0.00</total>
<merchantordernumber></merchantordernumber>
<last4digits></last4digits>
<avsresult></avsresult>
<cvv2result></cvv2result>
<duplicate>0</duplicate>
<paytype></paytype>
</outputs>
</transaction>
</trans_catalog>
</interface_driver>
    )
  end

  def transcript
    %(<?xml version="1.0" encoding="UTF-8"?>
      <interface_driver>
        <trans_catalog>
          <transaction name="creditcard">
            <inputs>
              <amount>1.00</amount>
              <merchantordernumber>41f093119352aae74d30478695ace163</merchantordernumber>
              <currency>USD</currency>
              <ccname>Longbob Longsen</ccname>
              <ccnum>4003000123456781</ccnum>
              <cvv2>123</cvv2>
              <expmon>09</expmon>
              <expyear>2016</expyear>
              <billaddr1>456 My Street</billaddr1>
              <billaddr2>Apt 1</billaddr2>
              <billcity>Ottawa</billcity>
              <billstate>ON</billstate>
              <billcountry>CA</billcountry>
              <bilzip>K1C2N6</bilzip>
              <phone>(555)555-5555</phone>
              <acctid>TEST0</acctid>
              <merchantpin>1234567890</merchantpin>
              <service>2</service>
            </inputs>
          </transaction>
        </trans_catalog>
      </interface_driver>

      <?xml version="1.0"?><interface_driver>
      <trans_catalog>
      <transaction>
      <outputs>
      <status>Approved</status>
      <accountname>Longbob Longsen</accountname>
      <result>AVSSALE:TEST:::398009684:N::U</result>
      <authcode>TEST</authcode>
      <historyid>398009684</historyid>
      <orderid>287780716</orderid>
      <refcode>398009684</refcode>
      <total>1.0</total>
      <merchantordernumber>41f093119352aae74d30478695ace163</merchantordernumber>
      <last4digits>6781</last4digits>
      <avsresult>N</avsresult>
      <cvv2result>U</cvv2result>
      <duplicate>0</duplicate>
      <paytype>Visa</paytype>
      </outputs>
      </transaction>
      </trans_catalog>
      </interface_driver>
    )
  end

  def scrubbed_transcript
    %(<?xml version="1.0" encoding="UTF-8"?>
      <interface_driver>
        <trans_catalog>
          <transaction name="creditcard">
            <inputs>
              <amount>1.00</amount>
              <merchantordernumber>41f093119352aae74d30478695ace163</merchantordernumber>
              <currency>USD</currency>
              <ccname>Longbob Longsen</ccname>
              <ccnum>[FILTERED]</ccnum>
              <cvv2>[FILTERED]</cvv2>
              <expmon>09</expmon>
              <expyear>2016</expyear>
              <billaddr1>456 My Street</billaddr1>
              <billaddr2>Apt 1</billaddr2>
              <billcity>Ottawa</billcity>
              <billstate>ON</billstate>
              <billcountry>CA</billcountry>
              <bilzip>K1C2N6</bilzip>
              <phone>(555)555-5555</phone>
              <acctid>TEST0</acctid>
              <merchantpin>[FILTERED]</merchantpin>
              <service>2</service>
            </inputs>
          </transaction>
        </trans_catalog>
      </interface_driver>

      <?xml version="1.0"?><interface_driver>
      <trans_catalog>
      <transaction>
      <outputs>
      <status>Approved</status>
      <accountname>Longbob Longsen</accountname>
      <result>AVSSALE:TEST:::398009684:N::U</result>
      <authcode>TEST</authcode>
      <historyid>398009684</historyid>
      <orderid>287780716</orderid>
      <refcode>398009684</refcode>
      <total>1.0</total>
      <merchantordernumber>41f093119352aae74d30478695ace163</merchantordernumber>
      <last4digits>6781</last4digits>
      <avsresult>N</avsresult>
      <cvv2result>U</cvv2result>
      <duplicate>0</duplicate>
      <paytype>Visa</paytype>
      </outputs>
      </transaction>
      </trans_catalog>
      </interface_driver>
    )
  end
end
