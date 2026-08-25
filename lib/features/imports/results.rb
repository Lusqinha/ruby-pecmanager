# frozen_string_literal: true

module Features
  module Imports
    Result = Struct.new(:status, :kind, :items, :duplicates, :source, :error, :recorded, :uncategorized,
                        :in_budget, keyword_init: true)
  end
end
