require "test_helper"

class RailsCompatibilityTest < Test::Unit::TestCase
  def test_should_be_able_to_access_errors_indifferently
    cc = credit_card("4779139500118580", :first_name => "")

    silence_deprecation_warnings do
      assert !cc.valid?
      assert cc.errors.on(:first_name)
      assert cc.errors.on("first_name")
      assert_equal "cannot be empty", cc.errors.on(:first_name)
    end
  end
end
