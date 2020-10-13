require 'mechanize/test_case'

class TestMechanizeForm < Mechanize::TestCase

  def setup
    super

    @uri = URI 'http://example'
    @page = page @uri

    @form = Mechanize::Form.new node('form', 'name' => @NAME), @mech, @page
  end

  def test_action
    form = Mechanize::Form.new node('form', 'action' => '?a=b&amp;b=c')

    assert_equal '?a=b&b=c', form.action
  end

  def test_add_button_to_query
    button = Mechanize::Form::Button.new node('input', 'type' => 'submit')

    e = assert_raises ArgumentError do
      @form.add_button_to_query button
    end

    assert_equal "#{button.inspect} does not belong to the same page " \
                 "as the form \"#{@NAME}\" in #{@uri}",
                 e.message
  end

  def test_aset
    assert_empty @form.keys

    @form['intarweb'] = 'Aaron'

    assert_equal 'Aaron', @form['intarweb']
  end

  def test_aset_exists
    page = html_page <<-BODY
<title>Page Title</title>
<form name="post_form">
  <input name="first" type="text" id="name_first">
  <input name="first" type="text">
  <input type="submit" value="Submit">
</form>
    BODY

    form = page.form_with(:name => 'post_form')

    assert_equal %w[first first], form.keys

    form['first'] = 'Aaron'

    assert_equal 'Aaron', form['first']
    assert_equal ['Aaron', ''], form.values
  end

  def test_build_query_blank_form
    page = @mech.get('http://localhost/tc_blank_form.html')
    form = page.forms.first
    query = form.build_query
    assert(query.length > 0)
    assert query.all? { |x| x[1] == '' }
  end

  def test_build_query_radio_button_duplicate
    html = Nokogiri::HTML <<-HTML
<form>
  <input type=radio name=name value=a checked=true>
  <input type=radio name=name value=a checked=true>
</form>
    HTML

    form = Mechanize::Form.new html.at('form'), @mech, @page

    query = form.build_query

    assert_equal [%w[name a]], query
  end

  def test_build_query_radio_button_multiple_checked
    html = Nokogiri::HTML <<-HTML
<form>
  <input type=radio name=name value=a checked=true>
  <input type=radio name=name value=b checked=true>
</form>
    HTML

    form = Mechanize::Form.new html.at('form'), @mech, @page

    e = assert_raises Mechanize::Error do
      form.build_query
    end

    assert_equal 'radiobuttons "a, b" are checked in the "name" group, ' \
                 'only one is allowed',
                 e.message
  end

  def test_method_missing_get
    page = html_page <<-BODY
<form>
  <input name="not_a_method" value="some value">
</form>
    BODY

    form = page.forms.first

    assert_equal 'some value', form.not_a_method
  end

  def test_method_missing_set
    page = html_page <<-BODY
<form>
  <input name="not_a_method">
</form>
    BODY

    form = page.forms.first

    form.not_a_method = 'some value'

    assert_equal [%w[not_a_method some\ value]], form.build_query
  end

  def test_parse_buttons
    page = html_page <<-BODY
<form>
  <input type="submit" value="submit">
  <input type="button" value="submit">
  <button type="submit" value="submit">
  <button type="button" value="submit">
  <input type="image" name="submit" src="/button.jpeg">
  <input type="image" src="/button.jpeg">
</form>
    BODY

    form = page.forms.first
    buttons = form.buttons.sort

    assert buttons.all? { |b| Mechanize::Form::Button === b }

    assert_equal 'submit', buttons.shift.type
    assert_equal 'button', buttons.shift.type
    assert_equal 'submit', buttons.shift.type
    assert_equal 'button', buttons.shift.type
    assert_equal 'image',  buttons.shift.type
    assert_equal 'image',  buttons.shift.type

    assert_empty buttons
  end

  def test_parse_select
    page = html_page <<-BODY
<form>
  <select name="multi" multiple></select>
  <select name="single"></select>
