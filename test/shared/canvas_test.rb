# frozen_string_literal: true

require_relative "../test_helper"

class CanvasTest < Minitest::Test
  Canvas = Interface::Canvas

  def test_writes_a_png_that_declares_its_own_size
    png = Canvas.new(width: 40, height: 20).to_png

    assert_equal "\x89PNG\r\n\x1A\n".b, png[0, 8]
    assert_equal "IHDR", png[12, 4]
    assert_equal 40, png[16, 4].unpack1("N")
    assert_equal 20, png[20, 4].unpack1("N")
    assert_equal "IEND", png[-8, 4]
  end

  def test_every_chunk_carries_a_valid_crc
    png = Canvas.new(width: 8, height: 8).to_png
    offset = 8

    while offset < png.bytesize
      length = png[offset, 4].unpack1("N")
      type = png[offset + 4, 4]
      body = png[offset + 8, length]
      crc = png[offset + 8 + length, 4].unpack1("N")

      assert_equal Zlib.crc32(type + body), crc, "CRC inválido no chunk #{type}"
      offset += 12 + length
    end
  end

  def test_a_filled_rectangle_lands_where_it_was_asked
    canvas = Canvas.new(width: 4, height: 4, background: [255, 255, 255])
    canvas.rect(1, 1, 2, 2, [10, 20, 30])

    assert_equal [10, 20, 30], canvas.pixel(1, 1)
    assert_equal [10, 20, 30], canvas.pixel(2, 2)
    assert_equal [255, 255, 255], canvas.pixel(0, 0)
    assert_equal [255, 255, 255], canvas.pixel(3, 3)
  end

  def test_drawing_outside_the_canvas_is_ignored
    canvas = Canvas.new(width: 4, height: 4)
    canvas.rect(-5, -5, 20, 20, [1, 2, 3])

    assert_equal [1, 2, 3], canvas.pixel(0, 0)
    assert_equal [1, 2, 3], canvas.pixel(3, 3)
  end
end
