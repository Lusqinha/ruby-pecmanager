# frozen_string_literal: true

module Features
  module Reports
    # Parecer opcional sobre a semana. Manda ao modelo só os números que
    # importam e pede resposta curta: quanto menor a saída, menor a chance de
    # estourar o prazo. Qualquer falha devolve nil e o relatório sai sem ele.
    class WeeklyAdvice
      MAX_LENGTH = 500
      MAX_LINES = 4

      def initialize(advisor:, logger: Infrastructure::Log.for("llm"))
        @advisor = advisor
        @logger = logger
      end

      # O relatório é o produto; o parecer é enfeite. Qualquer falha aqui vira
      # nil, e o rescue mora neste ponto porque é quem faz essa promessa — o
      # adapter pode ser trocado por outro que não trate nada.
      def call(report)
        return nil unless @advisor.respond_to?(:advise)
        return nil if report.lines.empty?

        trim(@advisor.advise(prompt(report)))
      rescue StandardError => e
        @logger&.warn("Parecer descartado: #{e.class}: #{e.message}")
        nil
      end

      private

      # O teto entra como regra dura: realocar mantém a soma, não aumenta o
      # total comprometido.
      def prompt(report)
        <<~TXT.strip
          Você é um consultor financeiro objetivo. Dados do mês, em reais:

          #{table(report)}

          Total dos budgets: #{reais(total(report))} — este total não pode aumentar.
          Faltam #{report.days_left} dias no mês.

          Use apenas os números acima. Não compare com outros meses nem suponha
          dados que não estão aqui.

          Responda em no máximo 3 linhas curtas, sem saudação:
          1. Uma sugestão de realocação entre duas categorias, mantendo a soma igual.
          2. Um comentário sobre os gastos desta semana.
        TXT
      end

      def table(report)
        report.lines.map do |line|
          "#{line.category_name}: teto #{reais(line.limit)}, gasto #{reais(line.spent)}, " \
            "semana #{reais(line.week)}"
        end.join("\n")
      end

      def total(report) = report.lines.reduce(Domain::Money.zero) { |sum, line| sum + line.limit }

      def reais(money) = format("%.2f", money.cents / 100.0)

      # Modelo pequeno às vezes se alonga: corta no que cabe numa mensagem.
      def trim(text)
        return nil if text.nil? || text.strip.empty?

        text.strip.lines.first(MAX_LINES).join.strip[0, MAX_LENGTH]
      end
    end
  end
end
