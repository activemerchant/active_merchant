require 'mechanize/test_case'

class MultiSelectTest < Mechanize::TestCase
  def setup
    super

    @page = @mech.get("http://localhost/form_multi_select.html")
    @form = @page.forms.first
  end

  def test_option_with
    o = @form.field_with(:name => 'list').option_with(:value => '1')
    assert_equal '1', o.value
  end

  def test_options_with
    os = @form.field_with(:name => 'list').options_with(:value => /1|2/)
    assert_equal ['1', '2'].sort, os.map { |x| x.value }.sort
  end

  def test_select_none
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    form.field_with(:name => 'list').select_none
    page = @mech.submit(form)
    assert_equal(0, page.links.length)
  end

  def test_select_all
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    form.field_with(:name => 'list').select_all
    page = @mech.submit(form)
    assert_equal(6, page.links.length)
    assert_equal(1, page.links_with(:text => 'list:1').length)
    assert_equal(1, page.links_with(:text => 'list:2').length)
    assert_equal(1, page.links_with(:text => 'list:3').length)
    assert_equal(1, page.links_with(:text => 'list:4').length)
    assert_equal(1, page.links_with(:text => 'list:5').length)
    assert_equal(1, page.links_with(:text => 'list:6').length)
  end

  def test_click_all
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    form.field_with(:name => 'list').options.each { |o| o.click }
    page = @mech.submit(form)
    assert_equal(5, page.links.length)
    assert_equal(1, page.links_with(:text => 'list:1').length)
    assert_equal(1, page.links_with(:text => 'list:3').length)
    assert_equal(1, page.links_with(:text => 'list:4').length)
    assert_equal(1, page.links_with(:text => 'list:5').length)
    assert_equal(1, page.links_with(:text => 'list:6').length)
  end

  def test_select_default
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    page = @mech.submit(form)
    assert_equal(1, page.links.length)
    assert_equal(1, page.links_with(:text => 'list:2').length)
  end

  def test_select_one
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    form.list = 'Aaron'
    assert_equal(['Aaron'], form.list)
    page = @mech.submit(form)
    assert_equal(1, page.links.length)
    assert_equal('list:Aaron', page.links.first.text)
  end

  def test_select_two
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    form.list = ['1', 'Aaron']
    page = @mech.submit(form)
    assert_equal(2, page.links.length)
    assert_equal(1, page.links_with(:text => 'list:1').length)
    assert_equal(1, page.links_with(:text => 'list:Aaron').length)
  end

  def test_select_three
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    form.list = ['1', '2', '3']
    page = @mech.submit(form)
    assert_equal(3, page.links.length)
    assert_equal(1, page.links_with(:text => 'list:1').length)
    assert_equal(1, page.links_with(:text => 'list:2').length)
    assert_equal(1, page.links_with(:text => 'list:3').length)
  end

  def test_select_three_twice
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    form.list = ['1', '2', '3']
    form.list = ['1', '2', '3']
    page = @mech.submit(form)
    assert_equal(3, page.links.length)
    assert_equal(1, page.links_with(:text => 'list:1').length)
    assert_equal(1, page.links_with(:text => 'list:2').length)
    assert_equal(1, page.links_with(:text => 'list:3').length)
  end

  def test_select_with_click
    page = @mech.get("http://localhost/form_multi_select.html")
    form = page.forms.first
    form.list = ['1', 'Aaron']
    form.field_with(:name => 'list').options[3].tick
    assert_equal(['1', 'Aaron', '4'].sort, form.list.sort)
    page = @mech.submit(form)
    assert_equal(3, page.links.length)
    assert_equal(1, page.links_with(:text => 'list:1').length)
    assert_equal(1, page.links_with(:text => 'list:Aaron').length)
    assert_equal(1, page.links_with(:text => 'list:4').length)
  end
end
