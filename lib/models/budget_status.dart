/// Threshold states for monthly category budgets.
enum BudgetStatus {
  /// Spending is under 80% of the limit – no alert.
  none,

  /// Spending reached >= 80% of the limit – show warning notification.
  warning,

  /// Spending reached 100% (or more) – show exceeded notification.
  exceeded,
}
