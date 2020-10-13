# Portions of this code were copied and modified from Ruby on Rails, released
# under the MIT license, copyright (c) 2005-2009 David Heinemeier Hansson
module Braintree
  module Xml # :nodoc:
    module Rexml # :nodoc:

      CONTENT_KEY = '__content__'.freeze

      def self.parse(string)
        require 'rexml/document' unless defined?(REXML::Document)
        doc = REXML::Document.new(string)
        _merge_element!({}, doc.root)
      end

      def self._merge_element!(hash, element)
        _merge!(hash, element.name, _collapse(element))
      end

      def self._collapse(element)
        hash = _get_attributes(element)

        if element.has_elements?
          element.each_element {|child| _merge_element!(hash, child) }
          _merge_texts!(hash, element) unless _empty_content?(element)
          hash
        else
          _merge_texts!(hash, element)
        end
      end

      def self._merge_texts!(hash, element)
        unless element.has_text?
          hash
        else
          # must use value to prevent double-escaping
          _merge!(
            hash,
            CONTENT_KEY,
            element.texts.map { |t| t.value}.join
          )
        end
      end

      def self._merge!(hash, key, value)
        if hash.has_key?(key)
          if hash[key].instance_of?(Array)
            hash[key] << value
          else
            hash[key] = [hash[key], value]
          end
        elsif value.instance_of?(Array)
          hash[key] = [value]
        else
          hash[key] = value
        end
        hash
      end

      def self._get_attributes(element)
        attributes = {}
        element.attributes.each { |n,v| attributes[n] = v }
        attributes
      end

      def self._empty_content?(element)
        element.texts.join.strip == ""
      end
    end
  end
end

