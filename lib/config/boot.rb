# frozen_string_literal: true

# Shared kernel first, then the slices. Slices may use shared; nothing in shared
# may reach into a slice.
root = File.expand_path("../..", __dir__)

def require_all(root, *globs)
  globs.each { |glob| Dir[File.join(root, glob)].sort.each { |file| require file } }
end

require_all(root,
            "lib/shared/domain/values/*.rb",
            "lib/shared/domain/entities/*.rb",
            "lib/shared/domain/services/*.rb",
            "lib/shared/ports/*.rb",
            "lib/shared/interface/*.rb",
            "lib/shared/handler.rb",
            "lib/shared/find_user.rb",
            "lib/shared/plan_assembler.rb",
            "lib/shared/infrastructure/log.rb",
            "lib/shared/infrastructure/schedule.rb",
            "lib/shared/infrastructure/system_clock.rb",
            "lib/shared/infrastructure/parsing/*.rb",
            "lib/shared/infrastructure/llm/registry.rb",
            "lib/shared/infrastructure/llm/http_expense_parser.rb",
            # every adapter here registers itself: a new provider is one file
            "lib/shared/infrastructure/llm/*.rb",
            "lib/shared/infrastructure/persistence/sequel/*.rb",
            # each slice owns its domain, use cases, presenter and routes
            "lib/features/*/*.rb",
            "lib/config/router.rb",
            "lib/config/container.rb")
