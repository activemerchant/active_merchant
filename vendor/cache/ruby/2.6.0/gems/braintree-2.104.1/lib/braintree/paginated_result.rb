module Braintree
  class PaginatedResult
    include BaseModule

    attr_reader :current_page
    attr_reader :page_size
    attr_reader :total_items

    def initialize(total_items, page_size, current_page) # :nodoc:
      @total_items = total_items
      @current_page = current_page
      @page_size = page_size
    end
  end
end
