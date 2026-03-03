class BmbBucks {
  final int balance;
  final List<BmbBucksTransaction> transactions;

  const BmbBucks({required this.balance, this.transactions = const []});
}

class BmbBucksTransaction {
  final String id;
  final String description;
  final int amount;
  final DateTime date;
  final String type;

  const BmbBucksTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
  });

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;
}
