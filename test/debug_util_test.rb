require 'test_helper'

class DebugUtilTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::DebugUtil::VERSION
  end

  def test_it_does_something_useful
    assert false
  end

  def test_memory
    before = DebugUtil.memory
    10.times { Array.new(100, 1) }
    after = DebugUtil.memory
    after2 = DebugUtil.memory
    puts before
    puts after
    puts after2
  end
end
