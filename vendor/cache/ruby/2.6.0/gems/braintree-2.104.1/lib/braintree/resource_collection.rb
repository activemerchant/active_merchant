module Braintree
  class ResourceCollection # :nodoc:
    include Enumerable

    attr_reader :ids

    def initialize(response, &block) # :nodoc:
      @ids = Util.extract_attribute_as_array(response[:search_results], :ids)
      @page_size = response[:search_results][:page_size]
      @paging_block = block
    end

    # Yields each item
    def each(&block)
      @ids.each_slice(@page_size) do |page_of_ids|
        resources = @paging_block.call(page_of_ids)
        resources.each(&block)
      end
    end

    def empty?
      @ids.empty?
    end

    # Returns the first item in the collection or nil if the collection is empty
    def first
      @paging_block.call([@ids.first]).first
    end

    # Only the maximum size of a resource collection can be determined since the data on the server can change while
    # fetching blocks of results for iteration.  For example, customers can be deleted while iterating, so the number
    # of results iterated over may be less than the maximum_size.  In general, this method should be avoided.
    def maximum_size
      @ids.size
    end
  end
end
