# PecMan

Bot de Telegram, em Ruby, para controle financeiro pessoal: um wizard de setup
no primeiro contato e, depois, lançamento de gastos em texto livre.

O caminho determinístico vem primeiro — regex extrai valor e data, e as
keywords resolvem a categoria. Só quando isso falha é que um LLM local (Qwen
via llama.cpp ou Ollama) é consultado. Cada correção sua vira keyword, então o
bot pergunta menos e responde mais rápido com o tempo.

## Instalação

Esta máquina não tem os headers de `ruby-dev`, e o bundler tenta recompilar
`bigdecimal`/`json` em vez de usar as default gems do Ruby. O `rubygems` resolve
as mesmas dependências sem build nativo:

```sh
gem install --user-install telegram-bot-ruby sequel sqlite3
```

Com `ruby-dev` instalado (`sudo apt install ruby-dev`), `bundle install` também
funciona — o `Gemfile` está no repositório.

## Uso

```sh
cp .env.example .env   # preencha TELEGRAM_TOKEN e ALLOWED_USER_IDS
set -a; source .env; set +a
ruby bot.rb
```

O banco é criado em `data/pecman.db` na primeira execução; as migrations
rodam sozinhas no boot. Backup é copiar esse arquivo.

O `llama-server` precisa estar no ar em `LLAMA_URL` para a interpretação por
LLM. Se estiver fora, o bot cai no parser de regex e continua registrando
gastos.

## Trocar ou adicionar um provedor de IA

O parser de gastos é um port (`Ports::ExpenseParser`). Os
adapters se registram sozinhos, então um provedor novo é **um arquivo**:

```ruby
# lib/shared/infrastructure/llm/groq_expense_parser.rb
module Infrastructure
  module Llm
    class GroqExpenseParser < HttpExpenseParser
      def endpoint = URI.join(base_url, "/openai/v1/chat/completions")
      def payload_for(text, today) = { model: model, messages: [...] }
      def extract(body) = body.dig("choices", 0, "message", "content")

      Registry.register("groq", self)
    end
  end
end
```

`boot.rb` carrega tudo em `lib/shared/infrastructure/llm/`, e `LLM_BACKEND=groq`
passa a valer. Container, casos de uso e testes existentes não mudam.

A classe base cuida do POST, do timeout, do JSON, da conversão para
`ParsedExpense` e de devolver `nil` em qualquer falha — o que aciona o
fallback de regex. Um provedor que não seja HTTP pode implementar o port
direto e registrar do mesmo jeito.

Registrados hoje: `ollama` (padrão) e `llamacpp`.

## Comandos

| Comando | O que faz |
|---|---|
| texto livre | lança um gasto: `35 mercado`, `12,50 uber ontem`, `R$ 89,90 farmácia dia 12` |
| texto com `Nx` | cria um parcelamento: `1200 em 12x notebook`, `12x de 100 cadeira` |
| `/setup` | refaz a configuração (categorias com histórico são preservadas) |
| `/hoje` | gastos do dia |
| `/mes` | resumo do mês, budget por categoria e parcelas do mês |
| `/categoria mercado` | detalhe de uma categoria |
| `/parcelas` | parcelamentos em aberto, com botão para encerrar |
| `/projecao` | quanto sobra por mês até a última parcela, e quando cada meta fecha |
| `/metas` | progresso das reservas |
| `/desfazer` | apaga o último lançamento (janela de 5 min) |

Desistir também funciona em português: `cancela`, `deixa quieto`, `me enganei`.
Dentro do wizard: `/voltar`, `/pular`, `/cancelar`.

## Renda e parcelamento

O setup pergunta se você é PJ ou CLT e ajusta o que vem depois: PJ informa
imposto (percentual sobre a receita), INSS e contadora; CLT informa os
descontos que quiser acompanhar. A renda líquida é derivada, nunca digitada —
mudou a receita, o imposto acompanha.

Parcela é compromisso, não gasto: o plano fica guardado e os relatórios
projetam a partir dele. Nenhum lançamento futuro é criado, então encerrar uma
compra é uma data no plano, e o histórico do que já foi pago continua de pé.
As parcelas formam bloco próprio no `/mes` — não consomem o teto da categoria,
porque a projeção já as desconta separadamente.

## Testes

```sh
rake test
```

## Arquitetura

Vertical slices: cada assunto do bot vive numa pasta, com seu domínio,
casos de uso, presenter e rotas juntos.

```
lib/shared/          o que mais de um slice usa
  domain/            Money, Category, Expense, FinancialPlan, Categorizer...
  ports/             repositórios, ExpenseParser, Clock (interfaces)
  interface/         ViewMessage, Brl, MoneyParser
  infrastructure/    Sequel, llm/, telegram/, clock
  handler.rb         base de slice, com o DSL de rotas
lib/features/
  setup/             wizard, draft, 3 casos de uso, input parser, presenter, rotas
  expense/           lançar, recategorizar, desfazer, presenter, rotas
  installments/      parcelamentos: cadastrar, listar, encerrar
  reports/           /hoje /mes /categoria /metas /projecao, presenter, rotas
  help/              /ajuda
lib/config/          router (percorre os slices) e container (composition root)
```

Adicionar comando mexe em **um slice só**: a rota é declarada dentro dele.

```ruby
class Handler < Shared::Handler
  route "/parcelas", to: :installments
  callback(/\Apay:(\d+)\z/, to: :pay)
  fallback :record          # texto livre que não casou com nenhum comando
end
```

O `Router` não conhece comando nenhum: pergunta a cada slice, em ordem, e
fica com a primeira resposta. O slice de setup usa `intercept` para
segurar a conversa inteira enquanto o wizard está aberto.

`test/config/architecture_test.rb` falha se um slice referenciar outro,
se `shared` referenciar um slice, ou se o domínio importar Sequel.

Os testes de fluxo de cada slice rodam contra repositórios em memória
(`test/support/`); só a suíte de infraestrutura sobe SQLite.
