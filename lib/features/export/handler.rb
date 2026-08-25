# frozen_string_literal: true

module Features
  module Export
    class Handler < Shared::Handler
      route "/exportar", to: :menu
      route "/export", to: :menu
      callback("export:md", to: :markdown)
      callback("export:json", to: :json)

      def initialize(export_data:, presenter:)
        @export_data = export_data
        @presenter = presenter
      end

      def menu(_request) = @presenter.menu
      def markdown(request) = @presenter.markdown(@export_data.call(user_id: request.user_id))
      def json(request) = @presenter.json(@export_data.call(user_id: request.user_id))
    end
  end
end
