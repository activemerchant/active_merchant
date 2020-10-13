require 'mechanize/test_case'

class TestMechanizeFormOption < Mechanize::TestCase

  def setup
    super

    page = html_page <<-BODY
<form name="form1" method="post" action="/form_post">
  <select name="select">
    <option value="1">Option 1</option>
    <option value="2" selected>Option 2</option>
  </select>
</form>
    BODY

    form = page.forms.first
    @select = form.fields.first
    @option1 = @select.options.first
    @option2 = @select.options.last
  end

  def test_inspect
    assert_match "value: 2", @select.inspect
  end

  def test_value_missing_value
    option = node 'option'
    option.inner_html = 'blah'
    option = Mechanize::Form::Option.new option, nil

    assert_equal 'blah', option.value
  end

  def test_click
    @option1.click

    assert @option1.selected?
  end

  def test_select
    @option1.select

    assert @option1.selected?
  end

  def test_unselect
    @option2.unselect

    refute @option2.selected?
  end

  def test_selected_eh
    refute @option1.selected?
    assert @option2.selected?
  end

end

