require 'mechanize/test_case'

class TestMechanizeHistory < Mechanize::TestCase

  def setup
    super

    @uri = URI 'http://example/'
    @uri2 = @uri + '/a'
    @history = Mechanize::History.new
  end

  def test_initialize
    assert_empty @history
  end

  def test_clear
    @history.push :page, @uri

    @history.clear

    assert_empty @history
  end

  def test_pop
    assert_nil @history.pop

    @history.push :page1, @uri
    @history.push :page2, @uri2

    assert_equal :page2, @history.pop
    refute_empty @history
  end

  def test_push
    p1 = page @uri

    obj = @history.push p1

    assert_same @history, obj
    assert_equal 1, @history.length

    p2 = page @uri2

    @history.push p2

    assert_equal 2, @history.length
  end

  def test_push_max_size
    @history = Mechanize::History.new 2

    @history.push :page1, @uri

    assert_equal 1, @history.length

    @history.push :page2, @uri

    assert_equal 2, @history.length

    @history.push :page3, @uri

    assert_equal 2, @history.length
  end

  def test_push_uri
    obj = @history.push :page, @uri

    assert_same @history, obj
    assert_equal 1, @history.length

    @history.push :page2, @uri

    assert_equal 2, @history.length
  end

  def test_shift
    assert_nil @history.shift

    @history.push :page1, @uri
    @history.push :page2, @uri2

    page = @history.shift

    assert_equal :page1, page
    refute_empty @history

    @history.shift

    assert_empty @history
  end

  def test_visited_eh
    refute @history.visited? @uri

    @history.push page @uri

    assert @history.visited? URI('http://example')
    assert @history.visited? URI('http://example/')
  end

end

