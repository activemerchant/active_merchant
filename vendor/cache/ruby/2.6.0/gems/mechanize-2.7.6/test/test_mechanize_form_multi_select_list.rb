require 'mechanize/test_case'

class TestMechanizeFormMultiSelectList < Mechanize::TestCase

  def setup
    super

    page = html_page <<-BODY
<form name="form1" method="post" action="/form_post">
  <select name="select" multiple>
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
    assert_match "value: #{%w[2]}", @select.inspect
  end

  def test_inspect_select_all
    @select.select_all
    assert_match "value: #{%w[1 2 3 4 5 6]}", @select.inspect
  end

  def test_option_with
    option = @select.option_with value: '1'

    assert_equal '1', option.value

    option = @select.option_with search: 'option[@selected]'

    assert_equal '2', option.value
  end

  def test_options_with
    options = @select.options_with :value => /[12]/

    assert_equal 2, options.length
  end

  def test_query_value
    assert_equal [%w[select 2]], @select.query_value

    @select.options.last.click

    assert_equal [%w[select 2], %w[select 6]], @select.query_value
  end

  def test_query_value_empty
    @select.options.last.click
    @select.options.last.instance_variable_set :@value, ''

    assert_equal [%w[select 2], ['select', '']], @select.query_value
  end

  def test_select_all
    @select.select_all

    assert_equal %w[1 2 3 4 5 6], @select.value
  end

  def test_select_none
    @select.select_none

    assert_empty @select.value
  end

  def test_selected_options
    assert_equal [@select.options[1]], @select.selected_options

    @select.options.last.click

    assert_equal [@select.options[1], @select.options.last],
      @select.selected_options
  end

  def test_value
    assert_equal %w[2], @select.value
  end

  def test_value_equals
    @select.value = %w[a 1 2]

    assert_equal %w[a 1 2], @select.value
  end

end

