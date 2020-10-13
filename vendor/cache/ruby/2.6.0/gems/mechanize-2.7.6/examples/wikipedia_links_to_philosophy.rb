require 'mechanize'
require 'tsort'

##
# This example implements the alt-text of http://xkcd.com/903/ which states:
#
# Wikipedia trivia: if you take any article, click on the first link in the
# article text not in parentheses or italics, and then repeat, you will
# eventually end up at "Philosophy".

class WikipediaLinksToPhilosophy

  def initialize
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Mac Safari' # Wikipedia blocks "mechanize"

    @history = @agent.history

    @wiki_url = URI 'http://en.wikipedia.org'
    @search_url = @wiki_url + '/w/index.php'
    @random_url = @wiki_url + '/wiki/Special:Random'

    @title = nil
    @seen = nil
  end

  ##
  # Retrieves the title of the current page

  def extract_title
    @page.title =~ /(.*) - Wikipedia/

    @title = $1
  end

  ##
  # Retrieves the initial page.  If +query+ is not given a random page is
  # chosen

  def fetch_first_page query
    if query then
      search query
    else
      random
    end
  end

  ##
  # The search is finished if we've seen the page before or we've reached
  # Philosophy

  def finished?
    @seen or @title == 'Philosophy'
  end

  ##
  # Follows the first non-parenthetical, non-italic link in the main body of
  # the article.

  def follow_first_link
    puts @title

    # > p > a rejects italics
    links = @page.root.css('.mw-content-ltr > p > a[href^="/wiki/"]')

    # reject disambiguation and special pages, images and files
    links = links.reject do |link_node|
      link_node['href'] =~ %r%/wiki/\w+:|\(disambiguation\)%
    end

    links = links.reject do |link_node|
      in_parenthetical? link_node
    end

    link = links.first

    unless link then
      # disambiguation page? try the first item in the list
      link =
        @page.root.css('.mw-content-ltr > ul > li > a[href^="/wiki/"]').first
    end

    # convert a Nokogiri HTML element back to a mechanize link
    link = Mechanize::Page::Link.new link, @agent, @page

    return if @seen = @agent.visited?(link)

    @page = link.click

    extract_title
  end

  ##
  # Is +link_node+ in an open parenthetical section?

  def in_parenthetical? link_node
    siblings = link_node.parent.children

    seen = false

    before = siblings.reject do |node|
      seen or (seen = node == link_node)
    end

    preceding_text = before.map { |node| node.text }.join

    open  = preceding_text.count '('
    close = preceding_text.count ')'

    open > close
  end

  ##
  # Prints the result of the search

  def print_result
    if @seen then
      puts "[Loop detected]"
    else
      puts @title
    end
    puts
    # subtract initial search or Special:Random
    puts "After #{@agent.history.length - 1} pages"
  end

  ##
  # Retrieves a random page from wikipedia

  def random
    @page = @agent.get @random_url

    extract_title
  end

  ##
  # Entry point

  def run query = nil
    fetch_first_page query

    follow_first_link until finished?

    print_result
  end

  ##
  # Searches for +query+ on wikipedia

  def search query
    @page = @agent.get @search_url, search: query

    extract_title
  end

end

WikipediaLinksToPhilosophy.new.run ARGV.shift if $0 == __FILE__

