require 'json'

module Hps
	class ExceptionMapper

		attr_reader :exceptions

		def initialize
			path = File.join( File.dirname(__FILE__), "exceptions.json")
			
			File.open(path, "r") do |f|
				@exceptions = JSON.load(f)
			end
		end

		def version_number
			@exceptions["version"]
		end

		def map_issuer_exception(transaction_id, response_code, response_text)

			mapping = exception_for_category_and_code("issuer", response_code)

			unless mapping.nil?
				message = message_for_mapping(mapping, response_text)
				code = mapping["mapping_code"]			
				return CardException.new(transaction_id, code, message)				
			else
				return CardException.new(transaction_id, "unknown_card_exception", response_text)
			end

		end

		def map_gateway_exception(transaction_id, response_code, response_text)

			mapping = exception_for_category_and_code("gateway", response_code)
			message = message_for_mapping(mapping, response_text)
      
			unless mapping.nil?

				code = mapping["mapping_code"]	
				exception_type = mapping["mapping_type"]

				if exception_type == "AuthenticationException"

					return AuthenticationException.new(message)

				elsif exception_type == "CardException"

					return CardException.new(transaction_id, code, message)

				elsif exception_type == "InvalidRequestException"

					return InvalidRequestException.new(message, mapping["param"], code)
				
				elsif !code.nil?

					return HpsException.new(response_text, code)			

				end

			end

			HpsException.new(message, "unknown")
		end

		def map_sdk_exception(error_code, inner_exception = nil)

			mapping = exception_for_category_and_code("sdk", error_code)
			sdk_code_name = SdkCodes.instance_methods.detect { |m| SdkCodes.send(m) == error_code }

			if sdk_code_name.nil?
				response_text = "unknown"
			else
				response_text = sdk_code_name
			end

			unless mapping.nil?

					message = message_for_mapping(mapping, response_text)
					code = mapping["mapping_code"]	
					exception_type = mapping["mapping_type"]	

					if exception_type == "InvalidRequestException"

						return InvalidRequestException.new(message, mapping["param"], code)

					elsif exception_type == "ApiConnectionException"

						return ApiConnectionException.new(message, inner_exception, code)
					
					elsif !code.nil?

						return HpsException.new(message, code)			

					end						

			end

			HpsException.new("unknown", "unknown", inner_exception)

		end

		private

		def message_for_mapping(mapping, original_message)

			return original_message if mapping.nil?

			message = mapping["mapping_message"]

			unless message.nil?

				mapping_message = @exceptions["exception_messages"].detect { |m| 			
					m["code"] == message
				}

				return mapping_message["message"] unless mapping_message["message"].nil?

			end

			original_message

		end

		def exception_for_category_and_code(category, code)

			@exceptions["exception_mappings"].detect { |m| 
				m["category"] == category and m["exception_codes"].include?(code.to_s) 
			}

		end

	end
end