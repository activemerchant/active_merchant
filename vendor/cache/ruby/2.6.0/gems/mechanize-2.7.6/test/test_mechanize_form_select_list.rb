require 'mechanize/test_case'

class TestMechanizeFormSelectList < Mechanize::TestCase

  def setup
    super

    page = html_page <<-BODY
<form name="form1" method="post" action="/form_post">
  <select name="select">
    <option value="1">Option 1</option>
    <option value="2" selected>Option 2</option>
    <option value="3">Option 3</option>
    <option value="4">Option 4</option>
    <option value="5">Option 5</option>
    <option value="6">Option 6</option>
  </select>
</form>
    BODY

    form = page.forms.first
    @select = form.fields.first
  end

  def test_inspect
    assert_match "value: 2", @select.inspect
  end

  def test_option_with
    option = @select.option_with :value => '1'

    assert_equal '1', option.value
  end

  def test_options_with
    options = @select.options_with :value => /[12]/

    assert_equal 2, options.length
  end

  def test_query_value
    assert_equal [%w[select 2]], @select.query_value

    @select.select_all

    assert_equal [%w[select 6]], @select.query_value
  end

  def test_select_all
    @select.select_all

    assert_equal "6", @select.value
  end

  def test_select_none
    @select.select_none

    assert_equal "1", @select.value
  end

  def test_selected_options
    assert_equal [@select.options[1]], @select.selected_options

    @select.options.last.click

    assert_equal [@select.options.last], @select.selected_options
  end

  def test_value
    assert_equal "2", @select.value
  end

  def test_value_equals
    @select.value = %w[a 1 2]

    assert_equal "a", @select.value
  end

end

