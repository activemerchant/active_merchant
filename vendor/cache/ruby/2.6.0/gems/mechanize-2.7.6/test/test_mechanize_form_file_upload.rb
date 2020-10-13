require 'mechanize/test_case'

class TestMechanizeFormFileUpload < Mechanize::TestCase

  def test_file_name
    field = node 'input'
    field = Mechanize::Form::FileUpload.new field, 'a&b'

    assert_equal 'a&b', field.file_name
  end

  def test_file_name_entity
    field = node 'input'
    field = Mechanize::Form::FileUpload.new field, 'a&amp;b'

    assert_equal 'a&b', field.file_name
  end

end

