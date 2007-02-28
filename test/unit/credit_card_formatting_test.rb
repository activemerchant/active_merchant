require File.dirname(__FILE__) + '/../test_helper'

class CreditCardFormattingTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::CreditCardFormatting
  
  def test_format_expiry_year
    year = 2005
    
    assert_equal '05', format(year, :two_digits)
    assert_equal '2005', format(year, :four_digits)
    assert_equal '05', format(05, :two_digits)
    assert_equal '0005', format(05, :four_digits)
  end

  def test_format_expiry_month
    month = 8
    assert_equal '08', format(month, :two_digits)
  end
  
  def test_format_empty_numbers
    assert_equal '', format(nil, :two_digits)
    assert_equal '', format('', :two_digits)
  end
end