</form>
    BODY

    form = page.forms.first
    selects = form.fields.sort

    multi = selects.shift
    assert_kind_of Mechanize::Form::MultiSelectList, multi

    single = selects.shift
    assert_kind_of Mechanize::Form::SelectList, single

    assert_empty selects
  end

  def test_checkboxes_no_input_name
    page = @mech.get('http://localhost/form_no_input_name.html')
    form = page.forms.first

    assert_equal(0, form.checkboxes.length)
  end

  def test_field_with
    page = @mech.get("http://localhost/google.html")
    search = page.forms.find { |f| f.name == "f" }

    assert(search.field_with(:name => 'q'))
    assert(search.field_with(:name => 'hl'))
    assert(search.fields.find { |f| f.name == 'ie' })
  end

  def test_fields_no_input_name
    page = @mech.get('http://localhost/form_no_input_name.html')
    form = page.forms.first

    assert_equal(0, form.fields.length)
  end

  def test_file_uploads_no_value
    page = @mech.get("http://localhost/file_upload.html")
    form = page.form('value_test')
    assert_nil(form.file_uploads.first.value)
    assert_nil(form.file_uploads.first.file_name)
  end

  def test_forms_no_input_name
    page = @mech.get('http://localhost/form_no_input_name.html')
    form = page.forms.first

    assert_equal(0, form.radiobuttons.length)
  end

  def test_has_field_eh
    refute @form.has_field? 'name'

    @form['name'] = 'Aaron'

    assert_equal true, @form.has_field?('name')
  end

  def test_has_value_eh
    refute @form.has_value? 'Aaron'

    @form['name'] = 'Aaron'

    assert_equal true, @form.has_value?('Aaron')
  end

  def test_keys
    assert_empty @form.keys

    @form['name'] = 'Aaron'

    assert_equal %w[name], @form.keys
  end

  def test_parse_textarea
    form = Nokogiri::HTML <<-FORM
<form>
<textarea name="t">hi</textarea>
</form>
    FORM

    form = Mechanize::Form.new form, @mech
    textarea = form.fields.first

    assert_kind_of Mechanize::Form::Textarea, textarea
    assert_equal 'hi', textarea.value
  end

  def test_post_with_rails_3_encoding_hack
    page = @mech.get("http://localhost/rails_3_encoding_hack_form_test.html")
    form = page.forms.first
    form.submit
  end

  def test_post_with_blank_encoding
    page = @mech.get("http://localhost/form_test.html")
    form = page.form('post_form1')
    form.page.encoding = nil
    form.submit
  end

  def test_set_fields_duplicate
    page = html_page '<form><input name="a" value="b"><input name="a"></form>'
    form = page.forms.first

    form.set_fields :a => 'c'

    assert_equal 'c', form.fields.first.value
    assert_equal '', form.fields.last.value
  end

  def test_set_fields_none
    page = html_page '<form><input name="a" value="b"></form>'
    form = page.forms.first

    form.set_fields

    assert_equal 'b', form.fields.first.value
  end

  def test_set_fields_many
    page = html_page '<form><input name="a" value="b"><input name="b"></form>'
    form = page.forms.first

    form.set_fields :a => 'c', :b => 'd'

    assert_equal 'c', form.fields.first.value
    assert_equal 'd', form.fields.last.value
  end

  def test_set_fields_one
    page = html_page '<form><input name="a" value="b"></form>'
    form = page.forms.first

    form.set_fields :a => 'c'

    assert_equal 'c', form.fields.first.value
  end

  def test_set_fields_position
    page = html_page '<form><input name="a" value="b"><input name="a"></form>'
    form = page.forms.first

    form.set_fields :a => { 0 => 'c', 1 => 'd' }

    assert_equal 'c', form.fields.first.value
    assert_equal 'd', form.fields.last.value
  end

  def test_set_fields_position_crappily
    page = html_page '<form><input name="a" value="b"><input name="a"></form>'
    form = page.forms.first

    form.set_fields :a => ['c', 1]

    assert_equal 'b', form.fields.first.value
    assert_equal 'c', form.fields.last.value
  end

  def test_values
    assert_empty @form.values

    @form['name'] = 'Aaron'

    assert_equal %w[Aaron], @form.values
  end

  def test_no_form_action
    page = @mech.get('http://localhost:2000/form_no_action.html')
    page.forms.first.fields.first.value = 'Aaron'
    page = @mech.submit(page.forms.first)
    assert_match('/form_no_action.html?first=Aaron', page.uri.to_s)
  end

  def test_submit_first_field_wins
    page = @mech.get('http://localhost/tc_field_precedence.html')
    form = page.forms.first

    assert !form.checkboxes.empty?
    assert_equal "1", form.checkboxes.first.value

    submitted = form.submit

    assert_equal 'ticky=1&ticky=0', submitted.parser.at('#query').text
  end

  def test_submit_takes_arbirary_headers
    page = @mech.get('http://localhost:2000/form_no_action.html')
    assert form = page.forms.first
    form.action = '/http_headers'
    page = @mech.submit(form, nil, { 'foo' => 'bar' })

    headers = page.body.split("\n").map { |x| x.split('|', 2) }.flatten
    headers = Hash[*headers]

    assert_equal 'bar', headers['foo']
  end

  def test_submit_select_default_all
    page = html_page <<-BODY
