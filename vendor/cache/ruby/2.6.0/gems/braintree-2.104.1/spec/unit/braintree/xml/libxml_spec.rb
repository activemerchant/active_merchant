require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::Xml::Libxml do
  describe "self.parse" do
    it "typecasts integers" do
      xml = "<root><foo type=\"integer\">123</foo></root>"
      Braintree::Xml::Libxml.parse(xml).should == {"root"=>{"foo"=>{"__content__"=>"123", "type"=>"integer"}}}
    end

    it "works with dashes or underscores" do
      xml = <<-END
        <root>
          <dash-es />
          <under_scores />
        </root>
      END
      Braintree::Xml::Libxml.parse(xml).should == {"root"=>{"dash-es"=>{}, "under_scores"=>{}}}
    end

    it "uses nil if nil=true, otherwise uses empty string" do
      xml = <<-END
        <root>
          <a_nil_value nil="true"></a_nil_value>
          <an_empty_string></an_empty_string>
        </root>
      END
      Braintree::Xml::Libxml.parse(xml).should == {"root"=>{"a_nil_value"=>{"nil"=>"true"}, "an_empty_string"=>{}}}
    end

    it "typecasts dates and times" do
      xml = <<-END
        <root>
          <created-at type="datetime">2009-10-28T10:19:49Z</created-at>
        </root>
      END
      Braintree::Xml::Libxml.parse(xml).should == {"root"=>{"created-at"=>{"__content__"=>"2009-10-28T10:19:49Z", "type"=>"datetime"}}}
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
      Braintree::Xml::Libxml.parse(xml).should == {"root"=>{"customers"=>{"type"=>"array", "customer"=>[{"name"=>{"__content__"=>"Adam"}}, {"name"=>{"__content__"=>"Ben"}}]}}}
    end
  end
end
