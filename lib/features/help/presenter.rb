# frozen_string_literal: true

module Features
  module Help
    class Presenter
      def call
        Interface::ViewMessage.text(<<~TXT)
          Manda o gasto em texto livre: `35 mercado`, `12,50 uber ontem`, `R$ 89,90 farmácia dia 12`.
Parcelou? `1200 em 12x notebook` ou `12x de 100 notebook`.

          *Comandos*
          /hoje — o que saiu hoje
          /mes — resumo do mês com budgets
          /categoria mercado — detalhe de uma categoria
          /metas — progresso das reservas
          /parcelas — parcelamentos em aberto
          /importar_parcelas — cadastrar parcelas do cartão por JSON
          /importar_gastos — lançar vários gastos por JSON
          /projecao — quanto sobra por mês até a última parcela
          /desfazer — apaga o último lançamento (5 min)
          /setup — refaz a configuração

          Ou escreve como fala: `cancela`, `deixa quieto`, `me enganei` desfazem a última coisa.
        TXT
      end
    end
  end
end
