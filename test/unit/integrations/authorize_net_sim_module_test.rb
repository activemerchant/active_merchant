require 'test_helper'

class AuthorizeNetSimModuleTest < Test::Unit::TestCase
  include ActionViewHelperTestHelper
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of AuthorizeNetSim::Notification, AuthorizeNetSim.notification('name=cody')
  end

  def test_address2
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
	    service.billing_address :address1 => 'address1', :address2 => 'line 2'
    }
    all= ['<input id="x_address" name="x_address" type="hidden" value="address1 line 2" />']
    check_inclusion all
  end

  def test_lots_of_line_items_same_name
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
      35.times {service.add_line_item :name => 'beauty2 - ayoyo', :quantity => 1, :unit_price => 0}
    }
    assert @output_buffer =~ / more unshown items after this one/
    # It should display them all in, despite each having the same name.
    assert @output_buffer.scan(/beauty2 - ayoyo/).length > 5
  end

  def test_lots_of_line_items_different_names
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
      35.times {|n| service.add_line_item :name => 'beauty2 - ayoyo' + n.to_s, :quantity => 1, :unit_price => 0}
    }
    assert @output_buffer =~ / ayoyo3/
    assert @output_buffer =~ / ayoyo4/
  end

  def test_should_round_numbers
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => "157.003"){}
    assert @output_buffer !~ /x_amount.*157.003"/
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => "157.005"){}
    assert @output_buffer =~ /x_amount.*157.01"/
  end

  def test_all_fields
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|

       service.setup_hash :transaction_key => '8CP6zJ7uD875J6tY',
           :order_timestamp => 1206836763
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

      service.invoice "516428355"
      service.notify_url "http://t/authorize_net_sim/payment_received_notification_sub_step"
      service.payment_header 'MyFavoritePal'
      service.add_line_item :name => 'beauty2 - ayoyo', :quantity => 1, :unit_price => 0.0
      service.test_request 'true'
      service.shipping '25.0'
      service.add_shipping_as_line_item
    }

    all = '<INPUT TYPE=HIDDEN name="x_cust_id" value="8">
      <INPUT TYPE=HIDDEN name="x_ship_to_last_name" value="g">
      <INPUT TYPE=HIDDEN name="x_fp_timestamp" value="1206836763">
      <INPUT TYPE=HIDDEN name="x_ship_to_first_name" value="g">
      <INPUT TYPE=HIDDEN name="x_last_name" value="g">
      <INPUT TYPE=HIDDEN name="x_amount" value="157.0">
      <INPUT TYPE=HIDDEN name="x_ship_to_country" value="United States of America">
      <INPUT TYPE=HIDDEN name="x_ship_to_zip" value="g">
      <INPUT TYPE=HIDDEN name="x_zip" value="g">
      <INPUT TYPE=HIDDEN name="x_country" value="United States of America">
      <INPUT TYPE=HIDDEN name="x_duplicate_window" value="28800">
      <INPUT TYPE=HIDDEN name="x_relay_response" value="TRUE">
      <INPUT TYPE=HIDDEN name="x_ship_to_address" value="g">
      <INPUT TYPE=HIDDEN name="x_first_name" value="g">
      <INPUT TYPE=HIDDEN name="x_version" value="3.1">
      <INPUT TYPE=HIDDEN name="x_invoice_num" value="516428355">
      <INPUT TYPE=HIDDEN name="x_address" value="g">
      <INPUT TYPE=HIDDEN name="x_login" value="8wd65QS">
      <INPUT TYPE=HIDDEN name="x_phone" value="3">
      <INPUT TYPE=HIDDEN name="x_relay_url" value="http://t/authorize_net_sim/payment_received_notification_sub_step">
      <INPUT TYPE=HIDDEN name="x_fp_sequence" value="44">
      <INPUT TYPE=HIDDEN name="x_show_form" value="PAYMENT_FORM">
      <INPUT TYPE=HIDDEN name="x_header_html_payment_form" value="MyFavoritePal">
      <INPUT TYPE=HIDDEN name="x_email" value="g@g.com">
      <INPUT TYPE=HIDDEN name="x_fp_hash" value="31d572da4e9910b36e999d73925eb01c">
      <INPUT TYPE=HIDDEN name="x_line_item" value="Item 1<|>beauty2 - ayoyo<|>beauty2 - ayoyo<|>1<|>0.0<|>N">
      <INPUT TYPE=HIDDEN name="x_test_request" value="true">
      <INPUT TYPE=HIDDEN name="x_freight" value="25.0"/>
      <INPUT TYPE=HIDDEN name="x_line_item" value="Shipping<|>Shipping and Handling Cost<|>Shipping and Handling Cost<|>1<|>25.0<|>N">'

    # clean it up a bit for parsing
    @output_buffer.gsub!("type=\"hidden\" ", "")
    for line in all.split("\n") do
      line.strip!
      if line =~ /(name=".*".*value=".*")/i
        line = $1
        assert @output_buffer.include?(line), 'didnt find' + line + 'in ' + @output_buffer
      end
    end
  end

  def check_inclusion(these_lines)
    for line in these_lines do
      assert @output_buffer.include?(line), ['unable to find ', line, ' ', 'in \n', @output_buffer].join(' ')
    end
  end

  def test_custom
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
      service.add_custom_field 'abc', 'def'
    }
    all = ["<input id=\"abc\" name=\"abc\" type=\"hidden\" value=\"def\" />"]
    check_inclusion all
  end


  def test_shipping_and_tax_line_item
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
      service.shipping 44.0
      service.tax 44.0
      service.add_shipping_as_line_item
      service.add_tax_as_line_item
    }
    all = ['<input id="x_line_item" name="x_line_item" type="hidden" value="Tax<|>Total Tax<|>Total Tax<|>1<|>44.0<|>N',
    'input id="x_line_item" name="x_line_item" type="hidden" value="Shipping<|>Shipping and Handling Cost<|>Shipping and Handling Cost<|>1<|>44.0<|>N" />'
    ]
    check_inclusion all
  end

  def test_shipping_large
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|

    service.ship_to_address :first_name => 'first', :last_name => 'last', :company => 'company1',
      :city => 'city2', :state => 'TX', :zip => 84601, :country => 'US'
    }
     expected = "<input id=\"x_ship_to_city\" name=\"x_ship_to_city\" type=\"hidden\" value=\"city2\" />\n<input id=\"x_ship_to_last_name\" name=\"x_ship_to_last_name\" type=\"hidden\" value=\"last\" />\n<input id=\"x_ship_to_first_name\" name=\"x_ship_to_first_name\" type=\"hidden\" value=\"first\" />
     <input id=\"x_ship_to_country\" name=\"x_ship_to_country\" type=\"hidden\" value=\"US\" />\n<input id=\"x_ship_to_zip\" name=\"x_ship_to_zip\" type=\"hidden\" value=\"84601\" />\n<input id=\"x_ship_to_company\" name=\"x_ship_to_company\" type=\"hidden\" value=\"company1\" />\n
     <input id=\"x_ship_to_state\" name=\"x_ship_to_state\" type=\"hidden\" value=\"TX\" />\n"
    for line in expected.split("\n") do
      assert @output_buffer.include?(line.strip), 'expected but not found' + line
    end
  end

  def test_line_item
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
      service.add_line_item :name => 'name1', :quantity => 1, :unit_price => 1, :tax => 'true'
      service.add_line_item :name => 'name2', :quantity => '2', :unit_price => '2'
      assert_raise(RuntimeError) do
        service.add_line_item :name => 'name3', :quantity => '3',  :unit_price => '-3'
      end
      service.tax 4
      service.shipping 5
      service.add_tax_as_line_item
      service.add_shipping_as_line_item
    }
    all = ["<input id=\"x_line_item\" name=\"x_line_item\" type=\"hidden\" value=\"Item 1<|>name1<|>name1<|>1<|>1.0<|>N\" />"]
    check_inclusion all
  end

  def test_line_item_weird_prices
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
      service.add_line_item :name => 'name1', :quantity => 1, :unit_price => "1.001", :tax => 'true'
      service.add_line_item :name => 'name2', :quantity => '2', :unit_price => '1.006'
    }
    # should round the prices
    assert @output_buffer !~ /1.001/
    assert @output_buffer =~ /1.01/
  end

  def test_ship_to
      payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
        service.tax 4
        service.ship_to_address :first_name => 'firsty'
      }
      assert @output_buffer.include? "<input id=\"x_ship_to_first_name\" name=\"x_ship_to_first_name\" type=\"hidden\" value=\"firsty\" />"
  end

  def test_normal_fields
    payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|

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

    expected = "<input id=\"x_cust_id\" name=\"x_cust_id\" type=\"hidden\" value=\"8\" />

    <input id=\"x_city\" name=\"x_city\" type=\"hidden\" value=\"city1\" />
      <input id=\"x_fp_timestamp\" name=\"x_fp_timestamp\" type=\"hidden\" value=\"1206836763\" />
    <input id=\"x_last_name\" name=\"x_last_name\" type=\"hidden\" value=\"Fauser\" />\n<input id=\"x_amount\" name=\"x_amount\" type=\"hidden\" value=\"157.0\" />
    <input id=\"x_country\" name=\"x_country\" type=\"hidden\" value=\"United States of America\" />\n<input id=\"x_zip\" name=\"x_zip\" type=\"hidden\" value=\"90210\" />\n<input id=\"x_duplicate_window\" name=\"x_duplicate_window\" type=\"hidden\" value=\"28800\" />
    \n<input id=\"x_relay_response\" name=\"x_relay_response\" type=\"hidden\" value=\"TRUE\" />\n<input id=\"x_first_name\" name=\"x_first_name\" type=\"hidden\" value=\"Cody\" />\n<input id=\"x_type\" name=\"x_type\" type=\"hidden\" value=\"AUTH_CAPTURE\" />\n<input id=\"x_version\" name=\"x_version\" type=\"hidden\" value=\"3.1\" />\n<input id=\"x_login\" name=\"x_login\" type=\"hidden\" value=\"8wd65QS\" />\n<input id=\"x_invoice_num\" name=\"x_invoice_num\" type=\"hidden\" value=\"#1000\" />\n<input id=\"x_phone\" name=\"x_phone\" type=\"hidden\" value=\"(555)555-5555\" />\n<input id=\"x_fp_sequence\" name=\"x_fp_sequence\" type=\"hidden\" value=\"44\" />\n<input id=\"x_show_form\" name=\"x_show_form\" type=\"hidden\" value=\"PAYMENT_FORM\" />
    <input id=\"x_state\" name=\"x_state\" type=\"hidden\" value=\"UT\" />\n<input id=\"x_email\" name=\"x_email\" type=\"hidden\" value=\"g@g.com\" />\n<input id=\"x_fp_hash\" name=\"x_fp_hash\" type=\"hidden\" value=\"31d572da4e9910b36e999d73925eb01c\" />
    <input id=\"x_tax\" name=\"x_tax\" type=\"hidden\" value=\"31.00\" />
    <input id=\"x_freight\" name=\"x_freight\" type=\"hidden\" value=\"30.00\" />".split("\n")

    for line in expected
      assert @output_buffer.include?(line.strip), 'missing field' + line + ' in' + "\n"
    end

  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://test.authorize.net/gateway/transact.dll', AuthorizeNetSim.service_url
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://secure.authorize.net/gateway/transact.dll', AuthorizeNetSim.service_url
  end

end
