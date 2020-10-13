require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe "Braintree::ResourceCollection" do
  describe "enumeration" do
    it "iterates over the elements, yielding to the block in pages" do
      values = %w(a b c d e)
      collection = Braintree::ResourceCollection.new(:search_results => {:ids => [0,1,2,3,4], :page_size => 2}) do |ids|
        ids.map {|id| values[id] }
      end

      count = 0
      collection.each_with_index do |item, index|
        item.should == values[index]
        count += 1
      end

      count.should == 5
    end
  end

  describe "#ids" do
    it "returns a list of the resource collection ids" do
      collection = Braintree::ResourceCollection.new(:search_results => {:ids => [0,1,2,3,4], :page_size => 2})
      collection.ids.should == [0,1,2,3,4]
    end
  end

  it "returns an empty array when the collection is empty" do
    collection = Braintree::ResourceCollection.new(:search_results => {:page_size => 2})
    collection.ids.should == []
  end
end
