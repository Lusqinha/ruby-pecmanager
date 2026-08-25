# frozen_string_literal: true

module Features
  module Setup
    State = Struct.new(:step, :status, :error, :draft, :summary, keyword_init: true) do
      def ok? = status == :ok
      def invalid? = status == :invalid
      def cancelled? = status == :cancelled
      def completed? = status == :completed
    end
  end
end
