# PecMan

Bot de Telegram para controle de gastos pessoais. Ruby, SQLite.

Os lançamentos são feitos em texto livre (`35 mercado`). A leitura é
determinística: expressão regular extrai valor e data, e as palavras-chave da
categoria resolvem o resto. Um modelo de linguagem local é consultado apenas
quando a categoria não é identificada.

## Setup

```sh
bundle install
cp .env.example .env    # TELEGRAM_TOKEN e ALLOWED_USER_IDS
set -a; source .env; set +a
ruby bot.rb
```

O banco é criado em `data/pecman.db` no primeiro boot, com as migrations
aplicadas automaticamente.

Se `bundle install` falhar ao compilar `bigdecimal` ou `json`, falta o pacote
`ruby-dev`. Alternativa sem build nativo:

```sh
gem install --user-install telegram-bot-ruby sequel sqlite3
```

Para a interpretação por modelo de linguagem, é preciso ter `llama-server` ou
Ollama disponível em `LLAMA_URL`. Sem isso o bot opera apenas com a leitura por
expressão regular.

Em ambientes sem locale UTF-8 (Termux em proot, contêineres enxutos), defina
`LANG=C.UTF-8` antes de iniciar.

## Logs

Uma linha por evento, em stderr:

```
2026-08-25T17:42:06Z  INFO  telegram  Bot iniciado. Usuários autorizados: 1
2026-08-25T17:42:11Z  WARN  llm       Consulta ao modelo falhou, seguindo sem ela: Net::OpenTimeout
```

`LOG_LEVEL` aceita `debug`, `info` (padrão), `warn` e `error`. Em `debug` os
backtraces das falhas também são registrados.

## Contribuindo

```sh
rake test
```

O código é organizado em vertical slices: `lib/features/<assunto>/` reúne
domínio, casos de uso, presenter e rotas. `lib/shared/` contém o que é usado por
mais de um slice.

Rotas são declaradas dentro do próprio slice:

```ruby
class Handler < Shared::Handler
  route "/parcelas", to: :list
  callback(/\Aplan:cancel:(\d+)\z/, to: :cancel)
end
```

Um slice novo é registrado no router em `lib/config/container.rb`.

`rake test` executa `test/config/architecture_test.rb`, que falha se um slice
importar outro ou se o domínio importar Sequel.

Um provedor de modelo novo é um arquivo em `lib/shared/infrastructure/llm/`,
herdando de `HttpExpenseParser` e chamando `Registry.register`.

### Branches e commits

Modelo gitflow: `main` guarda as releases, `develop` é a base do trabalho,
funcionalidades saem em `feature/<nome>` e correções urgentes em
`hotfix/<nome>`.

Mensagens no padrão conventional commits:

```
feat(installments): aceita mes por extenso no cadastro
fix(imports): valor do lote pendente relido como reais
refactor(reports): extrai calculo de projecao
test(setup): cobre wizard PJ
docs: atualiza readme
chore: ajusta gitignore
```

O escopo é o slice (`setup`, `expense`, `installments`, `reports`, `imports`,
`account`) ou vazio, quando a mudança é transversal.
