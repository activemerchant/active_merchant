require 'test_helper'

class PxpayModuleTest < Test::Unit::TestCase
  include CommStub
  include ActionViewHelperTestHelper
  include ActiveMerchant::Billing::Integrations

  def setup
    super
    @username = "ShopifyHPP_Dev"
    @key = "b1853e58edccc1cc13bb24b9bede3acd41cdeaa8942ad330b27ab04d209003c0"
  end

  def test_notification_method
    assert_instance_of Pxpay::Notification, Pxpay.notification('name=cody')
  end

  def test_should_round_numbers
    Pxpay::Helper.any_instance.stubs(:request_secure_token)

    request = ""
    payment_service_for('44',@username, :service => :pxpay,  :amount => "157.003"){ |service| request = service.generate_request}
    assert request !~ /AmountInput>157.003</

    payment_service_for('44',@username, :service => :pxpay,  :amount => "157.005"){ |service| request = service.generate_request}
    assert request =~ /AmountInput>157.01</
  end

  def test_amount_has_cent_precision
    Pxpay::Helper.any_instance.stubs(:request_secure_token)

    request = ""
    payment_service_for('44',@username, :service => :pxpay,  :amount => "157"){ |service| request = service.generate_request}
    assert request =~ /AmountInput>157.00</
  end

  def test_all_fields
    Pxpay::Helper.any_instance.stubs(:request_secure_token)

    request = ""
      payment_service_for('44',@username, :service => :pxpay,  :amount => 157.0){|service|

        service.customer_id 8
        service.customer :first_name => 'g',
                         :last_name => 'g',
                         :email => 'g@g.com',
                         :phone => '3'

        service.billing_address :zip => 'g',
                         :country => 'United States of America',
                         :address1 => 'g'

        service.ship_to_address :first_name => 'g',
                                :last_name => 'g',
                                :city => '',
                                :address1 => 'g',
                                :address2 => '',
                                :state => 'ut',
                                :country => 'United States of America',
                                :zip => 'g'

        service.return_url "http://t/pxpay/return_url"
        service.cancel_return_url "http://t/pxpay/cancel_url"

        request = service.generate_request
      }

    # <GenerateRequest><TxnId>44</TxnId><PxPayUserId>PxPayUser</PxPayUserId><TxnType>Purchase</TxnType><AmountInput>157.0</AmountInput>
    # <EnableAddBillCard>0</EnableAddBillCard><EmailAddress>g@g.com</EmailAddress><TxnData1>g</TxnData1>
    # <TxnData3>United States of America</TxnData3><UrlSuccess>http://t/pxpay/return_url</UrlSuccess>
    # <UrlFail>http://t/pxpay/cancel_url</UrlFail></GenerateRequest>
  end

  def test_xml_escaping_all_fields
    Pxpay::Helper.any_instance.stubs(:request_secure_token)

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

      service.credential2 = @key

      service.return_url "http://t/pxpay/return_url?&"
      service.cancel_return_url "http://t/pxpay/cancel_url?&"
      request = service.generate_request
    }

    assert_nothing_raised do
      doc = Nokogiri::XML(request) { |config| config.options = Nokogiri::XML::ParseOptions::STRICT }
    end

    # <GenerateRequest><TxnId>44</TxnId><PxPayUserId>PxPayUser</PxPayUserId><TxnType>Purchase</TxnType><AmountInput>157.0</AmountInput>
    # <EnableAddBillCard>0</EnableAddBillCard><EmailAddress>g@g.com</EmailAddress><TxnData1>g</TxnData1>
    # <TxnData3>United States of America</TxnData3><UrlSuccess>http://t/pxpay/return_url</UrlSuccess>
    # <UrlFail>http://t/pxpay/cancel_url</UrlFail></GenerateRequest>
  end

  def test_payment_key_required()
  end

  def test_currency_required()
  end

  def test_urlsuccess_required()
  end

  def test_urlfailure_required()
  end

  def test_ 
  end

  def check_inclusion(these_lines)
    for line in these_lines do
      assert @output_buffer.include?(line), ['unable to find ', line, ' ', 'in \n', @output_buffer].join(' ')
    end
  end

  def test_normal_fields
    Pxpay::Helper.any_instance.stubs(:request_secure_token)

    payment_service_for('44','8wd65QS', :service => :pxpay,  :amount => 157.0){|service|

      service.setup_hash :transaction_key => '8CP6zJ7uD875J6tY',
          :order_timestamp => 1206836763
      service.customer_id 8
      service.customer :first_name => 'Cody',
                         :last_name => 'Fauser',
                         :phone => '(555)555-5555',
                         :email => 'g@g.com'

      service.billing_address :city => 'city1',
                                :address1 => 'g',
                                :address2 => '',
                                :state => 'UT',
                                :country => 'United States of America',
                                :zip => '90210'
       service.invoice '#1000'
       service.shipping '30.00'
       service.tax '31.00'
       service.test_request 'true'

    }
  end

 

end
