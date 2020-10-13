module Braintree
  class DocumentUploadGateway # :nodoc:
    include BaseModule

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def create(attributes)
      Util.verify_keys(DocumentUploadGateway._create_signature, attributes)
      _do_create "/document_uploads", {"document_upload[kind]" => attributes[:kind]}, attributes[:file]
    end

    def create!(*args)
      return_object_or_raise(:document_upload) { create(*args) }
    end

    def self._create_signature # :nodoc:
      [
        :kind,
        :file
      ]
    end

    def _do_create(path, params, file) # :nodoc:
      response = @config.http.post("#{@config.base_merchant_path}#{path}", params, file)
      if response[:document_upload]
        SuccessfulResult.new(:document_upload => DocumentUpload._new(response[:document_upload]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :document_upload or :api_error_response"
      end
    end
  end
end
