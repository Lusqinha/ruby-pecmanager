# frozen_string_literal: true

require "json"

module Features
  module Export
    # O arquivo é para outra ferramenta ler, então tudo o que a conversa deixa
    # implícito — moeda, mês de referência, teto de cada categoria — vai escrito.
    class Presenter
      NOT_READY = "Configuração ainda não concluída. Use /setup."

      def menu
        Interface::ViewMessage.new(
          text: "Exportar os seus dados dos últimos 6 meses para outra ferramenta ler:",
          keyboard: [[["Markdown", "export:md"]], [["JSON", "export:json"]]]
        )
      end

      def json(result)
        return Interface::ViewMessage.text(NOT_READY) unless result.status == :ready

        file(JSON.pretty_generate(result.data), result, "json", "Exportação em JSON.")
      end

      def markdown(result)
        return Interface::ViewMessage.text(NOT_READY) unless result.status == :ready

        file(document(result.data), result, "md", "Exportação em Markdown.")
      end

      private

      def file(body, result, extension, caption)
        Interface::ViewMessage.file(body, filename: "pecman-#{result.generated_on.iso8601}.#{extension}",
                                          caption: caption)
      end

      def document(data)
        [heading(data), income(data[:renda]),
         table("Categorias e budgets", %w[Categoria Teto Gasto Restante Tipo],
               data[:categorias].map { |item| [item[:nome], brl(item[:teto]), brl(item[:gasto_no_mes]),
                                               brl(item[:restante]), item[:tipo_do_teto]] }),
         table("Custos fixos", %w[Nome Mensal Dia Desconto],
               data[:custos_fixos].map { |item| [item[:nome], brl(item[:valor_mensal]), item[:dia],
                                                 item[:desconto_na_folha] ? "sim" : "não"] }),
         table("Assinaturas", %w[Nome Valor Ciclo Mensal Dia],
               data[:assinaturas].map { |item| [item[:nome], brl(item[:valor]), item[:ciclo],
                                                brl(item[:valor_mensal]), item[:dia]] }),
         table("Caixinhas", ["Nome", "Guardado", "Meta", "Falta", "Prazo", "Precisa/mês"],
               data[:caixinhas].map { |item| [item[:nome], brl(item[:guardado]), brl(item[:meta]),
                                              brl(item[:falta]), item[:prazo], brl(item[:precisa_por_mes])] }),
         table("Parcelamentos em aberto", ["Descrição", "Parcela", "Posição", "Último mês"],
               data[:parcelamentos].map { |item| [item[:descricao], brl(item[:parcela]), item[:posicao],
                                                  item[:ultimo_mes]] }),
         table("Lançamentos", ["Data", "Valor", "Descrição", "Categoria"],
               data[:lancamentos].map { |item| [item[:data], brl(item[:valor]), item[:descricao],
                                                item[:categoria] || "sem categoria"] })].compact.join("\n\n")
      end

      def heading(data)
        "# PecManager — exportação\n\nGerado em #{data[:gerado_em]} · mês de referência #{data[:mes_atual]} · " \
          "valores em #{data[:moeda]}"
      end

      def income(renda)
        rows = { "Salário bruto" => renda[:salario_bruto], "Deduções" => renda[:deducoes],
                 "Líquido" => renda[:liquido], "Custos fixos" => renda[:custos_fixos],
                 "Assinaturas" => renda[:assinaturas], "Caixinhas por mês" => renda[:caixinhas_por_mes],
                 "Soma dos budgets" => renda[:budgets], "Disponível para budgets" => renda[:disponivel_para_budgets],
                 "Livre" => renda[:livre] }
        note = renda[:assinaturas_dentro_do_budget] ? "As assinaturas ocupam o budget da categoria Assinaturas." : "As assinaturas saem direto da renda, fora dos budgets."

        table("Renda do mês", %w[Item Valor], rows.map { |name, value| [name, brl(value)] }) + "\n\n#{note}"
      end

      # Tabela vazia vira uma linha honesta em vez de um cabeçalho solto.
      def table(title, headers, rows)
        return "## #{title}\n\n_Nada cadastrado._" if rows.empty?

        ["## #{title}", "",
         "| #{headers.join(' | ')} |",
         "|#{(['---'] * headers.size).join('|')}|",
         *rows.map { |row| "| #{row.map { |cell| cell.to_s.empty? ? '—' : cell }.join(' | ')} |" }].join("\n")
      end

      def brl(value) = format("%.2f", value.to_f)
    end
  end
end
