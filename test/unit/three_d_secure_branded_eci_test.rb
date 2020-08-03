require 'test_helper'

class ThreeDSecureBrandedEciTest < Test::Unit::TestCase
  [
    { eci: '00', brands: %i[master maestro], generic_eci: :non_three_d_secure_transaction },
    { eci: '01', brands: %i[master maestro], generic_eci: :attempted_authentication_transaction },
    { eci: '02', brands: %i[master maestro], generic_eci: :fully_authenticated_transaction },
    { eci: '05', brands: %i[visa american_express discover diners_club jcb dankort elo], generic_eci: :fully_authenticated_transaction },
    { eci: '06', brands: %i[visa american_express discover diners_club jcb dankort elo], generic_eci: :attempted_authentication_transaction },
    { eci: '07', brands: %i[visa american_express discover diners_club jcb dankort elo], generic_eci: :non_three_d_secure_transaction }
  ].each do |test_spec|
    test_spec[:brands].each do |brand|
      eci = test_spec[:eci]
      generic_eci = test_spec[:generic_eci]
      test "#generic_eci(:#{brand}, '#{eci}') returns :#{generic_eci}" do
        assert_equal generic_eci, ActiveMerchant::Billing::ThreeDSecureBrandedEci.new(brand, eci).generic_eci
      end
    end
  end

  test "generic_eci(:unknown_brand, '05') returns nil" do
    assert_nil ActiveMerchant::Billing::ThreeDSecureBrandedEci.new(:unknown_brand, '05').generic_eci
  end

  test "generic_eci(:visa, 'unknown_eci') returns nil" do
    assert_nil ActiveMerchant::Billing::ThreeDSecureBrandedEci.new(:visa, 'unknown_eci').generic_eci
  end
end
