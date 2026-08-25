# frozen_string_literal: true

module Features
  module Setup
    # The wizard never sees a String: the parser converts chat text into one of
    # these first.
    module Input
      Amount = Struct.new(:money)
      Percentage = Struct.new(:value)
      Categories = Struct.new(:items)
      Items = Struct.new(:entities)
      Command = Struct.new(:name) # :back :skip :cancel :done :confirm :restart :preset :pj :clt
      Unknown = Struct.new(:raw)

      def self.command?(input, name) = input.is_a?(Command) && input.name == name
    end
  end
end
