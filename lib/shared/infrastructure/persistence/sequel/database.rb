# frozen_string_literal: true

require "sequel"
require "fileutils"

module Infrastructure
  module Persistence
    module SequelStore
      module Database
        ROOT = File.expand_path("../../../../..", __dir__)

        module_function

        def connect(path = ENV.fetch("DB_PATH", File.join(ROOT, "data", "pecman.db")))
          FileUtils.mkdir_p(File.dirname(path)) unless path == ":memory:"
          db = Sequel.sqlite(path)
          db.run("PRAGMA foreign_keys = ON")
          migrate!(db)
          db
        end

        def migrate!(db)
          Sequel.extension :migration
          Sequel::Migrator.run(db, File.join(ROOT, "db", "migrations"))
        end
      end
    end
  end
end
