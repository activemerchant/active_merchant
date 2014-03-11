module Hps
	class HpsChargeService < HpsService

		def get(transaction_id)

			if transaction_id.nil? or transaction_id == 0
				raise @exception_mapper.map_sdk_exception(SdkCodes.invalid_transaction_id) 
			end

      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :ReportTxnDetail do
          xml.hps :TxnId, transaction_id
        end
      end

			response = doTransaction(xml.target!)
      detail = response["Transaction"]["ReportTxnDetail"]
			
			header = hydrate_transaction_header(response["Header"])
			result = HpsReportTransactionDetails.new(header)
			result.transaction_id = detail["GatewayTxnId"]
			result.original_transaction_id = detail["OriginalGatewayTxnId"]
			result.authorized_amount = detail["Data"]["AuthAmt"]
			result.authorization_code = detail["Data"]["AuthCode"]
			result.avs_result_code = detail["Data"]["AVSRsltCode"]
			result.avs_result_text = detail["Data"]["AVSRsltText"]
			result.card_type = detail["Data"]["DardType"]
			result.masked_card_number = detail["Data"]["MaskedCardNbr"]
			result.transaction_type = Hps.service_name_to_transaction_type(detail["ServiceName"])
			result.transaction_date = detail["RspUtcDT"]
			result.cpc_indicator = detail["Data"]["CPCInd"]
			result.cvv_result_code = detail["Data"]["CVVRsltCode"]
			result.cvv_result_text = detail["Data"]["CVVRsltText"]
      result.reference_number = detail["Data"]["RefNbr"]
      result.response_code = detail["Data"]["RspCode"]
      result.response_text = detail["Data"]["RspText"]      

			tokenization_message = detail["Data"]["TokenizationMsg"]

			unless tokenization_message.nil?
				result.token_data = HpsTokenData.new(tokenization_message)
			end

			header_response_code = response["Header"]["GatewayRspCode"]
			data_response_code = detail["Data"]["RspCode"]

			if header_response_code != "0" or data_response_code != "00"

				exceptions = HpsChargeExceptions.new()

				if header_response_code != "0"
					message = response["Header"]["GatewayRspMsg"]
					exceptions.hps_exception = @exception_mapper.map_gateway_exception(result.transaction_id, header_response_code, message)
				end

				if data_response_code != "0"
					message = detail["Data"]["RspText"]
					exceptions.card_exception = @exception_mapper.map_issuer_exception(transaction_id, data_response_code, message)
				end

				result.exceptions = exceptions

			end

			result

		end

		def list(start_date, end_date, filter_by = nil)

			if start_date > DateTime.now
				raise @exception_mapper.map_sdk_exception(SdkCodes.invalid_start_date)
      elsif end_date > DateTime.now
				raise @exception_mapper.map_sdk_exception(SdkCodes.invalid_end_date)				
      end
            
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :ReportActivity do
          xml.hps :RptStartUtcDT, start_date.utc.iso8601
          xml.hps :RptEndUtcDT, end_date.utc.iso8601
        end
      end
      
			response = doTransaction(xml.target!)

			# Gateway exception
			if response["Header"]["GatewayRspCode"] != "0"
				transaction_id = response["Header"]["GatewayTxnId"]
				response_code = response["Header"]["GatewayRspCode"]
				response_message = response["Header"]["GatewayRspMsg"]
				raise @exception_mapper.map_gateway_exception(transaction_id, response_code, response_message)
			end

			result = Array.new

      if response["Transaction"]["ReportActivity"]["Header"]["TxnCnt"] == "0"
        return result
      end

			response["Transaction"]["ReportActivity"]["Details"].each { |charge| 

				next if !filter_by.nil? and charge.serviceName != Hps.transaction_type_to_service_name(filter_by)

				summary = HpsReportTransactionSummary.new()
				summary.transaction_id = charge["GatewayTxnId"]
				summary.original_transaction_id = charge["OriginalGatewayTxnId"]
				summary.masked_card_number = charge["MaskedCardNbr"]
				summary.response_code = charge["IssuerRspCode"]
				summary.response_text = charge["IssuerRspText"]
				summary.transaction_type = Hps.transaction_type_to_service_name(charge["ServiceName"]) if filter_by.nil? == false

				gw_response_code = charge["GatewayRspCode"]
				issuer_response_code = charge["IssuerRspCode"]

				if gw_response_code != "0" or issuer_response_code != "00"

					exceptions = HpsChargeExceptions.new()

					if gw_response_code != "0"
						message = charge["GatewayRspMsg"]
						exceptions.hps_exception = @exception_mapper.map_gateway_exception(charge["GatewayTxnId"], gw_response_code, message)
					end

					if issuer_response_code != "0"
						message = charge["IssuerRspText"]
						exceptions.card_exception = @exception_mapper.map_issuer_exception(charge["GatewayTxnId"], issuer_response_code, message)
					end

					summary.exceptions = exceptions

				end		

				result << summary		
			}
      
			result
		end

		def charge(amount, currency, card, card_holder = nil, request_multi_use_token = false, details = nil)      
      check_amount(amount)
      check_currency(currency)
      
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditSale do
          xml.hps :Block1 do
            xml.hps :AllowDup, "Y"
            xml.hps :Amt, amount          
            xml << hydrate_cardholder_data(card_holder) if card_holder     
            xml << hydrate_additional_txn_fields(details) if details                               
            xml.hps :CardData do
              
              # NOTE: Process as Manual Entry if they gave us a Credit Card
              if card.is_a? HpsCreditCard                    
                xml << hydrate_manual_entry(card)
              # Note: Otherwise, consider it a token
              else
                xml.hps :TokenData do
                  xml.hps :TokenValue, card
                end
              end
              
              xml.hps :TokenRequest, request_multi_use_token ? "Y" : "N"

            end
          end
        end
      end
      
      submit_charge(xml.target!, amount, currency)      
		end

    def verify(card, card_holder = nil, request_multi_use_token = false)
      
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditAccountVerify do
          xml.hps :Block1 do
            xml << hydrate_cardholder_data(card_holder) if card_holder     
            xml.hps :CardData do 
              
              # NOTE: Process as Manual Entry if they gave us a Credit Card
              if card.is_a? HpsCreditCard                    
                xml << hydrate_manual_entry(card)
              # Note: Otherwise, consider it a token
              else
                xml.hps :TokenData do
                  xml.hps :TokenValue, card
                end
              end
              
              xml.hps :TokenRequest, request_multi_use_token ? "Y" : "N"

            end
          end
        end
      end
      
      response = doTransaction(xml.target!)
      header = response["Header"]

      if !header["GatewayRspCode"].eql? "0"
        raise @exception_mapper.map_gateway_exception(header["GatewayTxnId"], header["GatewayRspCode"], header["GatewayRspMsg"])
      end

      account_verify = response["Transaction"]["CreditAccountVerify"]
      result = HpsAccountVerify.new(hydrate_transaction_header(header))
      result.transaction_id = header["GatewayTxnId"]
      result.avs_result_code = account_verify["AVSRsltCode"]
      result.avs_result_text = account_verify["AVSRsltText"]
      result.reference_number = account_verify["RefNbr"]
      result.response_code = account_verify["RspCode"]
      result.response_text = account_verify["RspText"]
      result.card_type = account_verify["CardType"]
      result.cpc_indicator = account_verify["CPCInd"]
      result.cvv_result_code = account_verify["CVVRsltCode"]
      result.cvv_result_text = account_verify["CVVRsltText"]
      result.authorization_code = account_verify["AuthCode"]
      result.authorized_amount = account_verify["AuthAmt"]
      
      if [ "85", "00" ].include? result.response_code == false
        raise @exception_mapper.map_issuer_exception(result.transaction_id, result.response_code, result.response_text)
      end

      unless header["TokenData"].nil?
        result.token_data = HpsTokenData.new()
        result.token_data.response_code = header["TokenData"]["TokenRspCode"];
        result.token_data.response_message = header["TokenData"]["TokenRspMsg"]
        result.token_data.token_value = header["TokenData"]["TokenValue"]
      end

      result      
    end

    def authorize(amount, currency, card, card_holder = nil, request_multi_use_token = false, details = nil)
      
      check_amount(amount)
      check_currency(currency)
      
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditAuth do
          xml.hps :Block1 do
            xml.hps :AllowDup, "Y"
            xml.hps :Amt, amount          
            xml << hydrate_cardholder_data(card_holder) if card_holder  
            xml << hydrate_additional_txn_fields(details) if details                      
            xml.hps :CardData do
              
              # NOTE: Process as Manual Entry if they gave us a Credit Card
              if card.is_a? HpsCreditCard                    
                xml << hydrate_manual_entry(card)
              # Note: Otherwise, consider it a token
              else
                xml.hps :TokenData do
                  xml.hps :TokenValue, card
                end
              end
              
              xml.hps :TokenRequest, request_multi_use_token ? "Y" : "N"              
              
            end
          end
        end
      end
      
      submit_authorize(xml.target!, amount, currency)
    end

    def capture(transaction_id, amount = nil)

      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditAddToBatch do
          xml.hps :GatewayTxnId, transaction_id
          xml.hps :Amt, amount if amount
        end
      end

      response = doTransaction(xml.target!)
      header = response["Header"]

      raise  @exception_mapper.map_gateway_exception(transaction_id, header["GatewayRspCode"], header["GatewayRspMsg"]) unless header["GatewayRspCode"].eql? "0"

      get(transaction_id)
    end

    def reverse(card, amount, currency, details = nil)
      check_amount(amount)
      check_currency(currency)
      
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditReversal do
          xml.hps :Block1 do
            xml.hps :Amt, amount          
            xml << hydrate_additional_txn_fields(details) if details                               
            xml.hps :CardData do
              
              # NOTE: Process as Manual Entry if they gave us a Credit Card
              if card.is_a? HpsCreditCard                    
                xml << hydrate_manual_entry(card)
              # Note: Otherwise, consider it a token
              else
                xml.hps :TokenData do
                  xml.hps :TokenValue, card
                end
              end

            end
          end
        end
      end      
      
      submit_reverse(xml.target!)       
    end
    
    def reverse_transaction(transaction_id, amount, currency, details = nil)      
      check_amount(amount)
      check_currency(currency)
      
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditReversal do
          xml.hps :Block1 do
            xml.hps :Amt, amount  
            xml.hps :GatewayTxnId, transaction_id        
            xml << hydrate_additional_txn_fields(details) if details                               
          end
        end
      end      
      
      submit_reverse(xml.target!)   
    end

    def refund(amount, currency, card, card_holder = nil, details = nil)
      check_amount(amount)
      check_currency(currency)
      
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditReturn do
          xml.hps :Block1 do
            xml.hps :AllowDup, "Y"
            xml.hps :Amt, amount          
            xml << hydrate_cardholder_data(card_holder) if card_holder  
            xml << hydrate_additional_txn_fields(details) if details                      
            xml.hps :CardData do
              
              # NOTE: Process as Manual Entry if they gave us a Credit Card
              if card.is_a? HpsCreditCard                    
                xml << hydrate_manual_entry(card)
              # Note: Otherwise, consider it a token
              else
                xml.hps :TokenData do
                  xml.hps :TokenValue, card
                end
              end
              
            end
          end
        end
      end      
      
      submit_refund(xml.target!)      
    end
    
    def refund_transaction(amount, currency, transaction_id, card_holder = nil, details = nil)
      check_amount(amount)
      check_currency(currency)
      
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditReturn do
          xml.hps :Block1 do
            xml.hps :AllowDup, "Y"
            xml.hps :Amt, amount
            xml.hps :GatewayTxnId, transaction_id
            xml << hydrate_cardholder_data(card_holder) if card_holder  
            xml << hydrate_additional_txn_fields(details) if details                      
          end
        end
      end         
      
      submit_refund(xml.target!)  
    end

    def void(transaction_id)
      xml = Builder::XmlMarkup.new
      xml.hps :Transaction do
        xml.hps :CreditVoid do
          xml.hps :GatewayTxnId, transaction_id
        end
      end

      submit_void(xml.target!)
    end
		private

		def check_amount(amount)			
			raise @exception_mapper.map_sdk_exception(SdkCodes.invalid_amount) if amount.nil? or amount <= 0
		end

		def check_currency(currency)
			raise @exception_mapper.map_sdk_exception(SdkCodes.missing_currency) if currency.empty?
			raise @exception_mapper.map_sdk_exception(SdkCodes.invalid_currency) unless currency.downcase.eql? "usd"
		end
    
    def hydrate_cardholder_data(card_holder)
      xml = Builder::XmlMarkup.new
      xml.hps :CardHolderData do
        xml.hps :CardHolderFirstName, card_holder.first_name
        xml.hps :CardHolderLastName, card_holder.last_name
        xml.hps :CardHolderEmail, card_holder.email_address
        xml.hps :CardHolderPhone, card_holder.phone
        xml.hps :CardHolderAddr, card_holder.address.address
        xml.hps :CardHolderCity, card_holder.address.city
        xml.hps :CardHolderState, card_holder.address.state
        xml.hps :CardHolderZip, card_holder.address.zip
      end
      xml.target!   
    end

    def hydrate_manual_entry(card)
      xml = Builder::XmlMarkup.new
      xml.hps :ManualEntry do
        xml.hps :CardNbr, card.number
        xml.hps :ExpMonth, card.exp_month
        xml.hps :ExpYear, card.exp_year
        xml.hps :CVV2, card.cvv
        xml.hps :CardPresent, "N"
        xml.hps :ReaderPresent, "N"
      end
      xml.target!
    end
    
    def hydrate_additional_txn_fields(details)
      xml = Builder::XmlMarkup.new
      xml.hps :AdditionalTxnFields do
        xml.hps :Description, details.memo if details.memo
        xml.hps :InvoiceNbr, details.invoice_number if details.invoice_number
        xml.hps :CustomerID, details.customer_id if details.customer_id
      end
      xml.target!        
    end
    
    def submit_charge(transaction, amount, currency)
      
      response = doTransaction(transaction)

      header = response["Header"]
      process_charge_gateway_response(header["GatewayRspCode"], header["GatewayRspMsg"], header["GatewayTxnId"], amount, currency)
      
      creditSaleRsp = response["Transaction"]["CreditSale"]
      process_charge_issuer_response(creditSaleRsp["RspCode"], creditSaleRsp["RspText"], header["GatewayTxnId"], amount, currency)  
      
      result = HpsCharge.new(hydrate_transaction_header(header))
      result.transaction_id = header["GatewayTxnId"]
      result.authorized_amount = creditSaleRsp["AuthAmt"]
      result.authorization_code = creditSaleRsp["AuthCode"]
      result.avs_result_code = creditSaleRsp["AVSRsltCode"]
      result.avs_result_text = creditSaleRsp["AVSRsltText"]
      result.card_type = creditSaleRsp["CardType"]
      result.cpc_indicator = creditSaleRsp["CPCInd"]
      result.cvv_result_code = creditSaleRsp["CVVRsltCode"]
      result.cvv_result_text = creditSaleRsp["CVVRsltText"]
      result.reference_number = creditSaleRsp["RefNbr"]
      result.response_code = creditSaleRsp["RspCode"]
      result.response_text = creditSaleRsp["RspText"]
      
      unless header["TokenData"].nil?
        result.token_data = HpsTokenData.new()
        result.token_data.response_code = header["TokenData"]["TokenRspCode"];
        result.token_data.response_message = header["TokenData"]["TokenRspMsg"]
        result.token_data.token_value = header["TokenData"]["TokenValue"]
      end
      
      result
    end
    
    def submit_authorize(transaction, amount, currency)
      
      response = doTransaction(transaction)
      header = response["Header"]
      process_charge_gateway_response(header["GatewayRspCode"], header["GatewayRspMsg"], header["GatewayTxnId"], amount, currency)
      
      auth_response = response["Transaction"]["CreditAuth"]
      process_charge_issuer_response(auth_response["RspCode"], auth_response["RspText"], header["GatewayTxnId"], amount, currency)
      
      result = HpsAuthorization.new(hydrate_transaction_header(header))
      result.transaction_id = header["GatewayTxnId"]
      result.authorized_amount = auth_response["AuthAmt"]
      result.authorization_code = auth_response["AuthCode"]
      result.avs_result_code = auth_response["AVSRsltCode"]
      result.avs_result_text = auth_response["AVSRsltText"]
      result.card_type = auth_response["CardType"]
      result.cpc_indicator = auth_response["CPCInd"]
      result.cvv_result_code = auth_response["CVVRsltCode"]
      result.cvv_result_text = auth_response["CVVRsltText"]
      result.reference_number = auth_response["RefNbr"]
      result.response_code = auth_response["RspCode"]
      result.response_text = auth_response["RspText"]
      
      unless header["TokenData"].nil?
        result.token_data = HpsTokenData.new()
        result.token_data.response_code = header["TokenData"]["TokenRspCode"];
        result.token_data.response_message = header["TokenData"]["TokenRspMsg"]
        result.token_data.token_value = header["TokenData"]["TokenValue"]
      end
      
      result
    end
    
    def submit_refund(transaction)

      response = doTransaction(transaction)
      header = response["Header"]
      
      unless header["GatewayRspCode"].eql? "0"
        raise @exception_mapper.map_gateway_exception(header["GatewayTxnId"], header["GatewayRspCode"], header["GatewayRspMsg"])
      end
      
      result = HpsRefund.new(hydrate_transaction_header(header))
      result.transaction_id = header["GatewayTxnId"]
      result.response_code = "00"
      result.response_text = ""
      
      result
    end
    
    def submit_reverse(transaction)
      
      response = doTransaction(transaction)
      header = response["Header"]
      
      if !header["GatewayRspCode"].eql? "0"
        raise @exception_mapper.map_gateway_exception(header["GatewayTxnId"], header["GatewayRspCode"], header["GatewayRspMsg"])
      end
    
      reversal = response["Transaction"]["CreditReversal"]
      result = HpsReversal.new(hydrate_transaction_header(header))
      result.transaction_id = header["GatewayTxnId"]
      result.avs_result_code = reversal["AVSRsltCode"]
      result.avs_result_text = reversal["AVSRsltText"]
      result.cpc_indicator = reversal["CPCInd"]
      result.cvv_result_code = reversal["CVVRsltCode"]
      result.cvv_result_text = reversal["CVVRsltText"]
      result.reference_number = reversal["RefNbr"]
      result.response_code = reversal["RspCode"]
      result.response_text = reversal["RspText"]
      result
    end

    def submit_void(transaction)
      response = doTransaction(transaction)
      header = response["Header"]

      unless header["GatewayRspCode"].eql? "0"
        raise @exception_mapper.map_gateway_exception(header["GatewayTxnId"], header["GatewayRspCode"], header["GatewayRspMsg"])
      end

      result = HpsVoid.new(hydrate_transaction_header(header))
      result.transaction_id = header["GatewayTxnId"]
      result.response_code = "00"
      result.response_text = ""
      result
    end

    def process_charge_gateway_response(response_code, response_text, transaction_id, amount, currency) 

      if !response_code.eql? "0"
        
        if response_code.eql? "30"
          
          begin
          
            reverse_transaction(transaction_id, amount, currency)
          
          rescue => e
            exception = @exception_mapper.map_sdk_exception(SdkCodes.reversal_error_after_gateway_timeout, e)
            exception.response_code = response_code
            exception.response_text = response_text
            raise exception
          end          
          
        end
        
        exception = @exception_mapper.map_gateway_exception(transaction_id, response_code, response_text)
        exception.response_code = response_code
        exception.response_text = response_text
        raise exception
        
      end
      
    end
    
    def process_charge_issuer_response(response_code, response_text, transaction_id, amount, currency)
      
      if response_code.eql? "91"
        
        begin
          
          reverse_transaction(transaction_id, amount, currency)
          
        rescue => e
          exception = @exception_mapper.map_sdk_exception(SdkCodes.reversal_error_after_issuer_timeout, e)
          exception.response_code = response_code
          exception.response_text = response_text
          raise exception
        end
        
        exception = @exception_mapper.map_sdk_exception(SdkCodes.processing_error)
        exception.response_code = response_code
        exception.response_text = response_text
        raise exception
      
      elsif !response_code.eql? "00"    

        exception = @exception_mapper.map_issuer_exception(transaction_id, response_code, response_text)
        exception.response_code = response_code
        exception.response_text = response_text
        raise exception
          
      end
    
    end
    
	end
  
end