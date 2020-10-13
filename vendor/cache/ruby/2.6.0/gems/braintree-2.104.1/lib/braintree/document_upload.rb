module Braintree
  class DocumentUpload
    include BaseModule
    include Braintree::Util::IdEquality

    module Kind
      IdentityDocument          = "identity_document"
      EvidenceDocument          = "evidence_document"
      PayoutInvoiceDocument     = "payout_invoice_document"
    end

    attr_reader :content_type
    attr_reader :id
    attr_reader :kind
    attr_reader :name
    attr_reader :size

    def self.create(*args)
      Configuration.gateway.document_upload.create(*args)
    end

    def self.create!(*args)
      Configuration.gateway.document_upload.create!(*args)
    end

    def initialize(attributes) # :nodoc:
      set_instance_variables_from_hash(attributes)
    end

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end
  end
end
