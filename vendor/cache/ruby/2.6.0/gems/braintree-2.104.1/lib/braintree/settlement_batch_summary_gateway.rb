module Braintree
  class SettlementBatchSummaryGateway # :nodoc
    include BaseModule

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def generate(criteria)
      Util.verify_keys(_signature, criteria)
      response = @config.http.post("#{@config.base_merchant_path}/settlement_batch_summary", :settlement_batch_summary => criteria)
      if response[:settlement_batch_summary]
        SuccessfulResult.new(:settlement_batch_summary => SettlementBatchSummary._new(@gateway, response[:settlement_batch_summary]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :settlement_batch_summary or :api_error_response"
      end
    end

    def _signature
      [:settlement_date, :group_by_custom_field]
    end
  end
end
