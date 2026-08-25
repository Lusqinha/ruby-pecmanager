# frozen_string_literal: true

module Shared
  # Lets a slice decide between setup and normal operation without reaching for
  # a repository it does not own.
  class FindUser
    def initialize(user_repository:, draft_repository:)
      @user_repository = user_repository
      @draft_repository = draft_repository
    end

    def call(user_id:)
      { user: @user_repository.find(user_id), setup_in_progress: !@draft_repository.find(user_id).nil? }
    end
  end
end
