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
