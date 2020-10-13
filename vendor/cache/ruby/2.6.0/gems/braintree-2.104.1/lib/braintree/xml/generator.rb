# Portions of this code were copied and modified from Ruby on Rails, released
# under the MIT license, copyright (c) 2005-2009 David Heinemeier Hansson
module Braintree
  module Xml
    module Generator # :nodoc:
      XML_TYPE_NAMES = {
        "Fixnum"     => "integer",
        "Bignum"     => "integer",
        "Integer"    => "integer",
        "TrueClass"  => "boolean",
        "FalseClass" => "boolean",
        "Date"       => "datetime",
        "DateTime"   => "datetime",
        "Time"       => "datetime",
      }

      XML_FORMATTING_NAMES = {
        "BigDecimal" => "bigdecimal",
        "Symbol"     => "symbol"
      }.merge(XML_TYPE_NAMES)

      XML_FORMATTING = {
        "symbol"     => Proc.new { |symbol| symbol.to_s },
        "datetime"   => Proc.new do |date_or_time|
          date_or_time.respond_to?(:xmlschema) ? date_or_time.xmlschema : date_or_time.to_s
        end,
        "bigdecimal" => Proc.new do |bigdecimal|
          str = bigdecimal.to_s('F')
          if str =~ /\.\d$/
            str += "0"
          end
          str
        end
      }

      def self.hash_to_xml(hash)
        root, contents = hash.keys[0], hash.values[0]

        if contents.is_a?(String)
          builder = Builder::XmlMarkup.new
          builder.__send__(_xml_escape(root)) { |b| b.text! contents }
        else
          _convert_to_xml contents, :root => root
        end
      end

      def self._convert_to_xml(hash_to_convert, options = {})
        raise ArgumentError, "need root" unless options[:root]
        options[:indent] ||= 2
        options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
        options[:builder].instruct! unless options.delete(:skip_instruct)
        root = _xml_escape(options[:root])

        options[:builder].__send__(:method_missing, root) do
          hash_to_convert.each do |key, value|
            case value
            when ::Hash
              _convert_to_xml(value, options.merge(:root => key, :skip_instruct => true))
            when ::Array
              _array_to_xml(value, options.merge(:root => key, :skip_instruct => true))
            else
              type_name = XML_TYPE_NAMES[value.class.name]

              attributes = ((value.nil? || type_name.nil?) ? {} : { :type => type_name })
              if value.nil?
                attributes[:nil] = true
              end

							formatting_name = XML_FORMATTING_NAMES[value.class.name]
              options[:builder].tag!(_xml_escape(key),
                XML_FORMATTING[formatting_name] ? XML_FORMATTING[formatting_name].call(value) : value,
                attributes
              )
            end
          end
        end

      end

      def self._array_to_xml(array, options = {})
        raise "expected options[:root]" unless options[:root]
        raise "expected options[:builder]" unless options[:builder]
        options[:indent] ||= 2
        root = options.delete(:root).to_s.tr("_", "-")
        if array.empty?
          options[:builder].tag!(root, :type => "array")
        else
          options[:builder].tag!(root, :type => "array") do
            array.each do |e|
              if e.is_a?(Hash)
                _convert_to_xml(e, options.merge(:root => "item", :skip_instruct => true))
              else
                options[:builder].tag!("item", e)
              end
            end
          end
        end
      end

      def self._xml_escape(key)
        dasherized_key = key.to_s.tr("_", "-")

        if Builder::XChar.respond_to?(:encode)
          Builder::XChar.encode(dasherized_key)
        else
          dasherized_key.to_xs
        end
      end
    end
  end
end
