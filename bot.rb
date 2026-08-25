# frozen_string_literal: true

require_relative "lib/config/boot"
require_relative "lib/shared/infrastructure/telegram/bot_runner"

token = ENV["TELEGRAM_TOKEN"].to_s
allowed = ENV["ALLOWED_USER_IDS"].to_s.split(",").map { |id| id.strip.to_i }.reject(&:zero?)

# Long polling means anyone who finds the bot can message it, so the id list is
# the only gate. Refuse to start without one instead of running wide open.
abort("TELEGRAM_TOKEN não definido") if token.empty?
abort("ALLOWED_USER_IDS não definido (ex: ALLOWED_USER_IDS=123456,789012)") if allowed.empty?

db = Infrastructure::Persistence::SequelStore::Database.connect
container = Config::Container.new(db: db)

# Warms the model up so the first expense of the day is not the slow one. Never
# fatal: without the LLM the regex parser answers.
container.llm_parser.warmup if container.llm_parser.respond_to?(:warmup)

Infrastructure::Telegram::BotRunner.new(
  token: token, allowed_user_ids: allowed, controller: container.router
).run
