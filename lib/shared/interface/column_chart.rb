# frozen_string_literal: true

module Interface
  # Colunas verticais para série temporal: uma coluna por mês, altura
  # proporcional ao maior valor da série. Os rótulos vão na legenda da foto.
  module ColumnChart
    WIDTH = 720
    HEIGHT = 320
    MARGIN = 24
    GAP = 8
    LABEL_BAND = 26
    LABEL = [90, 98, 110].freeze
    BACKGROUND = [252, 252, 252].freeze
    BAR = [47, 106, 152].freeze
    CURRENT = [214, 158, 46].freeze
    BASELINE = [210, 213, 217].freeze

    module_function

    # values: [Money] em ordem cronológica; a última é o mês corrente.
    # labels: texto sob cada coluna, como "08/26".
    def render(values, labels: [])
      canvas = Canvas.new(width: WIDTH, height: HEIGHT, background: BACKGROUND)
      return canvas.to_png if values.empty?

      span = WIDTH - (MARGIN * 2)
      floor = HEIGHT - MARGIN - LABEL_BAND
      width = [(span - (GAP * (values.size - 1))) / values.size, 1].max
      top = ceiling(values)

      values.each_with_index do |value, index|
        height = [(floor - MARGIN) * value.cents / top, 1].max
        left = MARGIN + (index * (width + GAP))
        canvas.rect(left, floor - height, width, height, index == values.size - 1 ? CURRENT : BAR)
        label(canvas, labels[index], left, floor, width)
      end

      canvas.rect(MARGIN, floor, span, 2, BASELINE)
      canvas.to_png
    end

    # Centralizado na coluna, e a escala cai se o texto não couber.
    def label(canvas, text, left, floor, width)
      return if text.to_s.empty?

      scale = Font.width(text, 2) <= width ? 2 : 1
      offset = [(width - Font.width(text, scale)) / 2, 0].max
      canvas.text(left + offset, floor + 8, text, LABEL, scale: scale)
    end

    # Escala pelo maior mês; série toda zerada não divide por zero.
    def ceiling(values) = [values.map(&:cents).max, 1].max
  end
end
