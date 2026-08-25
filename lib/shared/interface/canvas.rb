# frozen_string_literal: true

require "zlib"

module Interface
  # Bitmap RGB com um retângulo como única primitiva, e saída em PNG.
  #
  # PNG cabe em poucas linhas com a zlib da stdlib, o que evita uma dependência
  # de imagem que compila mal em ARM e mantém os dados do usuário na máquina.
  class Canvas
    SIGNATURE = "\x89PNG\r\n\x1A\n".b
    RGB = 3

    attr_reader :width, :height

    def initialize(width:, height:, background: [255, 255, 255])
      @width = width
      @height = height
      @pixels = (background * width * height).pack("C*")
    end

    def rect(left, top, width, height, color)
      x_range = clamp(left, left + width - 1, @width)
      y_range = clamp(top, top + height - 1, @height)
      return self if x_range.nil? || y_range.nil?

      row = (color * x_range.size).pack("C*")
      y_range.each { |y| @pixels[offset(x_range.first, y), row.bytesize] = row }
      self
    end

    def pixel(x, y) = @pixels[offset(x, y), RGB].unpack("C*")

    def to_png
      SIGNATURE + chunk("IHDR", header) + chunk("IDAT", Zlib::Deflate.deflate(scanlines)) + chunk("IEND", "")
    end

    private

    def offset(x, y) = ((y * @width) + x) * RGB

    def clamp(from, to, limit)
      first = [from, 0].max
      last = [to, limit - 1].min
      first > last ? nil : (first..last)
    end

    # Cada linha vem precedida do byte de filtro; 0 é "sem filtro".
    def scanlines
      (0...@height).map { |y| "\x00".b + @pixels[offset(0, y), @width * RGB] }.join
    end

    # Profundidade 8, cor tipo 2 (RGB), sem entrelaçamento.
    def header = [@width, @height].pack("N2") + [8, 2, 0, 0, 0].pack("C5")

    def chunk(type, body)
      [body.bytesize].pack("N") + type + body + [Zlib.crc32(type + body)].pack("N")
    end
  end
end
