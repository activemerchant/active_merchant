require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Xml do
  describe "self.hash_from_xml" do
    it "typecasts integers" do
      hash = Braintree::Xml.hash_from_xml("<root><foo type=\"integer\">123</foo></root>")
      hash.should == {:root => {:foo => 123}}
    end

    it "works with dashes or underscores" do
      xml = <<-END
        <root>
          <dash-es />
          <under_scores />
        </root>
      END

      hash = Braintree::Xml.hash_from_xml(xml)
      hash.should == {:root => {:dash_es => "", :under_scores => ""}}
    end

    it "uses nil if nil=true, otherwise uses empty string" do
      xml = <<-END
        <root>
          <a_nil_value nil="true"></a_nil_value>
          <an_empty_string></an_empty_string>
        </root>
      END
      hash = Braintree::Xml.hash_from_xml(xml)
      hash.should == {:root => {:a_nil_value => nil, :an_empty_string => ""}}
    end

    it "typecasts dates and times" do
      hash = Braintree::Xml.hash_from_xml <<-END
        <root>
          <created-at type="datetime">2009-10-28T10:19:49Z</created-at>
        </root>
      END
      hash.should == {:root => {:created_at => Time.utc(2009, 10, 28, 10, 19, 49)}}
    end

    it "builds an array if type=array" do
      hash = Braintree::Xml.hash_from_xml <<-END
        <root>
          <customers type="array">
            <customer><name>Adam</name></customer>
            <customer><name>Ben</name></customer>
          </customers>
        </root>
      END
      hash.should == {:root => {:customers => [{:name => "Adam"}, {:name => "Ben"}]}}
    end

    it "turns 1 and true to boolean if type = boolean" do
      hash = Braintree::Xml.hash_from_xml <<-END
        <root>
          <casted-true type="boolean">true</casted-true>
          <casted-one type="boolean">1</casted-one>
          <casted-false type="boolean">false</casted-false>
          <casted-anything type="boolean">anything</casted-anything>
          <uncasted-true>true</uncasted-true>
        </root>
      END
      hash.should == {:root => {
        :casted_true => true, :casted_one => true, :casted_anything => false, :casted_false => false,
        :uncasted_true => "true"
      }}
    end

    it "handles values that are arrays of hashes" do
      hash = Braintree::Xml.hash_from_xml("
        <container>
          <elem><value>one</value></elem>
          <elem><value>two</value></elem>
          <elem><value>three</value></elem>
        </container>
      ")
      hash.should == {:container => {:elem => [{:value => "one"}, {:value => "two"}, {:value => "three"}]}}
    end
  end

  describe "self.hash_to_xml" do
    def verify_to_xml_and_back(hash)
      Braintree::Xml.hash_from_xml(Braintree::Xml.hash_to_xml(hash)).should == hash
    end

    it "works for a simple case" do
      hash = {:root => {:foo => "foo_value", :bar => "bar_value"}}
      verify_to_xml_and_back hash
    end

    it "works for arrays" do
      hash = {:root => {:items => [{:name => "first"}, {:name => "second"}]}}
      verify_to_xml_and_back hash
    end

    it "works for arrays of strings" do
      hash = {:root => {:items => ["first", "second"]}}
      verify_to_xml_and_back hash
    end

		context "Integer" do
			it "works for integers" do
				hash = { :root => {:foo => 1 } }
				Braintree::Xml.hash_to_xml(hash).should include("<foo type=\"integer\">1</foo>")
			end
		end

		context "BigDecimal" do
			it "works for BigDecimals" do
				hash = {:root => {:foo => BigDecimal("123.45")}}
				Braintree::Xml.hash_to_xml(hash).should include("<foo>123.45</foo>")
			end

			it "works for BigDecimals with fewer than 2 digits" do
				hash = {:root => {:foo => BigDecimal("1000.0")}}
				Braintree::Xml.hash_to_xml(hash).should include("<foo>1000.00</foo>")
			end

			it "works for BigDecimals with more than 2 digits" do
				hash = {:root => {:foo => BigDecimal("12.345")}}
				Braintree::Xml.hash_to_xml(hash).should include("<foo>12.345</foo>")
			end
		end

		it "works for symbols" do
			hash = {:root => {:foo => :bar}}
			Braintree::Xml.hash_to_xml(hash).should include("<foo>bar</foo>")
		end

    it "type casts booleans" do
      hash = {:root => {:string_true => "true", :bool_true => true, :bool_false => false, :string_false => "false"}}
      verify_to_xml_and_back hash
    end

    it "type casts time" do
      hash = {:root => {:a_time => Time.utc(2009, 10, 28, 1, 2, 3), :a_string_that_looks_like_time => "2009-10-28T10:19:49Z"}}
      verify_to_xml_and_back hash
    end

    it "can distinguish nil from empty string" do
      hash = {:root => {:an_empty_string => "", :a_nil_value => nil}}
      verify_to_xml_and_back hash
    end

    it "includes the encoding" do
      xml = Braintree::Xml.hash_to_xml(:root => {:root => "bar"})
      xml.should include("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    end

    it "works for only a root node and a string" do
      hash = {:id => "123"}
      verify_to_xml_and_back hash
    end

    it "escapes keys and values" do
      hash = { "ke<y" => "val>ue" }
      Braintree::Xml.hash_to_xml(hash).should include("<ke&lt;y>val&gt;ue</ke&lt;y>")
    end

    it "escapes nested keys and values" do
      hash = { "top<" => { "ke<y" => "val>ue" } }
      Braintree::Xml.hash_to_xml(hash).gsub(/\s/, '').should include("<top&lt;><ke&lt;y>val&gt;ue</ke&lt;y></top&lt;>")
    end
  end
end
