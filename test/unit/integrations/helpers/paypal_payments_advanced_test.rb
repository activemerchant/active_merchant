require 'test_helper'

class PaypalPaymentsAdvancedHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    if RUBY_VERSION < '1.9' && $KCODE == "NONE"
      @original_kcode = $KCODE
      $KCODE = 'u'
    end

    @helper = PaypalPaymentsAdvanced::Helper.new(1121, 'myaccount', :amount => 500, 
                                      :currency => 'CAD', :credential2 => "password", 
                                      :test => true)
    @url = 'http://example.com'
  end

  def teardown
    $KCODE = @original_kcode if @original_kcode
  end

  def test_basic_helper_fields

    @helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)

      assert_equal 'myaccount', params["login[9]"]
      assert_equal 'myaccount', params["user[9]"]
      assert_equal 'PayPal', params["partner[6]"]
      assert_equal '500', params["amt[3]"]
      assert_equal 'S', params["trxtype[1]"]
      assert_equal '1121', params["user1[4]"]
      assert_equal '1121', params["invoice[4]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    @helper.form_fields
  end

  def test_description
    @helper.description "my order"
    @helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)

      assert_equal 'my order', params["description[8]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    @helper.form_fields
  end

  def test_name
    @helper.customer :first_name => "John", :last_name => "Doe"

    @helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)

      assert_equal 'John', params["first_name[4]"]
      assert_equal 'Doe', params["last_name[3]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    @helper.form_fields
  end

  def test_billing_information
    @helper.billing_address :country => 'CA',
                             :address1 => '1 My Street',
                             :address2 => 'APT. 2',
                             :city => 'Ottawa',
                             :state => 'On',
                             :zip => '90210',
                             :phone => '(555)123-4567'

    @helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)

      assert_equal '1 My Street APT. 2', params["address[18]"]
      assert_equal 'Ottawa', params["city[6]"]
      assert_equal 'ON', params["state[2]"]
      assert_equal '90210', params["zip[5]"]
      assert_equal 'CA', params["country[2]"]
      assert_equal '(555)123-4567', params["phone[13]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    @helper.form_fields
  end

  def test_state
    @helper.billing_address :country => 'US',
                             :state => 'TX'
    @helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)

      assert_equal "US", params["country[2]"]
      assert_equal "TX", params["state[2]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    @helper.form_fields
  end

  def test_country_code
    @helper.billing_address :country => 'CAN'
    @helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)

      assert_equal "CA", params["country[2]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    @helper.form_fields
  end

  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    fields["state"] = 'N/A'
    
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end
  
  def test_uk_shipping_address_with_no_state
    @helper.billing_address :country => 'GB',
                             :state => ''

    @helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)

      assert_equal "N/A", params["state[3]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    @helper.form_fields
  end

  def test_form_fields_when_using_secure_token
    @helper.expects(:ssl_post => "RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    fields = @helper.form_fields

    assert_equal "aaa", fields["securetoken"]
    assert_equal "test", fields["mode"]
    assert_equal "yyy", fields["securetokenid"]
  end

  def test_form_fields_when_secure_token_failed
    @helper.expects(:ssl_post => "RESPMSG=FAILED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    fields = @helper.form_fields

    assert_equal "test", fields["mode"]
    assert_nil fields["securetoken"]
    assert_nil fields["securetokenid"]
  end

  def test_submits_correct_fields_to_generate_secure_token
    @helper.expects(:secure_token_id => "aaaa")
    @helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)

      assert_equal "password", params["pwd[8]"]
      assert_equal "S", params["trxtype[1]"]
      assert_equal "myaccount", params["user[9]"]
      assert_equal "myaccount", params["vendor[9]"]
      assert_equal "aaaa", params["securetokenid[4]"]
      assert_equal "Y", params["createsecuretoken[1]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")

    @helper.form_fields
  end

  def test_transaction_type
    helper = PayflowLink::Helper.new(1121, 'myaccount', :amount => 500,
                                      :currency => 'CAD', :credential2 => "password",
                                      :test => true, :transaction_type => 'A')
    helper.expects(:ssl_post).with { |url, data|
      params = parse_params(data)
      assert_equal 'A', params["trxtype[1]"]
      true
    }.returns("RESPMSG=APPROVED&SECURETOKEN=aaa&SECURETOKENID=yyy")
    helper.form_fields
  end

  private
  def parse_params(response)
    response.split("&").inject({}) do |hash, param|
      key, value = param.split("=")
      hash[key] = value
      hash
    end
  end
end