<form name="form1" method="post" action="/form_post">
  <select name="list">
    <option value="1" selected>Option 1</option>
    <option value="2" selected>Option 2</option>
    <option value="3" selected>Option 3</option>
    <option value="4" selected>Option 4</option>
    <option value="5" selected>Option 5</option>
    <option value="6" selected>Option 6</option>
  </select>
  <br />
  <input type="submit" value="Submit" />
</form>
    BODY

    form = page.forms.first
    assert_equal "6", form.list

    page = @mech.submit form
    assert_equal 1, page.links.length
    assert_equal 1, page.links_with(:text => 'list:6').length
  end

  def test_submit_select_default_none
    page = html_page <<-BODY
<form name="form1" method="post" action="/form_post">
  <select name="list">
    <option value="1">Option 1</option>
    <option value="2">Option 2</option>
    <option>Option No Value</option>
    <option value="3">Option 3</option>
    <option value="4">Option 4</option>
    <option value="5">Option 5</option>
    <option value="6">Option 6</option>
  </select>
  <br />
  <input type="submit" value="Submit" />
</form>
    BODY

    form = page.forms.first

    assert_equal "1", form.list
    page = @mech.submit form

    assert_equal 1, page.links.length
    assert_equal 1, page.links_with(:text => 'list:1').length
  end

  def test_form_select_default_noopts
    page = html_page <<-BODY
<form name="form1" method="post" action="/form_post">
  <select name="list">
  </select>
  <br />
  <input type="submit" value="Submit" />
