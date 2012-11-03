require 'test_helper'

class CustomAssertionsTest < Test::Unit::TestCase
	def test_capture_post_data
		gateway = mock()
		captured_data = capture_post_data(gateway) do |gateway|
			gateway.ssl_post('url', 'Some post data')
		end
		assert_equal 'Some post data', captured_data
	end

	def test_assert_no_xml_element_basic
		xml = <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <Transaction>
        <Amount>1000</Amount>
        <CardNumber>4111111111111111</CardNumber>
      </Transaction>
    XML

		assert_no_xml_element(xml, 'ExpDate')
	end

	def test_assert_no_xml_element_nested
		xml = <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <Transaction>
        <Amount>1000</Amount>
        <CardNumber>4111111111111111</CardNumber>
        <Customer>
        	<Name>John Doe</Name>
        </Customer>
        <Details>
        	<Tax>100</Tax>
        </Details>
      </Transaction>
    XML

		assert_no_xml_element(xml, 'Details/Name')
		assert_no_xml_element(xml, 'Name')
		assert_no_xml_element(xml, 'Customer/Tax')
	end

	def test_assert_no_xml_element_on_root
		xml = <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <Transaction>
        <Amount>1000</Amount>
        <CardNumber>4111111111111111</CardNumber>
      </Transaction>
    XML

		assert_no_xml_element(xml, 'Transaction')
	end

	def test_assert_xml_element_basic
		xml = <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <Transaction>
        <Amount>1000</Amount>
        <CardNumber>4111111111111111</CardNumber>
      </Transaction>
    XML

		assert_xml_element(xml, 'Amount')
	end

	def test_assert_xml_element_nested
		xml = <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <Transaction>
        <Amount>1000</Amount>
        <CardNumber>4111111111111111</CardNumber>
        <Customer>
        	<Name>John Doe</Name>
        </Customer>
      </Transaction>
    XML

		assert_xml_element(xml, '//Name')
		assert_xml_element(xml, '*/Name')
		assert_xml_element(xml, 'Customer/Name')
	end

	def test_assert_xml_element_text
		xml = <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <Transaction>
        <Amount>1000</Amount>
        <CardNumber>4111111111111111</CardNumber>
        <Customer>
        	<Name>John Doe</Name>
        </Customer>
      </Transaction>
    XML

		assert_xml_element_text(xml, 'Amount', '1000')
		assert_xml_element_text(xml, '//Name', 'John Doe')
		assert_xml_element_text(xml, '*/Name', 'John Doe')
		assert_xml_element_text(xml, 'Customer/Name', 'John Doe')
	end

	def test_assert_xml_element_text_multiple
		xml = <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <Transaction>
        <Amount>1000</Amount>
        <Amount>2000</Amount>
      </Transaction>
    XML

		assert_xml_element_text(xml, 'Amount', '1000')
	end

end
