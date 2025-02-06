require 'thor/group'

class CardTypeGenerator < Thor::Group
  include Thor::Actions

  argument :card_type, type: :string, desc: "The name of the card type to add"
  class_option :gateways, type: :array, desc: "List of gateway names to update (optional)", default: nil

  def self.source_root
    File.dirname(__FILE__)
  end

  def add_card_type_to_gateways
    gateway_dir = "lib/active_merchant/billing/gateways"
    test_dir = "test/unit/gateways"

    gateways_to_update = if options[:gateways]
      options[:gateways].map { |g| "#{gateway_dir}/#{g}.rb" }
    else
      Dir.glob("#{gateway_dir}/*.rb")
    end

    gateways_to_update.each do |gateway_path|
      next unless File.exist?(gateway_path)

      gateway_name = File.basename(gateway_path, ".rb")
      test_path = "#{test_dir}/#{gateway_name}_test.rb"

      if File.exist?(test_path)
        update_gateway_file(gateway_path, card_type)
        update_test_file(test_path, card_type)
        say_status :update, "Added #{card_type} to #{gateway_name}", :green
      else
        say_status :skip, "Test file not found for #{gateway_name}", :yellow
      end
    end
  end

  private

  def update_gateway_file(path, new_card_type)
    content = File.read(path)
    # This method updates the supported_cardtypes array in a gateway file
    # It uses regex to find the line that defines supported_cardtypes, e.g:
    #   self.supported_cardtypes = %i[visa mastercard amex]
    # The regex captures 3 groups:
    # $1 = "self.supported_cardtypes = %i["
    # $2 = the current card types (e.g. "visa mastercard amex")
    # $3 = "]"
    updated_content = content.gsub(/(self\.supported_cardtypes\s*=\s*%i\[)(.*?)(\])/m) do
      current_types = $2.strip
      return if current_types.include?(new_card_type)
      "#{$1}#{current_types.empty? ? new_card_type : "#{current_types} #{new_card_type}"}#{$3}"
    end
    File.write(path, updated_content)
  end

  def update_test_file(path, new_card_type)
    content = File.read(path)

    # This method updates the supported_cardtypes array in a test file
    # It uses regex to find the line that defines test_supported_cardtypes or test_supported_cardtypes
    pattern1 = /(def\s+test_supported_card_types.*?assert_equal\s+.*?supported_cardtypes,\s*%i\[)(.*?)(\])/m
    pattern2 = /(def\s+test_supported_cardtypes.*?assert_equal\s*%i\[)(.*?)(\])/m

    if content.match?(pattern1)
      updated_content = content.gsub(pattern1) do
        current_types = $2.strip
        return if current_types.include?(new_card_type)
        "#{$1}#{current_types.empty? ? new_card_type : "#{current_types} #{new_card_type}"}#{$3}"
      end
    elsif content.match?(pattern2)
      updated_content = content.gsub(pattern2) do
        current_types = $2.strip
        return if current_types.include?(new_card_type)
        "#{$1}#{current_types.empty? ? new_card_type : "#{current_types} #{new_card_type}"}#{$3}"
      end
    end

    File.write(path, updated_content) unless updated_content.nil?
  end
end
