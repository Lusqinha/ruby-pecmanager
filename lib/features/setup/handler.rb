# frozen_string_literal: true

module Features
  module Setup
    # Intercepts instead of routing: mid-wizard, "35 mercado" is the answer to a
    # step, not an expense.
    class Handler < Shared::Handler
      route "/setup", to: :start

      def initialize(find_user:, start_setup:, advance_setup:, presenter:)
        @find_user = find_user
        @start_setup = start_setup
        @advance_setup = advance_setup
        @presenter = presenter
      end

      def intercept(request)
        status = @find_user.call(user_id: request.user_id)
        return advance(request) if status[:setup_in_progress]
        return start(request) unless status[:user]&.setup_done?

        nil
      end

      def start(request)
        @presenter.call(@start_setup.call(user_id: request.user_id))
      end

      private

      def advance(request)
        state = @advance_setup.call(user_id: request.user_id, text: request.text, name: request.name)
        state ? @presenter.call(state) : start(request)
      end
    end
  end
end
