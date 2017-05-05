module MercuryHelper
  module BatchClosing
    def close_batch
      xml = Builder::XmlMarkup.new
      xml.tag! "TStream" do
        xml.tag! "Admin" do
          xml.tag! 'MerchantID', @options[:login]
          xml.tag! 'TranCode', "BatchSummary"
        end
      end
      xml = xml.target!
      response = commit("BatchSummary", xml)

      xml = Builder::XmlMarkup.new
      xml.tag! "TStream" do
        xml.tag! "Admin" do
          xml.tag! 'MerchantID', @options[:login]
          xml.tag! 'OperatorID', response.params["operator_id"]
          xml.tag! 'TranCode', "BatchClose"
          xml.tag! 'BatchNo', response.params["batch_no"]
          xml.tag! 'BatchItemCount', response.params["batch_item_count"]
          xml.tag! 'NetBatchTotal', response.params["net_batch_total"]
          xml.tag! 'CreditPurchaseCount', response.params["credit_purchase_count"]
          xml.tag! 'CreditPurchaseAmount', response.params["credit_purchase_amount"]
          xml.tag! 'CreditReturnCount', response.params["credit_return_count"]
          xml.tag! 'CreditReturnAmount', response.params["credit_return_amount"]
          xml.tag! 'DebitPurchaseCount', response.params["debit_purchase_count"]
          xml.tag! 'DebitPurchaseAmount', response.params["debit_purchase_amount"]
          xml.tag! 'DebitReturnCount', response.params["debit_return_count"]
          xml.tag! 'DebitReturnAmount', response.params["debit_return_amount"]
        end
      end
      xml = xml.target!
      commit("BatchClose", xml)
    end

    def hashify_xml!(xml, response)
      super

      doc = REXML::Document.new(xml)
      doc.elements.each("//BatchSummary/*") do |node|
        response[node.name.underscore.to_sym] = node.text
      end
    end
  end

  private

  def close_batch(gateway=@gateway)
    gateway = ActiveMerchant::Billing::MercuryGateway.new(gateway.options)
    gateway.extend(BatchClosing)
    gateway.close_batch
  end
end
