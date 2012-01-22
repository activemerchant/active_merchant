require 'test_helper'

class ValitorHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Valitor::Helper.new(
      'order-500',
      'cody@example.com',
      :currency => 'USD',
      :credential2 => '123',
      :amount => 1000
      )
  end
 
  def test_basic_helper_fields
    assert_field 'VefverslunID', 'cody@example.com'

    assert_field 'Adeinsheimild', '0'
    assert_field 'Tilvisunarnumer', 'order-500'
    assert_field 'Gjaldmidill', 'USD'
    
    assert_equal Digest::MD5.hexdigest(['123', '0', '1', '1000', '0', 'cody@example.com', 'order-500', 'USD'].join('')),
                 @helper.form_fields['RafraenUndirskrift']
  end
  
  def test_products
    @helper.product(1, :description => 'one', :quantity => '2', :amount => 100, :discount => 50)
    @helper.product(2, :description => 'two', :amount => 200)
    
    assert_field 'Vara_1_Lysing', 'one'
    assert_field 'Vara_1_Fjoldi', '2'
    assert_field 'Vara_1_Verd', '100'
    assert_field 'Vara_1_Afslattur', '50'
    
    assert_field 'Vara_2_Lysing', 'two'
    assert_field 'Vara_2_Fjoldi', '1'
    assert_field 'Vara_2_Verd', '200'
    assert_field 'Vara_2_Afslattur', '0'

    assert_equal Digest::MD5.hexdigest(
      ['123', '0',
        '2', '100', '50',
        '1', '200', '0',
        'cody@example.com', 'order-500', 'USD'].join('')),
      @helper.form_fields['RafraenUndirskrift']
  end
  
  def test_invalid_products
    assert_nothing_raised do
      @helper.product(1, :description => '1', :amount => 100)
    end

    assert_nothing_raised ArgumentError do
      @helper.product('2', :description => '2', :amount => 100)
    end
    
    assert_raise ArgumentError do
      @helper.product(501, :description => '501', :amount => 100)
    end
    
    assert_raise ArgumentError do
      @helper.product(0, :description => '0', :amount => 100)
    end
    
    assert_raise ArgumentError do
      @helper.product(3, :amount => 100)
    end
    
    assert_raise ArgumentError do
      @helper.product(3, :description => 100)
    end
    
    assert_raise ArgumentError do
      @helper.product(3, :amount => 100, :bogus => 'something')
    end
  end
  
  def test_authorize_only
    @helper.authorize_only
    assert_field 'Adeinsheimild', '1'
  end
  
  def test_missing_password
    @helper.instance_eval{@security_number = nil}
    assert_raise ArgumentError do
      @helper.form_fields
    end
  end
  
  def test_urls
    @helper.return_url = 'http://example.com/return'
    assert_field 'SlodTokstAdGjaldfaera', 'http://example.com/return'

    @helper.cancel_return_url = 'http://example.com/cancel'
    assert_field 'SlodNotandiHaettirVid', 'http://example.com/cancel'

    @helper.notify_url = 'http://example.com/notify'
    assert_field 'SlodTokstAdGjaldfaeraServerSide', 'http://example.com/notify'

    assert_equal Digest::MD5.hexdigest(
      ['123', '0',
         '1', '1000', '0',
        'cody@example.com', 'order-500', 'http://example.com/return', 'http://example.com/notify', 'USD'].join('')),
      @helper.form_fields['RafraenUndirskrift']
  end
  
  def test_collect_customer_info
    assert_field 'KaupandaUpplysingar', '0'
    @helper.collect_customer_info
    assert_field 'KaupandaUpplysingar', '1'
  end

  def test_hide_header
    assert_field 'SlokkvaHaus', '0'
    @helper.hide_header
    assert_field 'SlokkvaHaus', '1'
  end
  
  def test_misc_mappings
    assert_field 'SlodTokstAdGjaldfaeraTexti', nil 
    @helper.success_text = 'text'
    assert_field 'SlodTokstAdGjaldfaeraTexti', 'text'
    
    assert_field 'Lang', nil
    @helper.language = 'en'
    assert_field 'Lang', 'en'
  end
  
  def test_amount_gets_sent_without_decimals
    @helper = Valitor::Helper.new('order-500', 'cody@example.com', :currency => 'ISK', :credential2 => '123', :amount => 115.10)
    @helper.form_fields
    assert_field "Vara_1_Verd", '115'
  end
end
