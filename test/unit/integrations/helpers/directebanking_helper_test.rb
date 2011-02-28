require 'test_helper'

class DirectebankingHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Directebanking::Helper.new('order-500','UserID-24352435', :credential2 => "ProjectID-1234",
            :amount => 500, :currency => 'EUR', :credential3 => "mysecretString")
    @helper.user_variable_0 "localhost:8080/directebanking"
  end

  def test_basic_helper_fields
    assert_field 'user_id', 'UserID-24352435'
    assert_field 'project_id', 'ProjectID-1234'
    assert_field 'amount', '5.00'
    assert_field 'user_variable_0', 'localhost:8080/directebanking'
    assert_field 'user_variable_1', 'order-500'
  end
  
  def test_form_fields
    assert !@helper.form_fields['hash'].empty?
    assert_equal "083f2daf2fe10e827eb0d5205f97e6750cdf30bc", @helper.form_fields['hash']
  end
  
  def test_generate_signature_string
    assert_equal "UserID-24352435|ProjectID-1234|||||5.00|EUR|||localhost:8080/directebanking|order-500|||||mysecretString", 
    @helper.generate_signature_string
  end

  def test_generate_signature
    assert_equal '083f2daf2fe10e827eb0d5205f97e6750cdf30bc', @helper.generate_signature
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
