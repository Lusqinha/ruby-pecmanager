# PecMan

Bot de Telegram pra controle de gastos. Ruby, SQLite.

## Setup

```sh
bundle install
cp .env.example .env    # TELEGRAM_TOKEN e ALLOWED_USER_IDS
set -a; source .env; set +a
ruby bot.rb
```

Banco em `data/pecman.db`, criado no primeiro boot.

`bundle install` falhando em `bigdecimal`/`json`: falta `ruby-dev`, ou usa
`gem install --user-install telegram-bot-ruby sequel sqlite3`.

Pro parser por LLM, `llama-server` ou Ollama no ar em `LLAMA_URL`. Sem isso o
bot usa só o regex.

## Contribuindo

```sh
rake test
```

Branches no modelo gitflow: `main` guarda release, `develop` é a base do dia a
dia, trabalho novo sai em `feature/<nome>` e volta pra `develop`. Correção
urgente em produção sai de `main` como `hotfix/<nome>`.

Commits no padrão conventional commits:

```
feat(installments): aceita mes por extenso no cadastro
fix(imports): valor do lote pendente relido como reais
refactor(reports): extrai calculo de projecao
test(setup): cobre wizard PJ
docs: atualiza readme
chore: ajusta gitignore
```

Escopo é o slice (`setup`, `expense`, `installments`, `reports`, `imports`) ou
vazio quando a mudança é transversal.

Código em vertical slices: `lib/features/<assunto>/` com domínio, casos de uso,
presenter e rotas juntos. `lib/shared/` é o que mais de um slice usa.

Rota nova fica dentro do slice:

```ruby
class Handler < Shared::Handler
  route "/parcelas", to: :list
  callback(/\Aplan:cancel:(\d+)\z/, to: :cancel)
end
```

Slice novo entra no router em `lib/config/container.rb`.

`rake test` roda `test/config/architecture_test.rb`, que quebra se um slice
importar outro ou se o domínio importar Sequel.

Provider de LLM novo é um arquivo em `lib/shared/infrastructure/llm/` herdando
de `HttpExpenseParser` e chamando `Registry.register`.
