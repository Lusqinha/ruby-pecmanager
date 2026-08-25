# frozen_string_literal: true

module Features
  module Imports
    class Presenter
      ERRORS = {
        invalid_json: "JSON inválido. Verifique se copiou o bloco completo, de `{` até `}`.",
        empty: "O JSON veio sem lançamentos.",
        invalid_item: "Há linha sem `data`, `descricao` ou `valor`, ou com valor zerado. " \
                      "Data no formato `AAAA-MM-DD`.",
        mixed: "Este lote mistura gasto avulso com parcelamento. Separe em dois arquivos: " \
               "um para /importar_gastos e outro para /importar_parcelas."
      }.freeze

      def instructions(kind, categories)
        Interface::ViewMessage.text(
          "#{header(kind)}\n\n" \
          "Envie o JSON no chat ou anexe o arquivo `.json`. Para gerar, use este prompt em uma IA, " \
          "junto com a fatura:\n\n```\n#{prompt(kind, categories)}\n```"
        )
      end

      def call(result)
        case result.status
        when :prepared then prepared(result)
        when :recorded then recorded(result)
        when :all_duplicated then Interface::ViewMessage.text("Todos os itens deste lote já estavam lançados.")
        when :nothing_pending then Interface::ViewMessage.text("Nenhuma importação aguardando confirmação.")
        when :discarded then Interface::ViewMessage.text("Importação descartada.")
        when :invalid then invalid(result)
        end
      end

      private

      def header(kind)
        return "*Importar parcelamentos*" if kind == :installments

        "*Importar gastos avulsos*"
      end

      def invalid(result)
        return Interface::ViewMessage.text(ERRORS[:mixed]) if result.error == :mixed
        return Interface::ViewMessage.text(wrong_kind(result.kind)) if result.error == :wrong_kind

        Interface::ViewMessage.text(ERRORS.fetch(result.error, ERRORS[:invalid_item]))
      end

      def wrong_kind(kind)
        return "Este JSON é de parcelamento. Use /importar_parcelas." if kind == :installments

        "Este JSON é de gasto avulso. Use /importar_gastos."
      end

      def prepared(result)
        lines = ["*Revise antes de gravar:*", ""]
        lines += result.items.first(15).map { |item| item_line(item) }
        lines << "_...e mais #{result.items.size - 15}._" if result.items.size > 15
        lines << ""
        lines << "#{result.items.size} #{result.kind == :installments ? 'parcelamento(s)' : 'gasto(s)'}" \
                 "#{duplicates(result)}."
        lines += ["", "Estas parcelas devem consumir o budget das categorias?"] if result.kind == :installments

        Interface::ViewMessage.new(text: lines.join("\n"), keyboard: buttons(result.kind))
      end

      # A pergunta cai aqui, antes de qualquer categorização: fora do budget o
      # bot nem tenta adivinhar categoria pras parcelas.
      def buttons(kind)
        return [[["Confirmar", "import:ok"], ["Descartar", "import:no"]]] unless kind == :installments

        [[["Contar no budget", "import:budget"], ["Fora do budget", "import:free"]],
         [["Descartar", "import:no"]]]
      end

      def item_line(item)
        return "· #{item.description} · #{Interface::Brl.format(item.amount)} · #{item.date.strftime('%d/%m')}" unless item.installment?

        "· #{item.description} #{item.number}/#{item.count} · #{Interface::Brl.format(item.amount)}/mês · " \
          "começou em #{item.first_month.strftime('%m/%Y')}"
      end

      def duplicates(result)
        count = result.duplicates.to_a.size
        count.zero? ? "" : ", #{count} já existia(m) e ficou(aram) de fora"
      end

      def recorded(result)
        Interface::ViewMessage.text("✅ #{result.recorded} lançado(s).#{budget_note(result)}#{pending(result)}")
      end

      def budget_note(result)
        return "" if result.in_budget.nil?

        result.in_budget ? " Passam a consumir o budget das categorias." : " Ficam fora do budget, em bloco próprio."
      end

      def pending(result)
        count = result.uncategorized.to_i
        count.positive? ? " #{count} sem categoria; aparecem assim no /mes." : ""
      end

      # As categorias e as keywords aprendidas vão no prompt: sem isso a IA
      # externa chuta no vácuo, com isso ela escolhe da lista real.
      def prompt(kind, categories)
        <<~TXT.strip
          Converta esta fatura em JSON. Responda só o JSON, sem comentários.

          #{shape(kind)}

          Regras:
          - valor: #{kind == :installments ? 'o da parcela do mês' : 'o do lançamento'}, vírgula decimal, sem "R$"
          #{rules(kind)}
          - ignore pagamentos, estornos e créditos (valores negativos)
          - não invente nenhuma linha
          - categoria: escolha uma da lista abaixo, ou omita o campo se não souber

          Categorias:
          #{category_list(categories)}

          Fatura:
        TXT
      end

      def shape(kind)
        return <<~TXT.strip if kind == :installments
          {"fonte":"NOME DO BANCO","lancamentos":[
            {"data":"AAAA-MM-DD","descricao":"...","valor":"0,00","parcela":1,"parcelas":12,"categoria":"..."}
          ]}
        TXT

        <<~TXT.strip
          {"fonte":"NOME DO BANCO","lancamentos":[
            {"data":"AAAA-MM-DD","descricao":"...","valor":"0,00","categoria":"..."}
          ]}
        TXT
      end

      def rules(kind)
        return "- inclua SÓ linhas parceladas; a marcação (\"Loja - Parcela 3/12\") vira parcela e parcelas, " \
               "e sai da descricao" if kind == :installments

        "- inclua SÓ linhas não parceladas; se a descrição tiver \"3/12\" ou \"Parcela 3/12\", pule a linha"
      end

      def category_list(categories)
        categories.map do |category|
          examples = category.keywords.first(6)
          examples.empty? ? "- #{category.name}" : "- #{category.name}: #{examples.join(', ')}"
        end.join("\n")
      end
    end
  end
end
