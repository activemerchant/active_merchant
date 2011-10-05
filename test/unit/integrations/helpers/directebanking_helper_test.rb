require 'test_helper'

class DirectebankingHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Directebanking::Helper.new('order-500','UserID-24352435', :credential2 => "ProjectID-1234",
            :amount => 500, :currency => 'EUR', :credential3 => "mysecretString")
    @helper.return_url "https://localhost:8080/directebanking"
  end

  def test_urls
    @helper.cancel_return_url "https://localhost:8080/directebanking/cancel"
    @helper.notify_url "https://localhost:8080/directebanking/notify"
    
    assert_field 'user_variable_1', "https://localhost:8080/directebanking"
    assert_field 'user_variable_2', "https://localhost:8080/directebanking/cancel"
    assert_field 'user_variable_3', "https://localhost:8080/directebanking/notify"
  end
  
  def test_basic_helper_fields
    @helper.description "My order #1234"
    assert_field 'user_id', 'UserID-24352435'
    assert_field 'project_id', 'ProjectID-1234'
    assert_field 'amount', '5.00'
    assert_field 'user_variable_0', 'order-500'
    assert_field 'reason_1', 'My order #1234'
  end
  
  def test_generate_signature_string
    assert_equal "UserID-24352435|ProjectID-1234|||||5.00|EUR|||order-500|https://localhost:8080/directebanking|||||mysecretString", 
    @helper.generate_signature_string
  end

  def test_generate_signature
    assert !@helper.form_fields['hash'].empty?
    assert_equal 'c34113bc04eb28a045fe5c2b1e9e186fe3cde03b', @helper.generate_signature
    assert_equal "c34113bc04eb28a045fe5c2b1e9e186fe3cde03b", @helper.form_fields['hash']
  end
  
  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '501 Dwemthy Fox Road'
    end
  end
  
  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end  
end
