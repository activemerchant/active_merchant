require 'test_helper'

class NumericCurrencyCodeTest < Test::Unit::TestCase
  
  def test_lookup_code
    assert_equal "840", ActiveMerchant::NumericCurrencyCode.lookup("USD")
  end
  
  def test_lookup_code_from_lower_case_currency
    assert_equal "840", ActiveMerchant::NumericCurrencyCode.lookup("usd")
  end
  
  def test_lookup_non_existant_code
    assert_nil ActiveMerchant::NumericCurrencyCode.lookup("ZZZ")
  end
  
  def test_lookup_with_nil
    assert_nil ActiveMerchant::NumericCurrencyCode.lookup(nil)
  end
  
  def test_lookup_with_empty_string
    assert_nil ActiveMerchant::NumericCurrencyCode.lookup("")
  end
  
end