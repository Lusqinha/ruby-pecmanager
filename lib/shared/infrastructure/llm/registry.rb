# frozen_string_literal: true

module Infrastructure
  module Llm
    # Adapters register themselves here, so a new provider is one new file: no
    # edit to the container, no case statement to extend. boot.rb loads this
    # whole directory, and LLM_BACKEND selects by the registered name.
    module Registry
      class UnknownBackend < StandardError; end

      @adapters = {}

      class << self
        attr_reader :adapters

        def register(name, klass)
          @adapters[name.to_s] = klass
        end

        def names = @adapters.keys.sort

        def build(name, **options)
          klass = @adapters[name.to_s]
          raise UnknownBackend, "LLM_BACKEND=#{name} desconhecido. Disponíveis: #{names.join(', ')}" unless klass

          klass.new(**options)
        end
      end
    end
  end
end
