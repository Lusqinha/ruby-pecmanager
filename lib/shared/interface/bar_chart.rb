# frozen_string_literal: true

module Interface
  # Barras horizontais: a barra clara é o limite, a escura é o quanto já foi
  # gasto. Sem texto na imagem de propósito — desenhar fonte custa mais do que
  # vale, e os nomes vão na legenda da foto.
  module BarChart
    WIDTH = 720
    ROW_HEIGHT = 74
    BAR_HEIGHT = 30
    MARGIN = 24
    BACKGROUND = [252, 252, 252].freeze
    TRACK = [226, 228, 231].freeze
    OVER = [200, 62, 51].freeze
    NEAR = [214, 158, 46].freeze
    UNDER = [47, 133, 90].freeze
    NO_LIMIT = [110, 120, 132].freeze
    LABEL = [58, 64, 74].freeze
    LABEL_SCALE = 2
    MAX_LABEL = 22

    # Quanto mais cheia a barra, pior no gasto e melhor no restante ou no
    # progresso de uma caixinha.
    PALETTES = {
      spending: [UNDER, NEAR, OVER],
      remaining: [OVER, NEAR, UNDER],
      progress: [OVER, NEAR, UNDER]
    }.freeze

    module_function

    # rows: [{ label: String, value: Money, limit: Money }] na ordem legendada.
    def render(rows, palette: :spending)
      height = (MARGIN * 2) + (ROW_HEIGHT * [rows.size, 1].max)
      canvas = Canvas.new(width: WIDTH, height: height, background: BACKGROUND)
      span = WIDTH - (MARGIN * 2)

      rows.each_with_index do |row, index|
        top = MARGIN + (index * ROW_HEIGHT)
        canvas.text(MARGIN, top, label(row[:label]), LABEL, scale: LABEL_SCALE)
        bar_top = top + (Font::HEIGHT * LABEL_SCALE) + 4
        canvas.rect(MARGIN, bar_top, span, BAR_HEIGHT, TRACK)
        canvas.rect(MARGIN, bar_top, filled(row, span), BAR_HEIGHT, color(row, palette))
      end

      canvas.to_png
    end

    # A fonte não tem acento: o nome vai normalizado e cortado no que cabe.
    def label(text)
      Domain::Categorizer.normalize(text).upcase[0, MAX_LABEL].to_s
    end

    # Sem limite não há proporção: a barra vira uma marca fixa, só pra registrar
    # que houve gasto.
    def filled(row, span)
      return row[:value].positive? ? span / 8 : 0 if row[:limit].zero?

      [(span * row[:value].cents) / row[:limit].cents, span].min
    end

    def color(row, palette)
      return NO_LIMIT if row[:limit].zero?

      low, middle, high = PALETTES.fetch(palette)
      ratio = row[:value].cents * 100 / row[:limit].cents
      return high if ratio >= 100
      return middle if ratio >= 70

      low
    end
  end
end
