# frozen_string_literal: true

require "logger"

module Infrastructure
  # Logger da stdlib com formato de uma linha por evento:
  #
  #   2026-08-25T01:12:03Z  INFO  telegram  Bot iniciado (1 usuário autorizado)
  #
  # Cada componente pega o seu com `Log.for("telegram")`, e o nome aparece na
  # linha — assim dá pra filtrar por componente com grep.
  module Log
    LEVELS = { "debug" => Logger::DEBUG, "info" => Logger::INFO,
               "warn" => Logger::WARN, "error" => Logger::ERROR }.freeze

    module_function

    def for(component, io: $stderr, level: ENV.fetch("LOG_LEVEL", "info"))
      logger = Logger.new(io)
      logger.level = LEVELS.fetch(level.to_s.downcase, Logger::INFO)
      logger.progname = component
      logger.formatter = FORMATTER
      logger
    end

    FORMATTER = lambda do |severity, time, component, message|
      format("%<time>s  %<level>-5s %<component>-9s %<message>s\n",
             time: time.utc.strftime("%Y-%m-%dT%H:%M:%SZ"), level: severity,
             component: component, message: message)
    end
  end
end
