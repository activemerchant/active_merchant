require 'mechanize/test_case'

class TestMechanizeFormField < Mechanize::TestCase

  def test_inspect
    field = node 'input'
    field = Mechanize::Form::Field.new field, 'a&b'

    assert_match "value: a&b", field.inspect
  end

  def test_name
    field = node 'input', 'name' => 'a&b'
    field = Mechanize::Form::Field.new field

    assert_equal 'a&b', field.name
  end

  def test_name_entity
    field = node 'input', 'name' => 'a&amp;b'
    field = Mechanize::Form::Field.new field

    assert_equal 'a&b', field.name
  end

  def test_name_entity_numeric
    field = node 'input', 'name' => 'a&#38;b'
    field = Mechanize::Form::Field.new field

    assert_equal 'a&b', field.name
  end

  def test_spaceship
    doc = Nokogiri::HTML::Document.new
    node = doc.create_element('input')
    node['name'] = 'foo'
    node['value'] = 'bar'

    a = Mechanize::Form::Field.new(node)
    b = Mechanize::Form::Field.new({'name' => 'foo'}, 'bar')
    c = Mechanize::Form::Field.new({'name' => 'foo'}, 'bar')

    assert_equal [a, b], [a, b].sort
    assert_equal [a, b], [b, a].sort
    assert_equal [b, c].sort, [b, c].sort
  end

  def test_value
    field = node 'input'
    field = Mechanize::Form::Field.new field, 'a&b'

    assert_equal 'a&b', field.value
  end

  def test_value_entity
    field = node 'input'
    field = Mechanize::Form::Field.new field, 'a&amp;b'

    assert_equal 'a&b', field.value
  end

  def test_value_entity_numeric
    field = node 'input'
    field = Mechanize::Form::Field.new field, 'a&#38;b'

    assert_equal 'a&b', field.value
  end

  def test_raw_value
    field = node 'input'
    field = Mechanize::Form::Field.new field, 'a&amp;b'

    assert_equal 'a&amp;b', field.raw_value
  end

end

