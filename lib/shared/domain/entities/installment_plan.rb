# frozen_string_literal: true

module Domain
  # Uma compra parcelada: compromisso futuro, não gasto já ocorrido. Nenhuma
  # Expense é criada pelas parcelas — os relatórios projetam a partir daqui, o
  # que deixa cancelar barato e mantém o histórico honesto.
  class InstallmentPlan
    attr_reader :id, :user_id, :category_id, :description, :origin,
                :total, :count, :first_month, :cancelled_on, :created_at

    def initialize(user_id:, description:, total:, count:, first_month:, id: nil, category_id: nil,
                   origin: nil, cancelled_on: nil, created_at: nil)
      @id = id
      @user_id = user_id
      @category_id = category_id
      @description = description.to_s
      @origin = origin
      @total = total
      @count = Integer(count)
      @first_month = Month.first_of(first_month)
      @cancelled_on = cancelled_on
      @created_at = created_at
    end

    # O resto de centavos vai na última parcela: a soma das parcelas é sempre
    # igual ao total, sem float no meio.
    def amount_for(number)
      base = total.cents / count
      Money.new(number >= count ? total.cents - (base * (count - 1)) : base)
    end

    def last_month = Month.advance(first_month, count - 1)

    def number_in(month)
      month = Month.first_of(month)
      return nil if month < first_month || month > last_month

      Month.distance(first_month, month) + 1
    end

    # Cancelar corta a partir do mês seguinte: a parcela do mês em que você
    # cancelou já caiu na fatura.
    def due_in(month)
      number = number_in(month)
      return nil unless number
      return nil if cancelled_on && Month.first_of(month) > Month.first_of(cancelled_on)

      amount_for(number)
    end

    def active_in?(month) = !due_in(month).nil?
    def cancelled? = !cancelled_on.nil?
    def label_in(month) = "#{number_in(month)}/#{count}"

    def cancel(on:)
      self.class.new(id: id, user_id: user_id, category_id: category_id, description: description,
                     origin: origin, total: total, count: count, first_month: first_month,
                     cancelled_on: on, created_at: created_at)
    end
  end
end
