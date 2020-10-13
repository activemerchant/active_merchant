require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

describe Braintree do
  it "doesn't produce warnings if loading braintree.rb twice" do
    lib_dir = File.expand_path(File.dirname(__FILE__) + "/../../lib")
    braintree_file = "#{lib_dir}/braintree.rb"
    File.exist?(braintree_file).should == true
    output = `ruby -r rubygems -I #{lib_dir} -e 'load #{braintree_file.inspect}; load #{braintree_file.inspect}' 2>&1`
    output = output.gsub(/^.*warning: constant ::Fixnum is deprecated.*\n/, "")
    output.should == ""
  end
end
