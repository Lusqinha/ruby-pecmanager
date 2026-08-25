# frozen_string_literal: true

module Features
  module Setup
    # Persists the half-finished draft on every step, so an abandoned setup can be
    # resumed without writing junk into the real tables.
    class AdvanceSetup
      def initialize(draft_repository:, complete_setup:, input_parser:, clock:)
        @draft_repository = draft_repository
        @complete_setup = complete_setup
        @input_parser = input_parser
        @clock = clock
      end

      # Parsing depends on the current step, which only the stored state knows,
      # so it happens here and not in the delivery layer.
      def call(user_id:, text:, name: nil)
        stored = @draft_repository.find(user_id)
        return nil unless stored

        input = @input_parser.parse(step: stored[:step], text: text)
        transition = Features::Setup::Wizard.apply(step: stored[:step], draft: stored[:draft], input: input)

        case transition.status
        when :cancelled then finish(user_id, transition)
        when :completed then complete(user_id, transition, name)
        else persist(user_id, transition)
        end
      end

      private

      def complete(user_id, transition, name)
        @complete_setup.call(user_id: user_id, draft: transition.draft, name: name)
        finish(user_id, transition)
      end

      def finish(user_id, transition)
        @draft_repository.delete(user_id)
        state(transition)
      end

      def persist(user_id, transition)
        @draft_repository.save(user_id, transition.step, transition.draft)
        state(transition)
      end

      def state(transition)
        State.new(
          step: transition.step, status: transition.status, error: transition.error,
          draft: transition.draft,
          summary: transition.step == :confirm ? transition.draft.to_plan.summary(@clock.today) : nil
        )
      end
    end
  end
end
