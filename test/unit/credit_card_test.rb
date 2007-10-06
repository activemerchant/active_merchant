require File.dirname(__FILE__) + '/../test_helper'

class CreditCardTest < Test::Unit::TestCase
  def setup
    CreditCard.require_verification_value = false
    @visa = credit_card("4779139500118580",   :type => "visa")
    @solo = credit_card("676700000000000000", :type => "solo", :issue_number => '01')
  end
  
  def teardown
    CreditCard.require_verification_value = false
  end
  
  def generate_valid_test_card(options={})
    CreditCard.new({
      :type       => "visa",
      :number     => "4779139500118580",
      :month      => Time.now.month,
      :year       => Time.now.year,
      :first_name => "Tobias",
      :last_name  => "Luetke"      
    }.merge(options))
  end
  
  def test_constructor_should_properly_assign_values
    c = generate_valid_test_card

    assert_equal "4779139500118580", c.number
    assert_equal Time.now.month, c.month
    assert_equal Time.now.year, c.year
    assert_equal "Tobias Luetke", c.name
    assert_equal "visa", c.type
    assert_valid c
  end
  
  def test_new_credit_card_should_not_be_valid
    c = CreditCard.new

    assert_not_valid c
    assert_false     c.errors.empty?
  end

  def test_should_be_a_valid_visa_card
    assert_valid @visa
    assert       @visa.errors.empty?
  end
  
  def test_should_be_a_valid_solo_card
    assert_valid @solo
    assert       @solo.errors.empty?
  end
  
  def test_cards_with_empty_names_should_not_be_valid
    @visa.first_name = ''
    @visa.last_name  = '' 
    
    assert_not_valid @visa
    assert_false     @visa.errors.empty?
  end
  
  def test_should_be_able_to_access_errors_indifferently
    @visa.first_name = ''
    
    assert_not_valid @visa
    assert @visa.errors.on(:first_name)
    assert @visa.errors.on("first_name")
  end
  
  def test_should_be_able_to_liberate_a_bogus_card
    c = generate_valid_test_card(:type => 'bogus', :number => '')
    assert_valid c
    
    c.type = 'visa'
    assert_not_valid c
  end

  def test_should_be_able_to_identify_invalid_card_numbers
    @visa.number = nil
    assert_not_valid @visa
    
    @visa.number = "11112222333344ff"
    assert_not_valid @visa
    assert_false @visa.errors.on(:type)
    assert       @visa.errors.on(:number)

    @visa.number = "111122223333444"
    assert_not_valid @visa
    assert_false @visa.errors.on(:type)
    assert       @visa.errors.on(:number)

    @visa.number = "11112222333344444"
    assert_not_valid @visa
    assert_false @visa.errors.on(:type)
    assert       @visa.errors.on(:number)
  end

  def test_should_have_errors_with_invalid_card_type_for_otherwise_correct_number
    @visa.type = 'master'
    
    assert_not_valid @visa
    assert_not_equal @visa.errors.on(:number), @visa.errors.on(:type)
  end

  def test_should_be_invalid_with_empty_type
    @visa.type = ''
    
    assert_not_valid @visa
    assert_false @visa.errors.on(:number)
    assert_match /is required/, @visa.errors.on(:type)
    assert  @visa.errors.on(:type)
  end

  def test_should_be_a_valid_card_number
    @visa.number = "4242424242424242"
    
    assert_valid @visa
  end

  def test_should_require_a_valid_card_month
    @visa.month  = Time.now.month
    @visa.year   = Time.now.year
    
    assert_valid @visa
  end

  def test_should_not_be_valid_with_empty_month
    @visa.month = ''
    
    assert_not_valid @visa
    assert @visa.errors.on('month')
  end

  def test_should_not_be_valid_for_edge_month_cases
    @visa.month = 13
    @visa.year = Time.now.year
    assert_not_valid @visa
    assert @visa.errors.on('month')

    @visa.month = 0
    @visa.year = Time.now.year
    assert_not_valid @visa
    assert @visa.errors.on('month')
  end 

  def test_should_be_invalid_with_empty_year
    @visa.year = ''
    assert_not_valid @visa
    assert @visa.errors.on('year')
  end

  def test_should_not_be_valid_for_edge_year_cases
    @visa.year  = Time.now.year - 1
    assert_not_valid @visa
    assert @visa.errors.on('year')

    @visa.year  = Time.now.year + 21
    assert_not_valid @visa
    assert @visa.errors.on('year')
  end

  def test_should_be_a_valid_future_year
    @visa.year = Time.now.year + 1
    assert_valid @visa
  end

  def test_should_identify_wrong_cardtype
    c = generate_valid_test_card(:type => 'master')
    assert_not_valid c
  end

  def test_should_display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '1111222233331234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '111222233331234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '1112223331234').display_number

    assert_equal 'XXXX-XXXX-XXXX-',     CreditCard.new(:number => nil).display_number
    assert_equal 'XXXX-XXXX-XXXX-',     CreditCard.new(:number => '').display_number
    assert_equal 'XXXX-XXXX-XXXX-123',  CreditCard.new(:number => '123').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '1234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '01234').display_number
  end

  def test_should_correctly_identify_card_type
    assert_equal 'visa',             CreditCard.type?('4242424242424242')
    assert_equal 'american_express', CreditCard.type?('341111111111111')
    assert_nil CreditCard.type?('')
  end
  
  def test_should_be_able_to_require_a_verification_value
    CreditCard.require_verification_value = true
    assert CreditCard.requires_verification_value?
  end
  
  def test_should_not_be_valid_when_requiring_a_verification_value
    CreditCard.require_verification_value = true
    card = generate_valid_test_card
    assert_not_valid card
    
    card.verification_value = '123'
    assert_valid card
  end
  
  def test_should_require_valid_start_date_for_solo_or_switch
    @solo.start_month  = nil
    @solo.start_year   = nil
    @solo.issue_number = nil
    
    assert_not_valid @solo
    assert @solo.errors.on('start_month')
    assert @solo.errors.on('start_year')
    assert @solo.errors.on('issue_number')
    
    @solo.start_month = 2
    @solo.start_year  = 2007
    assert_valid @solo
  end
  
  def test_should_require_a_valid_issue_number_for_solo_or_switch
    @solo.start_month  = nil
    @solo.start_year   = 2005
    @solo.issue_number = nil
    
    assert_not_valid @solo
    assert @solo.errors.on('start_month')
    assert @solo.errors.on('issue_number')
    
    @solo.issue_number = 3
    assert_valid @solo
  end
  
  def test_should_return_last_four_digits_of_card_number
    ccn = CreditCard.new(:number => "4779139500118580")
    assert_equal "8580", ccn.last_digits
  end
  
  def test_should_be_true_when_credit_card_has_a_first_name
    c = CreditCard.new
    assert_false c.first_name?
    
    c = CreditCard.new(:first_name => 'James')
    assert c.first_name?
  end
  
  def test_should_be_true_when_credit_card_has_a_last_name
    c = CreditCard.new
    assert_false c.last_name?
    
    c = CreditCard.new(:last_name => 'Herdman')
    assert c.last_name?
  end
  
  def test_should_test_for_a_full_name
    c = CreditCard.new
    assert_false c.name?

    c = CreditCard.new(:first_name => 'James', :last_name => 'Herdman')
    assert c.name?
  end
  
  # Huh?
#  def test_validate_new_card
#    credit_card = CreditCard.new
#    
#    assert_nothing_raised do
#      credit_card.validate
#    end
#  end
  
  # Huh?
#  def test_create_and_validate_credit_card_from_type
#    credit_card = CreditCard.new(:type => CreditCard.type?('4242424242424242'))
#    
#    assert_nothing_raised do
#      credit_card.valid?
#    end
#  end
end
