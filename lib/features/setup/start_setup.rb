# frozen_string_literal: true

module Features
  module Setup
    class StartSetup
      def initialize(draft_repository:)
        @draft_repository = draft_repository
      end

      def call(user_id:)
        transition = Features::Setup::Wizard.start
        @draft_repository.save(user_id, transition.step, transition.draft)

        State.new(step: transition.step, status: :ok, draft: transition.draft)
      end
    end
  end
end
