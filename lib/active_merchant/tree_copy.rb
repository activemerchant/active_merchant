module ActiveMerchant
  module TreeCopy
    private

    def copy_paths(source, dest, paths)
      paths.each do |path|
        copy_when_present(source, path.source_path, dest, path.dest_path, path.default)
      end
    end

    def copy_snake_paths(source, dest, paths)
      tree_paths = paths.map do |path|
        tree_path(path.map { |entry| camel_to_snake(entry) }, path)
      end
      copy_paths(source, dest, tree_paths)
    end

    def tree_path(source_path, dest_path = nil, default: nil)
      dest_path ||= source_path
      TreeCopyPath.new(source_path: source_path, dest_path: dest_path, default: default)
    end

    def copy_when_present(source, source_path, dest, dest_path, default)
      source_path.each do |key|
        return nil unless source[key] || default
        source = source[key]
      end

      source ||= default
      if source
        dest_path.first(dest_path.size - 1).each do |key|
          dest[key] ||= {}
          dest = dest[key]
        end
        dest[dest_path.last] = source
      end
    end

    def camel_to_snake(sym)
      sym.
        to_s.
        gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr('-', '_').
        downcase.
        to_sym
    end
  end

  class TreeCopyPath
    attr_reader :source_path, :dest_path, :default

    def initialize(source_path: nil, dest_path:, default:)
      @dest_path = dest_path
      @source_path = source_path || dest_path
      @default = default
    end
  end
end
