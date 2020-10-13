module Mechanize::ElementMatcher

  def elements_with singular, plural = "#{singular}s"
    class_eval <<-CODE
      def #{plural}_with criteria = {}
        selector = method = nil
        if String === criteria then
          criteria = {:name => criteria}
        else
          criteria = criteria.each_with_object({}) { |(k, v), h|
            case k = k.to_sym
            when :id
              h[:dom_id] = v
            when :class
              h[:dom_class] = v
            when :search, :xpath, :css
              if v
                if method
                  warn "multiple search selectors are given; previous selector (\#{method}: \#{selector.inspect}) is ignored."
                end
                selector = v
                method = k
              end
            else
              h[k] = v
            end
          }
        end

        f = select_#{plural}(selector, method).find_all do |thing|
          criteria.all? do |k,v|
            v === thing.__send__(k)
          end
        end
        yield f if block_given?
        f
      end

      def #{singular}_with criteria = {}
        f = #{plural}_with(criteria).first
        yield f if block_given?
        f
      end

      def #{singular}_with! criteria = {}
        f = #{singular}_with(criteria)
        raise Mechanize::ElementNotFoundError.new(self, :#{singular}, criteria) if f.nil?
        yield f if block_given?
        f
      end

      def select_#{plural} selector, method = :search
        if selector.nil? then
          #{plural}
        else
          nodes = __send__(method, selector)
          #{plural}.find_all do |element|
            nodes.include?(element.node)
          end
        end
      end

      alias :#{singular} :#{singular}_with
    CODE
  end

end

