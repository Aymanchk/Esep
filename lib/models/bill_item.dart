class BillItem {
  final String id;
  String name;
  double price;
  int quantity;
  bool isWeightBased;
  double weightKg;

  BillItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.isWeightBased = false,
    this.weightKg = 0,
  });

  double get totalPrice => price * quantity;
}