</form>
    BODY
    form = page.forms.first

    assert form.field 'list'
    assert_nil form.list

    page = @mech.submit form

    assert_empty page.links
  end

  # Test submitting form with two fields of the same name
  def test_post_multival
    page = @mech.get("http://localhost/form_multival.html")
    form = page.form_with(:name => 'post_form')

    assert_equal(2, form.fields_with(:name => 'first').length)

    form.fields_with(:name => 'first')[0].value = 'Aaron'
    form.fields_with(:name => 'first')[1].value = 'Patterson'

    page = @mech.submit(form)

    assert_equal(2, page.links.length)
    assert(page.link_with(:text => 'first:Aaron'))
    assert(page.link_with(:text => 'first:Patterson'))
  end

  # Test calling submit on the form object
  def test_submit_on_form
    page = @mech.get("http://localhost/form_multival.html")
    form = page.form_with(:name => 'post_form')

    assert_equal(2, form.fields_with(:name => 'first').length)

    form.fields_with(:name => 'first')[0].value = 'Aaron'
    form.fields_with(:name => 'first')[1].value = 'Patterson'

    page = form.submit

    assert_equal(2, page.links.length)
    assert(page.link_with(:text => 'first:Aaron'))
    assert(page.link_with(:text => 'first:Patterson'))
  end

  # Test submitting form with two fields of the same name
  def test_get_multival
    page = @mech.get("http://localhost/form_multival.html")
    form = page.form_with(:name => 'get_form')

    assert_equal(2, form.fields_with(:name => 'first').length)

    form.fields_with(:name => 'first')[0].value = 'Aaron'
    form.fields_with(:name => 'first')[1].value = 'Patterson'

    page = @mech.submit(form)

    assert_equal(2, page.links.length)
    assert(page.link_with(:text => 'first:Aaron'))
    assert(page.link_with(:text => 'first:Patterson'))
  end

  def test_post_with_non_strings
    page = @mech.get("http://localhost/form_test.html")
    page.form('post_form1') do |form|
      form.first_name = 10
    end.submit
  end

  def test_post_with_bang
    page = @mech.get("http://localhost/form_test.html")
    page.form_with!(:name => 'post_form1') do |form|
      form.first_name = 10
    end.submit
  end

  def test_post
    page = @mech.get("http://localhost/form_test.html")
    post_form = page.forms.find { |f| f.name == "post_form1" }

    assert_equal("post", post_form.method.downcase)
    assert_equal("/form_post", post_form.action)

    assert_equal(3, post_form.fields.size)

    assert_equal(1, post_form.buttons.size)
    assert_equal(2, post_form.radiobuttons.size)
    assert_equal(3, post_form.checkboxes.size)
    assert(post_form.fields.find { |f| f.name == "first_name" },
           "First name field was nil")
    assert(post_form.fields.find { |f| f.name == "country" },
           "Country field was nil")
    assert(post_form.radiobuttons.find { |f| f.name == "gender" && f.value == "male"},
           "Gender male button was nil")

    assert(post_form.radiobuttons.find {|f| f.name == "gender" && f.value == "female"},
           "Gender female button was nil")

    assert(post_form.checkboxes.find { |f| f.name == "cool person" },
           "couldn't find cool person checkbox")
    assert(post_form.checkboxes.find { |f| f.name == "likes ham" },
           "couldn't find likes ham checkbox")
    assert(post_form.checkboxes.find { |f| f.name == "green[eggs]" },
           "couldn't find green[eggs] checkbox")

    # Find the select list
    s = post_form.fields.find { |f| f.name == "country" }
    assert_equal(2, s.options.length)
    assert_equal("USA", s.value)
    assert_equal("USA", s.options.first.value)
    assert_equal("USA", s.options.first.text)
    assert_equal("CANADA", s.options[1].value)
    assert_equal("CANADA", s.options[1].text)

    # Now set all the fields
    post_form.fields.find { |f| f.name == "first_name" }.value = "Aaron"
    post_form.radiobuttons.find { |f|
      f.name == "gender" && f.value == "male"
    }.checked = true
    post_form.checkboxes.find { |f| f.name == "likes ham" }.checked = true
    post_form.checkboxes.find { |f| f.name == "green[eggs]" }.checked = true
    page = @mech.submit(post_form, post_form.buttons.first)

    # Check that the submitted fields exist
    assert_equal(5, page.links.size, "Not enough links")
    assert(page.links.find { |l| l.text == "likes ham:on" },
           "likes ham check box missing")
    assert(page.links.find { |l| l.text == "green[eggs]:on" },
           "green[eggs] check box missing")
    assert(page.links.find { |l| l.text == "first_name:Aaron" },
           "first_name field missing")
    assert(page.links.find { |l| l.text == "gender:male" },
           "gender field missing")
    assert(page.links.find { |l| l.text == "country:USA" },
           "select box not submitted")
  end

  def test_post_multipart
    page = @mech.get("http://localhost/form_test.html")
    post_form = page.forms.find { |f| f.name == "post_form4_multipart" }
    assert(post_form, "Post form is null")
    assert_equal("post", post_form.method.downcase)
    assert_equal("/form_post", post_form.action)

    assert_equal(1, post_form.fields.size)
    assert_equal(1, post_form.buttons.size)

    page = @mech.submit(post_form, post_form.buttons.first)

    assert page
  end

  def test_select_box
    page = @mech.get("http://localhost/form_test.html")
    post_form = page.forms.find { |f| f.name == "post_form1" }

    assert(page.header)
    assert(page.root)
    assert_equal(0, page.iframes.length)
    assert_equal("post", post_form.method.downcase)
    assert_equal("/form_post", post_form.action)

    # Find the select list
    s = post_form.field_with(:name => /country/)

    assert_equal(2, s.options.length)
    assert_equal("USA", s.value)
    assert_equal("USA", s.options.first.value)
    assert_equal("USA", s.options.first.text)
    assert_equal("CANADA", s.options[1].value)
    assert_equal("CANADA", s.options[1].text)

    # Now set all the fields
    post_form.field_with(:name => /country/).value = s.options[1]
    assert_equal('CANADA', post_form.country)
    page = @mech.submit(post_form, post_form.buttons.first)

    # Check that the submitted fields exist
    assert(page.links.find { |l| l.text == "country:CANADA" },
           "select box not submitted")
  end

  def test_get
    page = @mech.get("http://localhost/form_test.html")
    get_form = page.forms.find { |f| f.name == "get_form1" }

    assert_equal("get", get_form.method.downcase)
    assert_equal("/form_post", get_form.action)
    assert_equal(1, get_form.fields.size)
    assert_equal(2, get_form.buttons.size)
    assert_equal(2, get_form.radiobuttons.size)
    assert_equal(3, get_form.checkboxes.size)
    assert(get_form.fields.find { |f| f.name == "first_name" },
           "First name field was nil")
    assert(get_form.radiobuttons.find { |f| f.name == "gender" && f.value == "male"},
           "Gender male button was nil")

    assert(get_form.radiobuttons.find {|f| f.name == "gender" && f.value == "female"},
           "Gender female button was nil")

    assert(get_form.checkboxes.find { |f| f.name == "cool person" },
           "couldn't find cool person checkbox")
    assert(get_form.checkboxes.find { |f| f.name == "likes ham" },
           "couldn't find likes ham checkbox")
    assert(get_form.checkboxes.find { |f| f.name == "green[eggs]" },
           "couldn't find green[eggs] checkbox")

    # Set up the image button
    img = get_form.buttons.find { |f| f.name == "button" }
    img.x = "9"
    img.y = "10"
    # Now set all the fields
    get_form.fields.find { |f| f.name == "first_name" }.value = "Aaron"
    get_form.radiobuttons.find { |f|
      f.name == "gender" && f.value == "male"
    }.checked = true
    get_form.checkboxes.find { |f| f.name == "likes ham" }.checked = true
    get_form.checkboxes.find { |f| f.name == "green[eggs]" }.checked = true
    page = @mech.submit(get_form, get_form.buttons.first)

    # Check that the submitted fields exist
    assert_equal(6, page.links.size, "Not enough links")
    assert(page.links.find { |l| l.text == "likes ham:on" },
           "likes ham check box missing")
    assert(page.links.find { |l| l.text == "green[eggs]:on" },
           "green[eggs] check box missing")
    assert(page.links.find { |l| l.text == "first_name:Aaron" },
           "first_name field missing")
    assert(page.links.find { |l| l.text == "gender:male" },
           "gender field missing")
    assert(page.links.find { |l| l.text == "button.y:10" },
           "Image button missing")
    assert(page.links.find { |l| l.text == "button.x:9" },
           "Image button missing")
  end

  def test_reset
    page = @mech.get("http://localhost/form_test.html")
    get_form = page.forms.find { |f| f.name == "get_form1" }

    image_button = get_form.buttons.first
    submit_button = get_form.submits.first

    new_page = @mech.submit(get_form, submit_button)
    assert_equal "http://localhost/form_post?first_name=", new_page.uri.to_s

    new_page = @mech.submit(get_form, image_button)
    assert_equal "http://localhost/form_post?first_name=&button.x=0&button.y=0", new_page.uri.to_s

    get_form.reset

    new_page = @mech.submit(get_form, submit_button)
    assert_equal "http://localhost/form_post?first_name=", new_page.uri.to_s
  end

  def test_post_with_space_in_action
    page = @mech.get("http://localhost/form_test.html")
    post_form = page.forms.find { |f| f.name == "post_form2" }

    assert_equal("post", post_form.method.downcase)
    assert_equal("/form post", post_form.action)
    assert_equal(1, post_form.fields.size)
    assert_equal(1, post_form.buttons.size)
    assert_equal(2, post_form.radiobuttons.size)
    assert_equal(2, post_form.checkboxes.size)
    assert(post_form.fields.find { |f| f.name == "first_name" },
           "First name field was nil")
    assert(post_form.radiobuttons.find { |f| f.name == "gender" && f.value == "male"},
           "Gender male button was nil")

    assert(post_form.radiobuttons.find {|f| f.name == "gender" && f.value == "female"},
           "Gender female button was nil")

    assert(post_form.checkboxes.find { |f| f.name == "cool person" },
           "couldn't find cool person checkbox")
    assert(post_form.checkboxes.find { |f| f.name == "likes ham" },
           "couldn't find likes ham checkbox")

    # Now set all the fields
    post_form.fields.find { |f| f.name == "first_name" }.value = "Aaron"
    post_form.radiobuttons.find { |f|
      f.name == "gender" && f.value == "male"
    }.checked = true
    post_form.checkboxes.find { |f| f.name == "likes ham" }.checked = true
    page = @mech.submit(post_form, post_form.buttons.first)

    # Check that the submitted fields exist
    assert_equal(3, page.links.size, "Not enough links")
    assert(page.links.find { |l| l.text == "likes ham:on" },
           "likes ham check box missing")
    assert(page.links.find { |l| l.text == "first_name:Aaron" },
           "first_name field missing")
    assert(page.links.find { |l| l.text == "gender:male" },
           "gender field missing")
  end

  def test_get_with_space_in_action
    page = @mech.get("http://localhost/form_test.html")
    get_form = page.forms.find { |f| f.name == "get_form2" }

    assert_equal("get", get_form.method.downcase)
    assert_equal("/form post", get_form.action)
    assert_equal(1, get_form.fields.size)
    assert_equal(1, get_form.buttons.size)
    assert_equal(2, get_form.radiobuttons.size)
    assert_equal(2, get_form.checkboxes.size)
    assert(get_form.fields.find { |f| f.name == "first_name" },
           "First name field was nil")
    assert(get_form.radiobuttons.find { |f| f.name == "gender" && f.value == "male"},
           "Gender male button was nil")

    assert(get_form.radiobuttons.find {|f| f.name == "gender" && f.value == "female"},
           "Gender female button was nil")

    assert(get_form.checkboxes.find { |f| f.name == "cool person" },
           "couldn't find cool person checkbox")
    assert(get_form.checkboxes.find { |f| f.name == "likes ham" },
           "couldn't find likes ham checkbox")

    # Now set all the fields
    get_form.fields.find { |f| f.name == "first_name" }.value = "Aaron"
    get_form.radiobuttons.find { |f|
      f.name == "gender" && f.value == "male"
    }.checked = true
    get_form.checkboxes.find { |f| f.name == "likes ham" }.checked = true
    page = @mech.submit(get_form, get_form.buttons.first)

    # Check that the submitted fields exist
    assert_equal(3, page.links.size, "Not enough links")
    assert(page.links.find { |l| l.text == "likes ham:on" },
           "likes ham check box missing")
    assert(page.links.find { |l| l.text == "first_name:Aaron" },
           "first_name field missing")
    assert(page.links.find { |l| l.text == "gender:male" },
           "gender field missing")
  end

  def test_post_with_param_in_action
    page = @mech.get("http://localhost/form_test.html")
    post_form = page.forms.find { |f| f.name == "post_form3" }

    assert_equal("post", post_form.method.downcase)
    assert_equal("/form_post?great day=yes&one=two", post_form.action)
    assert_equal(1, post_form.fields.size)
    assert_equal(1, post_form.buttons.size)
    assert_equal(2, post_form.radiobuttons.size)
    assert_equal(2, post_form.checkboxes.size)

    assert(post_form.fields.find { |f| f.name == "first_name" },
           "First name field was nil")

    male_button = post_form.radiobuttons.find { |f|
      f.name == "gender" && f.value == "male"
    }
    assert(male_button, "Gender male button was nil")

    female_button = post_form.radiobuttons.find { |f|
      f.name == "gender" && f.value == "female"
    }

    assert(female_button, "Gender female button was nil")

    assert(post_form.checkbox_with(:name => "cool person"),
           "couldn't find cool person checkbox")

    assert(post_form.checkboxes.find { |f| f.name == "likes ham" },
                   "couldn't find likes ham checkbox")

    # Now set all the fields
    post_form.field_with(:name => 'first_name').value = "Aaron"
    post_form.radiobuttons.find { |f|
      f.name == "gender" && f.value == "male"
    }.checked = true
    post_form.checkboxes.find { |f| f.name == "likes ham" }.checked = true

    page = @mech.submit(post_form, post_form.buttons.first)

    # Check that the submitted fields exist
    assert_equal(3, page.links.size, "Not enough links")

    assert(page.links.find { |l| l.text == "likes ham:on" },
           "likes ham check box missing")
    assert(page.links.find { |l| l.text == "first_name:Aaron" },
           "first_name field missing")
    assert(page.links.find { |l| l.text == "gender:male" },
           "gender field missing")
  end

  def test_get_with_param_in_action
    page = @mech.get("http://localhost/form_test.html")
    get_form = page.forms.find { |f| f.name == "get_form3" }

    assert_equal("get", get_form.method.downcase)
    assert_equal("/form_post?great day=yes&one=two", get_form.action)
    assert_equal(1, get_form.fields.size)
    assert_equal(1, get_form.buttons.size)
    assert_equal(2, get_form.radiobuttons.size)
    assert_equal(2, get_form.checkboxes.size)
    assert(get_form.fields.find { |f| f.name == "first_name" },
           "First name field was nil")
    assert(get_form.radiobuttons.find { |f| f.name == "gender" && f.value == "male"},
           "Gender male button was nil")

    assert(get_form.radiobuttons.find {|f| f.name == "gender" && f.value == "female"},
           "Gender female button was nil")

    assert(get_form.checkboxes.find { |f| f.name == "cool person" },
           "couldn't find cool person checkbox")
    assert(get_form.checkboxes.find { |f| f.name == "likes ham" },
           "couldn't find likes ham checkbox")

    # Now set all the fields
    get_form.fields.find { |f| f.name == "first_name" }.value = "Aaron"
    get_form.radiobuttons.find { |f|
      f.name == "gender" && f.value == "male"
    }.checked = true
    get_form.checkboxes.find { |f| f.name == "likes ham" }.checked = true
    page = @mech.submit(get_form, get_form.buttons.first)
    # Check that the submitted fields exist
    assert_equal(3, page.links.size, "Not enough links")
    assert(page.links.find { |l| l.text == "likes ham:on" },
           "likes ham check box missing")
    assert(page.links.find { |l| l.text == "first_name:Aaron" },
           "first_name field missing")
    assert(page.links.find { |l| l.text == "gender:male" },
           "gender field missing")
  end

  def test_field_addition
    page = @mech.get("http://localhost/form_test.html")
    get_form = page.forms.find { |f| f.name == "get_form1" }
    get_form.field("first_name").value = "Gregory"
    assert_equal( "Gregory", get_form.field("first_name").value )
  end

  def test_fields_as_accessors
    page = @mech.get("http://localhost/form_multival.html")
    form = page.form_with(:name => 'post_form')

    assert_equal(2, form.fields_with(:name => 'first').length)

    form.first = 'Aaron'
    assert_equal('Aaron', form.first)
  end

  def test_form_and_fields_dom_id
    # blatant copypasta of test above
    page = @mech.get("http://localhost/form_test.html")
    form = page.form_with(dom_id: 'generic_form')

    assert_equal(1, form.fields_with(dom_id: 'name_first').length)
    assert_equal('first_name', form.field_with(dom_id: 'name_first').name)

    assert_equal(form, page.form_with(id: 'generic_form'))
    assert_equal(form, page.form_with(css: '#generic_form'))

    fields_by_dom_id = form.fields_with(dom_id: 'name_first')
    assert_equal(fields_by_dom_id, form.fields_with(id: 'name_first'))
    assert_equal(fields_by_dom_id, form.fields_with(css: '#name_first'))
    assert_equal(fields_by_dom_id, form.fields_with(xpath: '//*[@id="name_first"]'))
    assert_equal(fields_by_dom_id, form.fields_with(search: '//*[@id="name_first"]'))
  end

  def test_form_and_fields_dom_class
    # blatant copypasta of test above
    page = @mech.get("http://localhost/form_test.html")
    form = page.form_with(:dom_class => 'really_generic_form')
    form_by_class = page.form_with(:class => 'really_generic_form')

    assert_equal(1, form.fields_with(:dom_class => 'text_input').length)
    assert_equal('first_name', form.field_with(:dom_class => 'text_input').name)

    #  *_with(:class => blah) should work exactly like (:dom_class => blah)
    assert_equal(form, form_by_class)
    assert_equal(form.fields_with(:dom_class => 'text_input'), form.fields_with(:class => 'text_input'))
  end

  def test_add_field
    page = @mech.get("http://localhost/form_multival.html")
    form = page.form_with(:name => 'post_form')

    number_of_fields = form.fields.length

    assert form.add_field!('intarweb')
    assert_equal(number_of_fields + 1, form.fields.length)
  end

  def test_delete_field
    page = @mech.get("http://localhost/form_multival.html")
    form = page.form_with(:name => 'post_form')

    number_of_fields = form.fields.length
    assert_equal 2, number_of_fields

    form.delete_field!('first')
    assert_nil(form['first'])
    assert_equal(number_of_fields - 2, form.fields.length)
  end

  def test_has_field
    page = @mech.get("http://localhost/form_multival.html")
    form = page.form_with(:name => 'post_form')

    assert_equal false, form.has_field?('intarweb')
    assert form.add_field!('intarweb')
    assert_equal true, form.has_field?('intarweb')
  end

  def test_fill_unexisting_form
    page = @mech.get("http://localhost/empty_form.html")
    assert_raises(NoMethodError) {
      page.form_with(:name => 'no form') { |f| f.foo = 'bar' }
    }
    begin
      page.form_with!(:name => 'no form') { |f| f.foo = 'bar' }
    rescue => e
      assert_instance_of Mechanize::ElementNotFoundError, e
      assert_kind_of Mechanize::Page, e.source
      assert_equal :form, e.element
      assert_kind_of Hash, e.conditions
      assert_equal 'no form', e.conditions[:name]
    end
  end

  def test_field_error
    @page = @mech.get('http://localhost/empty_form.html')
    form = @page.forms.first
    assert_raises(NoMethodError) {
      form.foo = 'asdfasdf'
    }

    assert_raises(NoMethodError) {
      form.foo
    }
  end

  def test_form_build_query
    page = @mech.get("http://localhost/form_order_test.html")
    get_form = page.forms.first

    query = get_form.build_query

    expected = [
      %w[1 RADIO],
      %w[3 nobody@example],
      %w[2 TEXT],
      %w[3 2011-10],
    ]

    assert_equal expected, query
  end

  def test_form_input_disabled
    page = html_page <<-BODY
