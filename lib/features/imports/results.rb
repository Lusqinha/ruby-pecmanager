# frozen_string_literal: true

module Features
  module Imports
    Result = Struct.new(:status, :kind, :items, :duplicates, :source, :error, :recorded, :uncategorized,
                        keyword_init: true)
  end
end
