class BillItem {
  final String id;
  String name;
  double price;
  int quantity;

  BillItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;
}
