# frozen_string_literal: true

module Ports
  # Interfaces the use cases depend on. Infrastructure implements them; the
  # dependency never points the other way.
  class AbstractPort
    def self.abstract(*names)
      names.each do |name|
        define_method(name) { |*_args, **_kwargs| raise NotImplementedError, "#{self.class}##{name}" }
      end
    end
  end

  class UserRepository < AbstractPort
    abstract :find, :save
  end

  class CategoryRepository < AbstractPort
    # replace_all keeps the categories listed in keep_ids even when the new plan
    # drops them, so existing expenses are never orphaned.
    abstract :for_user, :find, :save, :replace_all
  end

  class ExpenseRepository < AbstractPort
    abstract :add, :find, :delete, :last_for, :for_period, :for_category,
             :totals_by_category, :category_ids_with_expenses
  end

  class FixedCostRepository < AbstractPort
    abstract :for_user, :replace_all
  end

  class SubscriptionRepository < AbstractPort
    abstract :for_user, :replace_all
  end

  class GoalRepository < AbstractPort
    abstract :for_user, :replace_all, :save
  end

  class InstallmentPlanRepository < AbstractPort
    abstract :for_user, :active, :find, :add, :save, :created_since, :delete
  end

  class PendingImportRepository < AbstractPort
    abstract :find, :save, :delete
  end

  class DraftRepository < AbstractPort
    abstract :find, :save, :delete
  end

  # Returns a ParsedExpense, or nil when it cannot tell.
  class ExpenseParser < AbstractPort
    abstract :parse
  end

  class InputParser < AbstractPort
    abstract :parse
  end

  class Clock < AbstractPort
    abstract :today, :now
  end
end
