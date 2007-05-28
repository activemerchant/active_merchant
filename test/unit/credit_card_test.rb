require File.dirname(__FILE__) + '/../test_helper'

class CreditCardTest < Test::Unit::TestCase
  MAESTRO_CARDS = [ '5000000000000000', '5099999999999999', '5600000000000000',
    '5899999999999999', '6000000000000000', '6999999999999999']
  
  NON_MAESTRO_CARDS = [ '4999999999999999', '5100000000000000', '5599999999999999',
    '5900000000000000', '5999999999999999', '7000000000000000' ]
    
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
      :number => "676700000000000000",
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
  
  def test_validate_new_card
    credit_card = CreditCard.new
    
    assert_nothing_raised do
      credit_card.validate
    end
  end
  
  def test_create_and_validate_credit_card_from_type
    credit_card = CreditCard.new(:type => CreditCard.type?('4242424242424242'))
    
    assert_nothing_raised do
      credit_card.valid?
    end
  end
  
  def test_ensure_type_from_credit_card_class_is_not_frozen
    type = CreditCard.type?('4242424242424242')
    assert !type.frozen?
  end
  
  def test_dankort_card_type
    assert_equal 'dankort', CreditCard.type?('5019717010103742')
  end
  
  def test_visa_dankort_detected_as_visa
    assert_equal 'visa', CreditCard.type?('4571100000000000')
  end
  
  def test_electron_dk_detected_as_visa
    assert_equal 'visa', CreditCard.type?('4175001000000000')
  end
  
  def test_detect_diners_club
    assert_equal 'diners_club', CreditCard.type?('36148010000000')
  end
  
  def test_detect_diners_club_dk
    assert_equal 'diners_club', CreditCard.type?('30401000000000')
  end
  
  def test_detect_maestro
    assert_equal 'maestro', CreditCard.type?('5020100000000000')
  end
    
  def test_maestro_dk_detects_as_maestro
    assert_equal 'maestro', CreditCard.type?('6769271000000000')
  end
  
  def test_maestro_range
    MAESTRO_CARDS.each{ |number| assert_equal 'maestro', CreditCard.type?(number) }
    
    NON_MAESTRO_CARDS.each{ |number| assert_not_equal 'maestro', CreditCard.type?(number) }
  end
  
  def test_mastercard_range
    assert_equal 'master', CreditCard.type?('6771890000000000')
    assert_equal 'master', CreditCard.type?('5413031000000000')
  end
  
  def test_forbrugsforeningen
    assert_equal 'forbrugsforeningen', CreditCard.type?('6007221000000000')
  end
  
  def test_laser_card
    # 16 digits
    assert_equal 'laser', CreditCard.type?('6304985028090561')
    
    # 18 digits
    assert_equal 'laser', CreditCard.type?('630498502809056151')
    
    # 19 digits
    assert_equal 'laser', CreditCard.type?('6304985028090561515')
    
    # 17 digits
    assert_not_equal 'laser', CreditCard.type?('63049850280905615')
    
    # 15 digits
    assert_not_equal 'laser', CreditCard.type?('630498502809056')
    
    # Alternate format
    assert_equal 'laser', CreditCard.type?('670695000000000000')
  end
end
