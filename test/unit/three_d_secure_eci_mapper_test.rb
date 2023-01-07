require 'test_helper'

class ThreeDSecureEciMapperTest < Test::Unit::TestCase
  ThreeDSecureEciMapper = ActiveMerchant::Billing::ThreeDSecureEciMapper

  [
    { eci: '00', brands: %i[master maestro], expected_eci_mapping: ThreeDSecureEciMapper::NON_THREE_D_SECURE_TRANSACTION },
    { eci: '01', brands: %i[master maestro], expected_eci_mapping: ThreeDSecureEciMapper::ATTEMPTED_AUTHENTICATION_TRANSACTION },
    { eci: '02', brands: %i[master maestro], expected_eci_mapping: ThreeDSecureEciMapper::FULLY_AUTHENTICATED_TRANSACTION },
    { eci: '05', brands: %i[visa american_express discover diners_club jcb dankort elo], expected_eci_mapping: ThreeDSecureEciMapper::FULLY_AUTHENTICATED_TRANSACTION },
    { eci: '06', brands: %i[visa american_express discover diners_club jcb dankort elo], expected_eci_mapping: ThreeDSecureEciMapper::ATTEMPTED_AUTHENTICATION_TRANSACTION },
    { eci: '07', brands: %i[visa american_express discover diners_club jcb dankort elo], expected_eci_mapping: ThreeDSecureEciMapper::NON_THREE_D_SECURE_TRANSACTION }
  ].each do |test_spec|
    test_spec[:brands].each do |brand|
      eci = test_spec[:eci]
      expected_eci_mapping = test_spec[:expected_eci_mapping]
      test "#map for #{brand} and '#{eci}' returns :#{expected_eci_mapping}" do
        assert_equal expected_eci_mapping, ThreeDSecureEciMapper.map(brand, eci)
      end
    end
  end

  test "#map for :unknown_brand and '05' returns nil" do
    assert_nil ThreeDSecureEciMapper.map(:unknown_brand, '05')
  end

  test "#map for :visa and 'unknown_eci' returns nil" do
    assert_nil ThreeDSecureEciMapper.map(:visa, 'unknown_eci')
  end
end
