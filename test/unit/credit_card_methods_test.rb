require File.dirname(__FILE__) + '/../test_helper'

class CreditCardMethodsTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::CreditCardMethods
  
  def test_valid_expiry_months
    assert !valid_month?(-1)
    1.upto(12){ |m| assert valid_month?(m) }
    assert !valid_month?(13)
  end

  def test_valid_expiry_year
    0.upto(20){ |n| assert valid_expiry_year?(Time.now.year + n) }
  end

  def test_invalid_expiry_year
    assert !valid_expiry_year?(-1)
    assert !valid_expiry_year?(Time.now.year + 21)
  end
  
  def test_valid_start_year
    assert !valid_start_year?(1987)
    assert valid_start_year?(1988)
    assert valid_start_year?(2007)
    assert valid_start_year?(3000)
  end
  
  def test_valid_issue_number
    assert valid_issue_number?(1)
    assert !valid_issue_number?(-1)
    assert valid_issue_number?(10)
    assert valid_issue_number?('12')
    assert valid_issue_number?(0)
    assert !valid_issue_number?(123)
    assert !valid_issue_number?('CAT')
  end
end
