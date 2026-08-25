# frozen_string_literal: true

require "date"

module Features
  module Setup
    # Chat text -> typed input. Each step accepts a different shape, which is why
    # the parser needs to know which step it is answering.
    class InputParser
      AMOUNT = /(?:r\$\s*)?(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i
      DONE_WORDS = %w[pronto pronta acabou fim terminei nenhum nenhuma nao não].freeze
      DEDUCTION = /\bdedu[çc][ãa]o\b/i
      PERCENTAGE = /(\d{1,2}(?:[.,]\d{1,2})?)\s*%/
      COMMANDS = {
        "/voltar" => :back, "/pular" => :skip, "/cancelar" => :cancel,
        "preset" => :preset, "confirmar" => :confirm, "recomecar" => :restart,
        "pj" => :pj, "clt" => :clt
      }.freeze

      def parse(step:, text:)
        text = text.to_s.strip
        command = command_for(text)
        return Features::Setup::Input::Command.new(command) if command

        case step
        when :salary, :budgets then amount_or_percentage(text)
        when :categories then categories(text)
        when :deductions then items(text) { |line| fixed_cost(line, deduction: true) }
        when :fixed_costs then items(text) { |line| fixed_cost(line) }
        when :subscriptions then items(text) { |line| subscription(line) }
        when :goals then items(text) { |line| goal(line) }
        else Features::Setup::Input::Unknown.new(text)
        end
      end

      private

      def command_for(text)
        lowered = text.downcase
        return COMMANDS[lowered] if COMMANDS.key?(lowered)

        return :done if DONE_WORDS.include?(lowered)

        :cancel if Interface::CancelWords.match?(text)
      end

      def amount_or_percentage(text)
        if (match = text.match(/(\d{1,3}(?:[.,]\d+)?)\s*%/))
          return Features::Setup::Input::Percentage.new(match[1].tr(",", ".").to_f.round)
        end

        money = Interface::MoneyParser.parse(text)
        money ? Features::Setup::Input::Amount.new(money) : Features::Setup::Input::Unknown.new(text)
      end

      def categories(text)
        items = text.split(/[,;\n]/).map(&:strip).reject(&:empty?)
                    .map { |name| { name: name.capitalize, keywords: [] } }
        items.empty? ? Features::Setup::Input::Unknown.new(text) : Features::Setup::Input::Categories.new(items)
      end

      def items(text)
        entities = text.split("\n").filter_map { |line| yield(line) }
        entities.empty? ? Features::Setup::Input::Unknown.new(text) : Features::Setup::Input::Items.new(entities)
      end

      # "imposto 6% dedução" e "contadora 250 dedução" saem da renda antes de
      # tudo; "aluguel 900 dia 10" é custo de vida como sempre foi.
      # No passo de descontos tudo é dedução; no de custos fixos, só o que traz
      # a palavra.
      def fixed_cost(line, deduction: false)
        text = line.to_s.sub(DEDUCTION) do
          deduction = true
          " "
        end

        percentage_cost(text, deduction) || fixed_amount_cost(text, deduction)
      end

      def percentage_cost(text, deduction)
        match = PERCENTAGE.match(text)
        return nil unless match

        name = clean(text.sub(match[0], " "))
        return nil if name.empty?

        # Centésimos de ponto percentual: 6,5% vira 650.
        cents = (match[1].tr(",", ".").to_f * 100).round
        Domain::FixedCost.new(name: name, amount: Domain::Money.new(cents),
                              kind: Domain::FixedCost::PERCENT, deduction: deduction)
      end

      def fixed_amount_cost(text, deduction)
        parsed = named_amount(text)
        return nil unless parsed

        Domain::FixedCost.new(name: parsed[:name], amount: parsed[:amount],
                              due_day: parsed[:due_day], deduction: deduction)
      end

      def subscription(line)
        cycle = line.match?(/\b(anual|anuais|ano|yearly)\b/i) ? Domain::Subscription::YEARLY : Domain::Subscription::MONTHLY
        parsed = named_amount(line.sub(/\b(anual|anuais|ano|yearly|mensal|monthly)\b/i, " "))
        return nil unless parsed

        Domain::Subscription.new(name: parsed[:name], amount: parsed[:amount],
                                 due_day: parsed[:due_day], cycle: cycle)
      end

      def goal(line)
        deadline = nil
        text = line.sub(/\bat[ée]\s+(\S+)/i) { deadline = deadline_for(Regexp.last_match(1)); " " }
        parsed = named_amount(text)
        return nil unless parsed

        Domain::Goal.new(name: parsed[:name], target: parsed[:amount], deadline: deadline)
      end

      def named_amount(line)
        text = line.to_s.strip
        return nil if text.empty?

        due_day = nil
        text = text.sub(/\bdia\s+(\d{1,2})\b/i) { due_day = Regexp.last_match(1).to_i; " " }

        match = AMOUNT.match(text)
        return nil unless match

        amount = Interface::MoneyParser.parse(match[0])
        return nil unless amount&.positive?

        name = clean(text.sub(match[0], " "))
        return nil if name.empty?

        { name: name, amount: amount, due_day: due_day }
      end

      def deadline_for(text)
        case text
        when %r{\A(\d{1,2})/(\d{4})\z} then Date.new(Regexp.last_match(2).to_i, Regexp.last_match(1).to_i, 1)
        when %r{\A(\d{1,2})/(\d{1,2})/(\d{4})\z} then Date.new(Regexp.last_match(3).to_i, Regexp.last_match(2).to_i, Regexp.last_match(1).to_i)
        when /\A(\d{4})-(\d{1,2})(?:-(\d{1,2}))?\z/ then Date.new(Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, (Regexp.last_match(3) || 1).to_i)
        when /\A\d{4}\z/ then Date.new(text.to_i, 12, 1)
        end
      rescue Date::Error
        nil
      end

      def clean(text) = text.gsub(/[^\p{L}\p{N}\s]/, " ").squeeze(" ").strip
    end
  end
end
