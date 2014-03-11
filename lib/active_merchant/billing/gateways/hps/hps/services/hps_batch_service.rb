module Hps
  class HpsBatchService < HpsService
    
    def close_batch()
      
      xml = Builder::XmlMarkup.new
      
      xml.hps :Transaction do
        xml.hps :BatchClose, "BatchClose"
      end
      
      response = doTransaction(xml.target!)
      header = response["Header"]

      unless header["GatewayRspCode"].eql? "0"
        raise @exception_mapper.map_gateway_exception(header["GatewayTxnId"], header["GatewayRspCode"], header["GatewayRspMsg"])
      end

      batch_close = response["Transaction"]["BatchClose"]
      result = HpsBatch.new()
      result.id = batch_close["BatchId"]
      result.sequence_number = batch_close["BatchSeqNbr"]
      result.total_amount = batch_close["TotalAmt"]
      result.transaction_count = batch_close["TxnCnt"]
      
      result
    end
    
  end
end