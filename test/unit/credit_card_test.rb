require File.dirname(__FILE__) + '/../test_helper'

class CreditCardTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  include ActiveMerchant::Billing::CreditCardMethods
  include ActiveMerchant::Billing::CreditCardFormatting

  def setup
    CreditCard.require_verification_value = false
    
    @visa = CreditCard.new(
      :type => "visa",
      :number => "4779139500118580",
      :month => Time.now.month,
      :year => Time.now.year + 1,
      :first_name => "Test",
      :last_name => "Mensch"
    )
    
    @solo = CreditCard.new(
      :type   => "solo",
      :number => "6334900000000005",
      :month  => Time.now.month,
      :year   => Time.now.year + 1,
      :first_name  => "Test",
      :last_name   => "Mensch",
      :issue_number => '01'
    )
  end
  
  def teardown
    CreditCard.require_verification_value = false
  end
  
  def test_validation
    c = CreditCard.new

    assert !c.valid?
    assert !c.errors.empty?
  end

  def test_valid
    assert @visa.valid?
    assert @visa.errors.empty?
  end
  
  def test_valid_solo_card
    assert @solo.valid?
  end
  
  def test_empty_names
    @visa.first_name = ''
    @visa.last_name = '' 
    
    assert !@visa.valid?
    assert !@visa.errors.empty?
  end
  
  def test_liberate_bogus_card
    c = CreditCard.new
    c.type = 'bogus'
    c.first_name = "Name"
    c.last_name = "Last"
    c.month  = 7
    c.year   = 2008
    c.valid?
    assert c.valid?
    c.type   = 'visa'
    assert !c.valid?
  end

  def test_invalid_card_numbers
    @visa.number = nil
    assert !@visa.valid?
    
    @visa.number = "11112222333344ff"
    assert !@visa.valid?

    @visa.number = "111122223333444"
    assert !@visa.valid?

    @visa.number = "11112222333344444"
    assert !@visa.valid?
  end
  
  def test_valid_card_number
    @visa.number = "4242424242424242"
    assert @visa.valid?
  end

  def test_valid_card_month
    @visa.month  = Time.now.month
    @visa.year   = Time.now.year
    assert @visa.valid?
  end
 
  def test_edge_cases_for_valid_months
    @visa.month = 13
    @visa.year = Time.now.year
    assert !@visa.valid?

    @visa.month = 0
    @visa.year = Time.now.year
    assert !@visa.valid?
  end 

  def test_edge_cases_for_valid_years
    @visa.year  = Time.now.year - 1
    assert !@visa.valid?

    @visa.year  = Time.now.year + 21
    assert !@visa.valid?
  end

  def test_valid_year
    @visa.year = Time.now.year + 1
    assert @visa.valid?
  end

  def test_wrong_cardtype

    c = CreditCard.new(
      "type"    => "visa",
      "number"  => "4779139500118580",
      "month"   => 10,
      "year"    => 2007,
      "first_name"    => "Tobias",
      "last_name"    => "Luetke"
    )

    assert c.valid?

    c.type = "master"
    assert !c.valid?

  end

  def test_constructor

    c = CreditCard.new(  
      "type"    => "visa",
      "number"  => "4779139500118580",
      "month"   => "10",
      "year"    => "2007",
      "first_name"    => "Tobias",
      "last_name"    => "Luetke"
    )

    assert_equal "4779139500118580", c.number
    assert_equal "10", c.month
    assert_equal "2007", c.year
    assert_equal "Tobias Luetke", c.name
    assert_equal "visa", c.type        
    c.valid?
  end

  def test_display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new('number' => '1111222233331234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new('number' => '111222233331234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new('number' => '1112223331234').display_number

     assert_equal 'XXXX-XXXX-XXXX-', CreditCard.new('number' => nil).display_number
    assert_equal 'XXXX-XXXX-XXXX-', CreditCard.new('number' => '').display_number
    assert_equal 'XXXX-XXXX-XXXX-123', CreditCard.new('number' => '123').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new('number' => '1234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new('number' => '01234').display_number
  end

  def test_format_expiry_year
    year = 2005
    
    assert_equal '2005', format_year(year)
    assert_equal '05', format_year(year, :two_digit)
    assert_equal '2005', format_year(year, :four_digit)
    assert_equal '5', format_year(05)
    assert_equal '05', format_year(05, :two_digit)
    assert_equal '0005', format_year(05, :four_digit)
    
  end

  def test_format_expiry_month
    month = 8
    assert_equal '8', format_month(month)
    assert_equal '08', format_month(month, :two_digit)
  end

  def test_valid_expiry_months
    assert !valid_month?(-1)
    1.upto(12){ |m| assert valid_month?(m) }
    assert !valid_month?(13)
  end

  def test_expired_date
    last_month = Time.now - 2.months
    date = CreditCard::ExpiryDate.new(last_month.month, last_month.year)
    assert date.expired?
  end

  def test_today_is_not_expired
    today = Time.now
    date = CreditCard::ExpiryDate.new(today.month, today.year)
    assert !date.expired?
  end

  def test_not_expired
    next_month = Time.now + 1.month
    date = CreditCard::ExpiryDate.new(next_month.month, next_month.year)
    assert !date.expired?
  end

  def test_valid_expiry_year
    0.upto(20){ |n| assert valid_expiry_year?(Time.now.year + n) }
  end

  def test_invalid_expiry_year
    assert !valid_expiry_year?(-1)
    assert !valid_expiry_year?(Time.now.year + 21)
  end

  def test_type
    assert_equal 'visa', CreditCard.type?('4242424242424242')
    assert_equal 'american_express', CreditCard.type?('341111111111111')
    assert_nil CreditCard.type?('')
  end
  
  def test_does_not_require_verification_value
    assert !CreditCard.requires_verification_value?
    assert @visa.valid?
  end
  
  def test_requires_verification_value
    CreditCard.require_verification_value = true

    assert CreditCard.requires_verification_value?
    
    card = CreditCard.new(
      :type   => "visa",
      :number => "4779139500118580",
      :month  => Time.now.month,
      :year   => Time.now.year + 1,
      :first_name  => "Test",
      :last_name   => "Mensch"
    )
    
    assert !card.valid?
    card.verification_value = '123'
    assert card.valid?
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
  
  def test_solo_is_valid_with_start_date
    @solo.start_month = nil
    @solo.start_year = nil
    @solo.issue_number = nil
    
    assert !@solo.valid?
    assert @solo.errors.on('start_month')
    assert @solo.errors.on('start_year')
    assert @solo.errors.on('issue_number')
    
    @solo.start_month = 2
    @solo.start_year = 2007
    assert @solo.valid?
  end
  
  def test_solo_is_valid_with_issue_number
    @solo.start_month = nil
    @solo.start_year = 2005
    @solo.issue_number = nil
    
    assert !@solo.valid?
    assert @solo.errors.on('start_month')
    assert !@solo.errors.on('start_year')
    assert @solo.errors.on('issue_number')
    
    @solo.issue_number = 3
    assert @solo.valid?
  end
end
