# frozen_string_literal: true

module Interface
  # Barras horizontais: a barra clara é o limite, a escura é o quanto já foi
  # gasto. Sem texto na imagem de propósito — desenhar fonte custa mais do que
  # vale, e os nomes vão na legenda da foto.
  module BarChart
    WIDTH = 720
    ROW_HEIGHT = 56
    BAR_HEIGHT = 30
    MARGIN = 24
    BACKGROUND = [252, 252, 252].freeze
    TRACK = [226, 228, 231].freeze
    OVER = [200, 62, 51].freeze
    NEAR = [214, 158, 46].freeze
    UNDER = [47, 133, 90].freeze
    NO_LIMIT = [110, 120, 132].freeze

    module_function

    # rows: [{ value: Money, limit: Money }] na ordem em que serão legendados.
    def render(rows)
      height = (MARGIN * 2) + (ROW_HEIGHT * [rows.size, 1].max)
      canvas = Canvas.new(width: WIDTH, height: height, background: BACKGROUND)
      span = WIDTH - (MARGIN * 2)

      rows.each_with_index do |row, index|
        top = MARGIN + (index * ROW_HEIGHT)
        canvas.rect(MARGIN, top, span, BAR_HEIGHT, TRACK)
        canvas.rect(MARGIN, top, filled(row, span), BAR_HEIGHT, color(row))
      end

      canvas.to_png
    end

    # Sem limite não há proporção: a barra vira uma marca fixa, só pra registrar
    # que houve gasto.
    def filled(row, span)
      return row[:value].positive? ? span / 8 : 0 if row[:limit].zero?

      [(span * row[:value].cents) / row[:limit].cents, span].min
    end

    def color(row)
      return NO_LIMIT if row[:limit].zero?

      ratio = row[:value].cents * 100 / row[:limit].cents
      return OVER if ratio >= 100
      return NEAR if ratio >= 70

      UNDER
    end
  end
end
