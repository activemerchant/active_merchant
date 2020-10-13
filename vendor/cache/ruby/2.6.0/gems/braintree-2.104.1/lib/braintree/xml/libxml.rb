# Portions of this code were copied and modified from Ruby on Rails, released
# under the MIT license, copyright (c) 2005-2009 David Heinemeier Hansson
module Braintree
  module Xml
    module Libxml # :nodoc:
      LIB_XML_LIMIT = 30000000

      def self.parse(xml_string)
        old_keep_blanks_setting = ::LibXML::XML.default_keep_blanks
        ::LibXML::XML.default_keep_blanks = false
        root_node = LibXML::XML::Parser.string(xml_string.strip).parse.root
        _node_to_hash(root_node)
      ensure
        ::LibXML::XML.default_keep_blanks = old_keep_blanks_setting
      end

      def self._node_to_hash(node, hash = {})
        if node.text?
          raise ::LibXML::XML::Error if node.content.length >= LIB_XML_LIMIT
          hash[CONTENT_ROOT] = node.content
        else
          sub_hash = _build_sub_hash(hash, node.name)
          _attributes_to_hash(node, sub_hash)
          if _array?(node)
            _children_array_to_hash(node, sub_hash)
          else
            _children_to_hash(node, sub_hash)
          end
        end
        hash
      end

      def self._build_sub_hash(hash, name)
        sub_hash = {}
        if hash[name]
          if !hash[name].kind_of? Array
            hash[name] = [hash[name]]
          end
          hash[name] << sub_hash
        else
          hash[name] = sub_hash
        end
        sub_hash
      end

      def self._children_to_hash(node, hash={})
        node.each { |child| _node_to_hash(child, hash) }
        _attributes_to_hash(node, hash)
        hash
      end

      def self._attributes_to_hash(node, hash={})
        node.each_attr { |attr| hash[attr.name] = attr.value }
        hash
      end

      def self._children_array_to_hash(node, hash={})
        hash[node.child.name] = node.map do |child|
          _children_to_hash(child, {})
        end
        hash
      end

      def self._array?(node)
        node.child? && node.child.next? && node.child.name == node.child.next.name
      end
    end
  end
end
