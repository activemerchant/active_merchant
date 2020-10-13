require 'mechanize/test_case'

class TestMechanizeFormCheckBox < Mechanize::TestCase

  def setup
    super

    @page = @mech.get('http://localhost/tc_checkboxes.html')
  end

  def test_search
    form = @page.forms.first

    checkbox = form.checkbox_with(name: 'green')
    assert_equal('green', checkbox.name)

    assert_equal(checkbox, form.checkbox_with('green'))
    assert_equal(checkbox, form.checkbox_with(search: 'input[@type=checkbox][@name=green]'))
  end

  def test_check
    form = @page.forms.first

    form.checkbox_with(:name => 'green').check

    assert(form.checkbox_with(:name => 'green').checked)

    %w{ red blue yellow brown }.each do |color|
      assert_equal(false, form.checkbox_with(:name => color).checked)
    end
  end

  def test_uncheck
    form = @page.forms.first

    checkbox = form.checkbox_with(:name => 'green')

    checkbox.check

    assert form.checkbox_with(:name => 'green').checked

    checkbox.uncheck

    assert !form.checkbox_with(:name => 'green').checked
  end

end

