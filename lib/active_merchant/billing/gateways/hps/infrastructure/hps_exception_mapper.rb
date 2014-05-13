require 'json'

module Hps
	class ExceptionMapper

		attr_reader :exceptions

		def initialize
			path = File.join( File.dirname(__FILE__), 'exceptions.json')
			
			File.open(path, 'r') do |f|
				@exceptions = JSON.load(f)
			end
		end

		def version_number
			@exceptions['version']
		end

		def map_issuer_exception(transaction_id, response_code, response_text)

			mapping = exception_for_category_and_code('issuer', response_code)

			unless mapping.nil?
				message = message_for_mapping(mapping, response_text)
				Exception.new(message)
			else
				Exception.new(message)
			end

		end

		def map_gateway_exception(transaction_id, response_code, response_text)

			mapping = exception_for_category_and_code('gateway', response_code)
			message = message_for_mapping(mapping, response_text)
      
			unless mapping.nil?

				code = mapping['mapping_code']
				exception_type = mapping['mapping_type']

				if exception_type == 'AuthenticationException'

					return Exception.new(message)

				elsif exception_type == 'CardException'

					return Exception.new(message)

				elsif exception_type == 'InvalidRequestException'

					return Exception.new(message)
				
				elsif !code.nil?

					return Exception.new(response_text)

				end

			end

      Exception.new(message)
		end

		def map_sdk_exception(error_code, inner_exception = nil)

			mapping = exception_for_category_and_code('sdk', error_code)
			sdk_code_name = SdkCodes.instance_methods.detect { |m| SdkCodes.send(m) == error_code }

			if sdk_code_name.nil?
				response_text = 'unknown'
			else
				response_text = sdk_code_name
			end

			unless mapping.nil?

					message = message_for_mapping(mapping, response_text)
					code = mapping['mapping_code']
					exception_type = mapping['mapping_type']

					if exception_type == 'InvalidRequestException'

						return Exception.new(message)

					elsif exception_type == 'ApiConnectionException'

						return Exception.new(message)
					
					elsif !code.nil?

						return Exception.new(message)

					end						

			end

      Exception.new('Unknown')

		end

		private

		def message_for_mapping(mapping, original_message)

			return original_message if mapping.nil?

			message = mapping['mapping_message']

			unless message.nil?

				mapping_message = @exceptions['exception_messages'].detect { |m|
					m['code'] == message
				}

				return mapping_message['message'] unless mapping_message['message'].nil?

			end

			original_message

		end

		def exception_for_category_and_code(category, code)

			@exceptions['exception_mappings'].detect { |m|
				m['category'] == category and m['exception_codes'].include?(code.to_s)
			}

		end

	end
end