<form name="form1" method="post" action="/form_post">
  <input type="text" name="opa" value="omg" disabled />
  <input type="submit" value="Submit" />
</form>
    BODY
    form = page.forms.first

    page = @mech.submit form

    assert_empty page.links
  end

  def test_form_built_from_array_post
    submitted = @mech.post(
      'http://example/form_post',
      [
        %w[order_matters 0],
        %w[order_matters 1],
        %w[order_matters 2],
        %w[mess_it_up asdf]
      ]
    )

    assert_equal 'order_matters=0&order_matters=1&order_matters=2&mess_it_up=asdf', submitted.parser.at('#query').text
  end

  def test_form_built_from_hashes_submit
    uri = URI 'http://example/form_post'
    page = page uri
    form = Mechanize::Form.new node('form', 'name' => @NAME, 'method' => 'POST'), @mech, page
    form.fields << Mechanize::Form::Field.new({'name' => 'order_matters'}, '0')
    form.fields << Mechanize::Form::Field.new({'name' => 'order_matters'}, '1')
    form.fields << Mechanize::Form::Field.new({'name' => 'order_matters'}, '2')
    form.fields << Mechanize::Form::Field.new({'name' => 'mess_it_up'}, 'asdf')

    submitted = @mech.submit form

    assert_equal 'order_matters=0&order_matters=1&order_matters=2&mess_it_up=asdf', submitted.parser.at('#query').text
  end

end
