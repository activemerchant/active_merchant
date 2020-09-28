require 'test_helper'

class CountryTest < Test::Unit::TestCase
  def test_country_from_hash
    country = ActiveMerchant::Country.new(:name => 'Canada', :alpha2 => 'CA', :alpha3 => 'CAN', :numeric => '124')
    assert_equal 'CA', country.code(:alpha2).value
    assert_equal 'CAN', country.code(:alpha3).value
    assert_equal '124', country.code(:numeric).value
    assert_equal 'Canada', country.to_s
  end

  def test_country_for_alpha2_code
    country = ActiveMerchant::Country.find('CA')
    assert_equal 'CA', country.code(:alpha2).value
    assert_equal 'CAN', country.code(:alpha3).value
    assert_equal '124', country.code(:numeric).value
    assert_equal 'Canada', country.to_s
  end

  def test_country_for_alpha3_code
    country = ActiveMerchant::Country.find('CAN')
    assert_equal 'Canada', country.to_s
  end

  def test_country_for_numeric_code
    country = ActiveMerchant::Country.find('124')
    assert_equal 'Canada', country.to_s
  end

  def test_find_country_by_name
    country = ActiveMerchant::Country.find('Canada')
    assert_equal 'Canada', country.to_s
  end

  def test_find_country_by_lowercase_name
    country = ActiveMerchant::Country.find('bosnia and herzegovina')
    assert_equal 'Bosnia and Herzegovina', country.to_s
  end

  def test_find_unknown_country_name
    assert_raises(ActiveMerchant::InvalidCountryCodeError) do
      ActiveMerchant::Country.find('Asskickistan')
    end
  end

  def test_find_australia
    country = ActiveMerchant::Country.find('AU')
    assert_equal 'AU', country.code(:alpha2).value

    country = ActiveMerchant::Country.find('Australia')
    assert_equal 'AU', country.code(:alpha2).value
  end

  def test_find_united_kingdom
    country = ActiveMerchant::Country.find('GB')
    assert_equal 'GB', country.code(:alpha2).value

    country = ActiveMerchant::Country.find('United Kingdom')
    assert_equal 'GB', country.code(:alpha2).value
  end

  def test_raise_on_nil_name
    assert_raises(ActiveMerchant::InvalidCountryCodeError) do
      ActiveMerchant::Country.find(nil)
    end
  end

  def test_country_names_are_alphabetized
    country_names = ActiveMerchant::Country::COUNTRIES.map { | each | each[:name] }
    assert_equal(country_names.sort, country_names)
  end

  def test_comparisons
    assert_equal ActiveMerchant::Country.find('GB'), ActiveMerchant::Country.find('GB')
    assert_not_equal ActiveMerchant::Country.find('GB'), ActiveMerchant::Country.find('CA')
    assert_not_equal Object.new, ActiveMerchant::Country.find('GB')
    assert_not_equal ActiveMerchant::Country.find('GB'), Object.new
  end
end
