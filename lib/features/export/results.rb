# frozen_string_literal: true

module Features
  module Export
    # data é o retrato inteiro do usuário em valores simples: quem renderiza
    # decide se vira Markdown ou JSON.
    Result = Struct.new(:status, :data, :generated_on, keyword_init: true)
  end
end
