require 'test_helper'
require 'remote/integrations/remote_integration_helper'
require 'nokogiri'

class RemoteValitorIntegrationTest < Test::Unit::TestCase
  include RemoteIntegrationHelper

  def setup
    @order = "order#{generate_unique_id}"
    @login = fixtures(:valitor)[:login]
    @password = fixtures(:valitor)[:password]
  end
  
  def test_full_purchase
    notification_request = listen_for_notification(80) do |notify_url|
      payment_page = submit %(
        <% payment_service_for('#{@order}', '#{@login}', :service => :valitor, :credential2 => #{@password}, :html => {:method => 'GET'}) do |service| %>
          <% service.product(1, :amount => 100, :description => 'PRODUCT1', :discount => '0') %>
          <% service.return_url = 'http://example.org/return' %>
          <% service.cancel_return_url = 'http://example.org/cancel' %>
          <% service.notify_url = '#{notify_url}' %>
          <% service.success_text = 'SuccessText!' %>
          <% service.language = 'en' %>
        <% end %>
      )
    
      assert_match(%r(http://example.org/cancel)i, payment_page.body)
      assert_match(%r(PRODUCT1), payment_page.body)
      
      form = payment_page.forms.first
      form['tbKortnumer'] = '4111111111111111'
      form['drpGildistimiManudur'] = '12'
      form['drpGildistimiAr'] = Time.now.year
      form['tbOryggisnumer'] = '000'
      result_page = form.submit(form.submits.first)
      
      assert continue_link = result_page.links.detect{|e| e.text =~ /successtext!/i}
      assert_match(%r(^http://example.org/return\?)i, continue_link.href)
      
      check_common_fields(return_from(continue_link.href))
    end
    
    check_common_fields(notification_from(notification_request))
  end
  
  def test_customer_fields
    payment_page = submit %(
      <% payment_service_for('#{@order}', '#{@login}', :service => :valitor, :credential2 => #{@password}, :html => {:method => 'GET'}) do |service| %>
        <% service.product(1, :amount => 100, :description => 'test', :discount => '0') %>
        <% service.return_url = 'http://example.org/return' %>
        <% service.cancel_return_url = 'http://example.org/cancel' %>
        <% service.success_text = 'SuccessText!' %>
        <% service.language = 'en' %>
        <% service.collect_customer_info %>
      <% end %>
    )
  
    form = payment_page.forms.first
    form['tbKortnumer'] = '4111111111111111'
    form['drpGildistimiManudur'] = '12'
    form['drpGildistimiAr'] = Time.now.year
    form['tbOryggisnumer'] = '000'
    form['tbKaupNafn'] = "NAME"
    form['tbKaupHeimilisfang'] = "123 ADDRESS"
    form['tbKaupPostnumer'] = "98765"
    form['tbKaupStadur'] = "CITY"
    form['tbKaupLand'] = "COUNTRY"
    form['tbKaupTolvupostfang'] = "EMAIL@EXAMPLE.COM"
    form['tbAthugasemdir'] = "COMMENTS"
    result_page = form.submit(form.submits.first)
    
    assert continue_link = result_page.links.detect{|e| e.text =~ /successtext!/i}
    assert_match(%r(^http://example.org/return\?)i, continue_link.href)
    
    ret = return_from(continue_link.href)
    check_common_fields(ret)
    assert_equal "NAME", ret.customer_name
    assert_equal "123 ADDRESS", ret.customer_address
    assert_equal "98765", ret.customer_zip
    assert_equal "CITY", ret.customer_city
    assert_equal "COUNTRY", ret.customer_country
    assert_equal "EMAIL@EXAMPLE.COM", ret.customer_email
    assert_equal "COMMENTS", ret.customer_comment
  end

  def test_products
    payment_page = submit %(
      <% payment_service_for('#{@order}', '#{@login}', :service => :valitor, :credential2 => #{@password}, :html => {:method => 'GET'}) do |service| %>
        <% service.product(1, :amount => 100, :description => 'PRODUCT1') %>
        <% service.product(2, :amount => 200, :description => 'PRODUCT2', :discount => '50') %>
        <% service.product(3, :amount => 300, :description => 'PRODUCT3', :quantity => '6') %>
        <% service.return_url = 'http://example.org/return' %>
        <% service.cancel_return_url = 'http://example.org/cancel' %>
        <% service.success_text = 'SuccessText!' %>
        <% service.language = 'en' %>
        <% service.collect_customer_info %>
      <% end %>
    )
    
    assert_match(%r(http://example.org/cancel)i, payment_page.body)

    doc = Nokogiri::HTML(payment_page.body)
    rows = doc.xpath("//table[@class='VoruTafla']//tr")
    assert_equal 5, rows.size
    check_product_row(rows[1], "PRODUCT1", "1", "100 ISK", "0 ISK",  "100 ISK")
    check_product_row(rows[2], "PRODUCT2", "1", "200 ISK", "50 ISK", "150 ISK")
    check_product_row(rows[3], "PRODUCT3", "6", "300 ISK", "0 ISK",  "1.800 ISK")
    assert_match /2.050 ISK/, rows[4].element_children.first.text
  end

  def test_default_product_if_none_provided
    payment_page = submit %(
      <% payment_service_for('#{@order}', '#{@login}', :service => :valitor, :credential2 => #{@password}, :html => {:method => 'GET'}) do |service| %>
        <% service.return_url = 'http://example.org/return' %>
        <% service.cancel_return_url = 'http://example.org/cancel' %>
        <% service.success_text = 'SuccessText!' %>
        <% service.language = 'en' %>
        <% service.collect_customer_info %>
      <% end %>
    )
    
    assert_match(%r(http://example.org/cancel)i, payment_page.body)

    doc = Nokogiri::HTML(payment_page.body)
    rows = doc.xpath("//table[@class='VoruTafla']//tr")
    assert_equal 5, rows.size
    check_product_row(rows[1], "PRODUCT1", "1", "100 ISK", "0 ISK",  "100 ISK")
    assert_match /2.050 ISK/, rows[4].element_children.first.text
  end
  
  def check_product_row(row, desc, quantity, amount, discount, total)
    assert_equal desc,     row.element_children[0].text.strip
    assert_equal quantity, row.element_children[1].text.strip
    assert_equal amount,   row.element_children[2].text.strip
    assert_equal discount, row.element_children[3].text.strip
    assert_equal total,    row.element_children[4].text.strip
  end
  
  def check_common_fields(response)
    assert response.success?
    assert_equal 'VISA', response.card_type
    assert_equal '9999', response.card_last_four # No idea why this comes back with 9's
    assert_equal @order, response.order
    assert response.received_at.length > 0
    assert response.authorization_number.length > 0
    assert response.transaction_number.length > 0
    assert response.transaction_id.length > 0
  end
  
  def return_from(uri)
    ActiveMerchant::Billing::Integrations::Valitor.return(uri.split('?').last, :credential2 => @password)
  end
  
  def notification_from(request)
    ActiveMerchant::Billing::Integrations::Valitor.notification(request.params["QUERY_STRING"], :credential2 => @password)
  end
end