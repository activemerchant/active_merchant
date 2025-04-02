require 'nokogiri'

module ActiveMerchant
  module XMLValidate
    def self.validate_with_xsd_path(xml, options, xsd_path:)
      xsd = Nokogiri::XML::Schema(File.read(xsd_path))
      doc = Nokogiri::XML(xml)

      errors = xsd.validate(doc)
      if errors.empty?
        true
      else
        puts(errors.map(&:message))
        errors.map(&:message)
      end
    end
  end
end
