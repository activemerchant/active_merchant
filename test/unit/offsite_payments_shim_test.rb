require "test_helper"

class OffsitePaymentsShimTest < Test::Unit::TestCase
  def test_should_get_a_deprecation_warning_if_accessing_integrations
    assert_deprecation_warning do
      silence_warnings do
        ActiveMerchant::Billing::Integrations::A1agregator::Helper.new(:boom, :boom)
      end
    end
  end
end
