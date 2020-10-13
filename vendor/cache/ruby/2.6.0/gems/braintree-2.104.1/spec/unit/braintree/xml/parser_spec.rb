require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::Xml::Parser do
  describe "self.hash_from_xml" do
    it "typecasts integers" do
      xml = "<root><foo type=\"integer\">123</foo></root>"
      xml.should parse_to(:root => {:foo => 123})
    end

    it "works with dashes or underscores" do
      xml = <<-END
        <root>
          <dash-es />
          <under_scores />
        </root>
      END
      xml.should parse_to(:root=>{:dash_es=>"", :under_scores=>""})
    end

    it "uses nil if nil=true, otherwise uses empty string" do
      xml = <<-END
        <root>
          <a_nil_value nil="true"></a_nil_value>
          <an_empty_string></an_empty_string>
        </root>
      END
      xml.should parse_to(:root => {:a_nil_value => nil, :an_empty_string => ""})
    end

    it "typecasts datetimes" do
      xml = <<-END
        <root>
          <created-at type="datetime">2009-10-28T10:19:49Z</created-at>
        </root>
      END
      xml.should parse_to(:root => {:created_at => Time.utc(2009, 10, 28, 10, 19, 49)})
    end

    it "doesn't typecast dates" do
      xml = <<-END
        <root>
          <created-at type="date">2009-10-28</created-at>
        </root>
      END
      xml.should parse_to(:root => {:created_at => "2009-10-28"})
    end

    it "builds an array if type=array" do
      xml = <<-END
        <root>
          <customers type="array">
            <customer><name>Adam</name></customer>
            <customer><name>Ben</name></customer>
          </customers>
        </root>
      END
      xml.should parse_to(:root => {:customers => [{:name => "Adam"}, {:name => "Ben"}]})
    end

    it "parses using libxml when not using ruby 2.0" do
      xml = "<root><foo type=\"integer\">123</foo></root>"
      stub_const("RUBY_VERSION", "2.1.1")
      ::Braintree::Xml::Libxml.should_receive(:parse).and_call_original

      Braintree::Xml::Parser.hash_from_xml(xml)
    end

    it "parses using rexml when using ruby 2.0 to avoid Libxml segfault" do
      segfault_prone_library_in_ruby_2_0 = ::Braintree::Xml::Libxml

      xml = "<root><foo type=\"integer\">123</foo></root>"
      stub_const("RUBY_VERSION", "2.0.0")

      ::Braintree::Xml::Rexml.should_receive(:parse).and_call_original
      segfault_prone_library_in_ruby_2_0.should_not_receive(:parse)

      Braintree::Xml::Parser.hash_from_xml(xml)
    end
  end
end
