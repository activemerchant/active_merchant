require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::DocumentUpload do
  describe "initialize" do
    it "sets attributes" do
      response = {:size => 555, :kind => "evidence_document", :name => "up_file.pdf", :content_type => "application/pdf", :id => "my_id"}
      document_upload = Braintree::DocumentUpload._new(response)
      document_upload.id.should == "my_id"
      document_upload.size.should == 555
      document_upload.name.should == "up_file.pdf"
      document_upload.content_type.should == "application/pdf"
      document_upload.kind.should == Braintree::DocumentUpload::Kind::EvidenceDocument
    end
  end

  describe "kind" do
    it "sets identity document" do
      response = {:size => 555, :kind => "identity_document", :name => "up_file.pdf", :content_type => "application/pdf", :id => "my_id"}
      document_upload = Braintree::DocumentUpload._new(response)
      document_upload.kind.should == Braintree::DocumentUpload::Kind::IdentityDocument
    end

    it "sets evidence document" do
      response = {:size => 555, :kind => "evidence_document", :name => "up_file.pdf", :content_type => "application/pdf", :id => "my_id"}
      document_upload = Braintree::DocumentUpload._new(response)
      document_upload.kind.should == Braintree::DocumentUpload::Kind::EvidenceDocument
    end

    it "sets payout invoice document" do
      response = {:size => 555, :kind => "payout_invoice_document", :name => "up_file.pdf", :content_type => "application/pdf", :id => "my_id"}
      document_upload = Braintree::DocumentUpload._new(response)
      document_upload.kind.should == Braintree::DocumentUpload::Kind::PayoutInvoiceDocument
    end
  end
end
