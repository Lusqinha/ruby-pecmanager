# frozen_string_literal: true

module Features
  module Help
    class Presenter
      def call
        Interface::ViewMessage.text(<<~TXT)
          Envie o gasto em texto livre: `35 mercado`, `12,50 uber ontem`, `R$ 89,90 farmácia dia 12`.
          Para parcelamento: `1200 em 12x notebook` ou `12x de 100 notebook`.

          *Comandos*
          /hoje — o que saiu hoje
          /mes — resumo do mês, com o que guardar nas caixinhas
          /mes out/26 — qualquer mês, inclusive os futuros
          /grafico — gráficos: categorias, mês a mês, caixinhas e acumulado
          /categoria mercado — detalhe de uma categoria
          /budgets — tetos de cada categoria e quanto sobra
          /budget mercado 500 — muda o teto (aceita `10%` e `livre`)
          /caixinhas — saldo de cada caixinha
          /caixinha viagem 200 — guarda numa caixinha (valor negativo retira)
          /parcelas — parcelamentos em aberto
          /importar_parcelas — cadastrar parcelas do cartão por JSON
          /importar_gastos — lançar vários gastos por JSON
          /projecao — quanto sobra por mês, com gráfico do acumulado
          /exportar — baixa seus dados em Markdown ou JSON
          /desfazer — apaga o último lançamento (5 min)
          /setup — refaz a configuração
          /reverter 30 — desfaz o que entrou nos últimos 30 min
          /apagar_tudo — apaga tudo e recomeça

          Também aceito linguagem corrente: `cancela`, `deixa quieto` e `me enganei` desfazem o último lançamento.
        TXT
      end
    end
  end
end
