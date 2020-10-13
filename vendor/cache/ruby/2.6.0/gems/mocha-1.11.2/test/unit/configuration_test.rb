require File.expand_path('../../test_helper', __FILE__)
require 'mocha/configuration'

class ConfigurationTest < Mocha::TestCase
  def test_allow_temporarily_changes_config_when_given_block
    Mocha.configure { |c| c.stubbing_method_unnecessarily = :warn }
    yielded = false
    Mocha::Configuration.override(:stubbing_method_unnecessarily => :allow) do
      yielded = true
      assert_equal :allow, Mocha.configuration.stubbing_method_unnecessarily
    end
    assert yielded
    assert_equal :warn, Mocha.configuration.stubbing_method_unnecessarily
  end

  def test_prevent_temporarily_changes_config_when_given_block
    Mocha.configure { |c| c.stubbing_method_unnecessarily = :allow }
    yielded = false
    Mocha::Configuration.override(:stubbing_method_unnecessarily => :prevent) do
      yielded = true
      assert_equal :prevent, Mocha.configuration.stubbing_method_unnecessarily
    end
    assert yielded
    assert_equal :allow, Mocha.configuration.stubbing_method_unnecessarily
  end

  def test_warn_when_temporarily_changes_config_when_given_block
    Mocha.configure { |c| c.stubbing_method_unnecessarily = :allow }
    yielded = false
    Mocha::Configuration.override(:stubbing_method_unnecessarily => :warn) do
      yielded = true
      assert_equal :warn, Mocha.configuration.stubbing_method_unnecessarily
    end
    assert yielded
    assert_equal :allow, Mocha.configuration.stubbing_method_unnecessarily
  end
end
