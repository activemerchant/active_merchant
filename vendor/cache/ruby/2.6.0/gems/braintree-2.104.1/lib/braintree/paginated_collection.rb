module Braintree
  class PaginatedCollection # :nodoc:
    include Enumerable

    def initialize(&block) # :nodoc:
      @next_page_block = block
    end

    def each(&block)
      current_page = 0
      total_items = 0

      loop do
        current_page += 1

        result = @next_page_block.call(current_page)
        total_items = result.total_items

        result.current_page.each(&block)

        break if current_page * result.page_size >= total_items
      end
    end
  end
end
