##
# This class manages history for your mechanize object.

class Mechanize::History < Array

  attr_accessor :max_size

  def initialize(max_size = nil)
    @max_size       = max_size
    @history_index  = {}
  end

  def initialize_copy(orig)
    super
    @history_index = orig.instance_variable_get(:@history_index).dup
  end

  def inspect # :nodoc:
    uris = map(&:uri).join ', '

    "[#{uris}]"
  end

  def push(page, uri = nil)
    super page

    index = uri ? uri : page.uri
    @history_index[index.to_s] = page

    shift while length > @max_size if @max_size

    self
  end

  alias :<< :push

  def visited? uri
    page = @history_index[uri.to_s]

    return page if page # HACK

    uri = uri.dup
    uri.path = '/' if uri.path.empty?

    @history_index[uri.to_s]
  end

  alias visited_page visited?

  def clear
    @history_index.clear
    super
  end

  def shift
    return nil if length == 0
    page    = self[0]
    self[0] = nil

    super

    remove_from_index(page)
    page
  end

  def pop
    return nil if length == 0
    page = super
    remove_from_index(page)
    page
  end

  private

  def remove_from_index(page)
    @history_index.each do |k,v|
      @history_index.delete(k) if v == page
    end
  end

end

