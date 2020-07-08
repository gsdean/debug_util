require 'test_helper'

class DebugUtilTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::DebugUtil::VERSION
  end

  def test_it_does_something_useful
    assert false
  end

  def test_heap
    before = DebugUtil.heap
    10.times { Array.new(100, 1) }
    after = DebugUtil.heap
    after2 = DebugUtil.heap
    puts before
    puts after
    puts after2
  end

  def test_sample_heap
    DebugUtil.sample_heap(frequency: 1)
    sleep(5)
  end
end
