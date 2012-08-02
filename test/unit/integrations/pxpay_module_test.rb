require 'test_helper'

class PxpayModuleTest < Test::Unit::TestCase
  include CommStub
  include ActionViewHelperTestHelper
  include ActiveMerchant::Billing::Integrations

  def setup
    super
    @options = fixtures(:pxpay)
    @username = @options[:login]
    @key = @options[:password]
  end

  def test_notification_method
    Pxpay::Notification.any_instance.stubs(:decrypt_transaction_result)

    assert_instance_of Pxpay::Notification, Pxpay.notification('name=cody&result=token', :credential1 => '', :credential2 => '')
  end

  def test_should_round_numbers
    Pxpay::Helper.any_instance.stubs(:form_fields).returns({})

    request = ""
    payment_service_for('44',@username, :service => :pxpay,  :amount => "157.003"){ |service| request = service.send :generate_request}
    assert request !~ /AmountInput>157.003</

    payment_service_for('44',@username, :service => :pxpay,  :amount => "157.005"){ |service| request = service.send :generate_request}
    assert request =~ /AmountInput>157.01</
  end

  def test_amount_has_cent_precision
    Pxpay::Helper.any_instance.stubs(:form_fields).returns({})

    request = ""
    payment_service_for('44',@username, :service => :pxpay,  :amount => "157"){ |service| request = service.send :generate_request}
    assert request =~ /AmountInput>157.00</
  end

  def test_all_fields
    Pxpay::Helper.any_instance.stubs(:form_fields).returns({})

    request = ""
    payment_service_for('44',@username, :service => :pxpay,  :amount => 157.0){|service|

      service.customer_id 8
      service.customer :first_name => 'g',
                       :last_name => 'g',
                       :email => 'g@g.com',
                       :phone => '3'

      service.return_url "http://example.com/pxpay/return_url"

      service.credential2 @key

      request = service.send :generate_request
    }

    assert_match /<TxnId>44</, request
    assert_match /<PxPayUserId>#{@username}</, request
    assert_match /<PxPayKey>#{@key}</, request
    assert_match /<TxnType>Purchase</, request
    assert_match /<AmountInput>157.00</, request
    assert_match /<EnableAddBillCard>0</, request
    assert_match /<EmailAddress>g@g.com</, request
    assert_match /<UrlSuccess>http:\/\/example.com\/pxpay\/return_url</, request
    assert_match /<UrlFail>http:\/\/example.com\/pxpay\/return_url</, request
  end

  def test_xml_escaping_fields
    Pxpay::Helper.any_instance.stubs(:form_fields).returns({})

    request = ""

    payment_service_for('44',@username, :service => :pxpay, :amount => 157.0){|service|

      service.customer_id 8
      service.customer :first_name => 'g<',
                       :last_name => 'g&',
                       :email => '<g g> g@g.com',
                       :phone => '3'

      service.billing_address :zip => 'g',
                       :country => 'United States of <',
                       :address1 => 'g'

      service.ship_to_address :first_name => 'g>',
                              :last_name => 'g>',
                              :city => '><&',
                              :address1 => 'g&',
                              :address2 => '>',
                              :state => '>ut',
                              :country => '>United States of America',
                              :zip => '>g'

      service.credential2 @key

      service.return_url "http://t/pxpay/return_url?&"
      service.cancel_return_url "http://t/pxpay/cancel_url?&"
      request = service.generate_request
    }

    assert_nothing_raised do
      doc = Nokogiri::XML(request) { |config| config.options = Nokogiri::XML::ParseOptions::STRICT }
    end
  end

  def test_created_form_is_valid
    Pxpay::Helper.any_instance.stubs(:ssl_post).returns('<Request valid="1"><URI>https://sec.paymentexpress.com/pxpay/pxpay.aspx?userid=PXPAY_USER&amp;request=REQUEST_TOKEN</URI></Request>')

    payment_service_for('44',@username, :service => :pxpay, :amount => 157.0){|service|
       service.credential2 @key
       service.return_url "http://store.shopify.com/done"
       service.cancel_return_url "http://store.shopify.com/cancel"
    }

    assert_match /method=\"GET\"/i, @output_buffer
  end
end
