module Braintree
  class ValidationErrorCollection
    include Enumerable

    def initialize(data) # :nodoc:
      return if !data.is_a? Hash
      @errors = (data[:errors] || {}).map { |hash| Braintree::ValidationError.new(hash) }
      @nested = {}
      data.keys.each do |key|
        next if key == :errors
        @nested[key] = ValidationErrorCollection.new(data[key])
      end
    end

    # Accesses the error at the given index.
    def [](index)
      @errors[index]
    end

    # Returns an array of ValidationError objects at this level and all nested levels in the error
    # hierarchy
    def deep_errors
      ([@errors] + @nested.values.map { |error_collection| error_collection.deep_errors }).flatten
    end

    def deep_size
      size + @nested.values.inject(0) { |count, error_collection| count + error_collection.deep_size }
    end

    # Iterates over errors at the current level. Nested errors will not be yielded.
    def each(&block)
      @errors.each(&block)
    end

    # Returns a ValidationErrorCollection of errors nested under the given nested_key.
    # Returns nil if there are not any errors nested under the given key.
    def for(nested_key)
      @nested[nested_key]
    end

    def for_index(index)
      self.for("index_#{index}".to_sym)
    end

    def inspect # :nodoc:
      "#<#{self.class} errors#{_inner_inspect}>"
    end

    # Returns an array of ValidationError objects on the given attribute.
    def on(attribute)
      @errors.select { |error| error.attribute == attribute.to_s }
    end

    # Returns an array of ValidationError objects at the given level in the error hierarchy
    def shallow_errors
      @errors.dup
    end

    # The number of errors at this level. This does not include nested errors.
    def size
      @errors.size
    end

    def _inner_inspect(scope = []) # :nodoc:
      all = []
      scope_string = scope.join("/")
      if @errors.any?
        all << "#{scope_string}:[" + @errors.map { |e| "(#{e.code}) #{e.message}" }.join(", ") + "]"
      end
      @nested.each do |key, values|
        all << values._inner_inspect(scope + [key])
      end
      all.join(", ")
    end
  end
end

