require 'mechanize/test_case'

class TestMechanizeFormTextarea < Mechanize::TestCase
  def setup
    super

    @page  = @mech.get("http://localhost/tc_textarea.html")
  end

  def test_empty_text_area
    form = @page.forms_with(:name => 'form1').first
    assert_equal('', form.field_with(:name => 'text1').value)
    form.text1 = 'Hello World'
    assert_equal('Hello World', form.field_with(:name => 'text1').value)
    page = @mech.submit(form)
    assert_equal(1, page.links.length)
    assert_equal('text1:Hello World', page.links[0].text)
  end

  def test_non_empty_textfield
    form = @page.forms_with(:name => 'form2').first
    assert_equal('sample text', form.field_with(:name => 'text1').value)
    page = @mech.submit(form)
    assert_equal(1, page.links.length)
    assert_equal('text1:sample text', page.links[0].text)
  end

  def test_multi_textfield
    form = @page.form_with(:name => 'form3')

    assert_equal(2, form.fields_with(:name => 'text1').length)
    assert_equal('', form.fields_with(:name => 'text1')[0].value)
    assert_equal('sample text', form.fields_with(:name => 'text1')[1].value)

    form.text1 = 'Hello World'

    assert_equal('Hello World', form.fields_with(:name => 'text1')[0].value)
    assert_equal('sample text', form.fields_with(:name => 'text1')[1].value)

    page = @mech.submit(form)

    assert_equal(2, page.links.length)

    link = page.links_with(:text => 'text1:sample text')

    assert_equal(1, link.length)

    link = page.links_with(:text => 'text1:Hello World')

    assert_equal(1, link.length)
  end
end
