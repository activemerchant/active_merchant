module Braintree
  class DisputeGateway # :nodoc:
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def accept(dispute_id)
      raise ArgumentError, "dispute_id contains invalid characters" unless dispute_id.to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "dispute_id cannot be blank" if dispute_id.nil? || dispute_id.to_s.strip == ""

      response = @config.http.put("#{@config.base_merchant_path}/disputes/#{dispute_id}/accept")
      if response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        SuccessfulResult.new
      end
    rescue NotFoundError
      raise NotFoundError, "dispute with id #{dispute_id} not found"
    end

    def add_file_evidence(dispute_id, document_id_or_request)
      raise ArgumentError, "dispute_id contains invalid characters" unless dispute_id.to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "dispute_id cannot be blank" if dispute_id.nil? || dispute_id.to_s.strip == ""
      raise ArgumentError, "document_id_or_request cannot be blank" if document_id_or_request.nil?

      request = document_id_or_request.is_a?(Hash) ? document_id_or_request : { document_id: document_id_or_request }

      raise ArgumentError, "document_id contains invalid characters" unless request[:document_id].to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "document_id cannot be blank" if request[:document_id].nil? || dispute_id.to_s.strip == ""
      raise ArgumentError, "category must be a string" if request[:category] && !request[:category].is_a?(String)

      params = {
        evidence: {
          document_upload_id: request[:document_id],
          category: request[:category],
        }
      }
      response = @config.http.post("#{@config.base_merchant_path}/disputes/#{dispute_id}/evidence", params)

      if response[:evidence]
        SuccessfulResult.new(:evidence => Dispute::Evidence.new(response[:evidence]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise "expected :evidence or :api_error_response"
      end
    rescue NotFoundError
      raise NotFoundError, "dispute with id #{dispute_id} not found"
    end

    def add_text_evidence(dispute_id, content_or_request)
      raise ArgumentError, "dispute_id contains invalid characters" unless dispute_id.to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "dispute_id cannot be blank" if dispute_id.nil? || dispute_id.to_s.strip == ""
      raise ArgumentError, "content_or_request cannot be blank" if content_or_request.nil?

      request = content_or_request.is_a?(String) ? { content: content_or_request } : content_or_request

      raise ArgumentError, "content cannot be blank" if request[:content].nil? || request[:content].to_s.strip == ""
      raise ArgumentError, "request can only contain the keys [:content, :category, :sequence_number]" if (request.keys - [:category, :content, :tag, :sequence_number]).any?
      raise ArgumentError, "sequence_number must be an integer" if request[:sequence_number] && request[:sequence_number].to_s.match(/\D/)
      raise ArgumentError, "tag must be a string" if request[:tag] && !request[:tag].is_a?(String)
      raise ArgumentError, "category must be a string" if request[:category] && !request[:category].is_a?(String)

      warn "[DEPRECATED] tag as an option is deprecated. Please use category" if request[:tag]

      category = request[:category] || request[:tag]

      params_for_http_post = {
        evidence: {
          comments: request[:content]
        }.tap do |evidence_params|
          evidence_params[:category] = category if category
          evidence_params[:sequence_number] = request[:sequence_number] if request[:sequence_number]
        end
      }
      response = @config.http.post("#{@config.base_merchant_path}/disputes/#{dispute_id}/evidence", params_for_http_post)

      if response[:evidence]
        SuccessfulResult.new(:evidence => Dispute::Evidence.new(response[:evidence]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise "expected :evidence or :api_error_response"
      end
    rescue NotFoundError
      raise NotFoundError, "dispute with id #{dispute_id} not found"
    end

    def finalize(dispute_id)
      raise ArgumentError, "dispute_id contains invalid characters" unless dispute_id.to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "dispute_id cannot be blank" if dispute_id.nil? || dispute_id.to_s.strip == ""

      response = @config.http.put("#{@config.base_merchant_path}/disputes/#{dispute_id}/finalize")
      if response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        SuccessfulResult.new
      end
    rescue NotFoundError
      raise NotFoundError, "dispute with id #{dispute_id} not found"
    end

    def find(dispute_id)
      raise ArgumentError, "dispute_id contains invalid characters" unless dispute_id.to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "dispute_id cannot be blank" if dispute_id.nil? || dispute_id.to_s.strip == ""
      response = @config.http.get("#{@config.base_merchant_path}/disputes/#{dispute_id}")
      Dispute._new(response[:dispute])
    rescue NotFoundError
      raise NotFoundError, "dispute with id #{dispute_id} not found"
    end

    def remove_evidence(dispute_id, evidence_id)
      raise ArgumentError, "dispute_id contains invalid characters" unless dispute_id.to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "dispute_id cannot be blank" if dispute_id.nil? || dispute_id.to_s.strip == ""
      raise ArgumentError, "evidence_id contains invalid characters" unless evidence_id.to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "evidence_id cannot be blank" if evidence_id.nil? || evidence_id.to_s.strip == ""

      response = @config.http.delete("#{@config.base_merchant_path}/disputes/#{dispute_id}/evidence/#{evidence_id}")

      if response.respond_to?(:to_hash) && response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        SuccessfulResult.new
      end
    rescue NotFoundError
      raise NotFoundError, "evidence with id #{evidence_id} for dispute with id #{dispute_id} not found"
    end

    def search(&block)
      search = DisputeSearch.new
      block.call(search) if block

      paginated_results = PaginatedCollection.new { |page| _fetch_disputes(search, page) }
      SuccessfulResult.new(:disputes => paginated_results)
    end

    def _fetch_disputes(search, page)
      response = @config.http.post("#{@config.base_merchant_path}/disputes/advanced_search?page=#{page}", {:search => search.to_hash, :page => page})
      body = response[:disputes]
      disputes = Util.extract_attribute_as_array(body, :dispute).map { |d| Dispute._new(d) }

      PaginatedResult.new(body[:total_items], body[:page_size], disputes)
    end
  end
end
