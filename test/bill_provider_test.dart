import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/providers/bill_provider.dart';

void main() {
  group('BillProvider — byItems split', () {
    test('single item fully assigned to one person matches its price', () {
      final p = BillProvider();
      p.addPerson('Alice');
      p.addItem('Coffee', 150.0);
      final itemId = p.items.first.id;
      final aliceId = p.people.first.id;

      p.assignOneUnit(itemId, aliceId);

      expect(p.getPersonSubtotal(aliceId), 150.0);
      expect(p.unassignedItems, isEmpty);
    });

    test('item shared by more people than its quantity divides proportionally', () {
      final p = BillProvider();
      p.addPerson('Alice');
      p.addPerson('Bob');
      p.addPerson('Cara');
      // quantity 1, but 3 people each take a "share" of it (oversharing).
      p.addItem('Big pizza', 900.0, quantity: 1);
      final itemId = p.items.first.id;
      final ids = p.people.map((x) => x.id).toList();

      for (final id in ids) {
        p.assignOneUnit(itemId, id);
      }

      final total = ids.fold(0.0, (sum, id) => sum + p.getPersonSubtotal(id));
      expect(total, closeTo(900.0, 0.0001));
      for (final id in ids) {
        expect(p.getPersonSubtotal(id), closeTo(300.0, 0.0001));
      }
    });

    test('partially-assigned item is flagged and excluded from totals', () {
      final p = BillProvider();
      p.addPerson('Alice');
      p.addItem('Bottled water', 60.0, quantity: 3);
      final itemId = p.items.first.id;
      final aliceId = p.people.first.id;

      // Only 1 of 3 units assigned — 2 units' worth of price is left out.
      p.assignOneUnit(itemId, aliceId);

      expect(p.unassignedItems, isEmpty); // getTotalAssignedUnits > 0, so not "fully unassigned"
      expect(p.getRemainingUnits(itemId), 2);
      // The sum of what people owe does NOT cover the bill's subtotal —
      // the UI must surface getRemainingUnits()/unassignedItems to the user,
      // otherwise money silently goes uncollected.
      expect(p.getPersonSubtotal(aliceId), lessThan(p.subtotal));
    });
  });

  group('BillProvider — percentage split', () {
    test('percentages that do not sum to 100 do not cover the bill total', () {
      final p = BillProvider();
      p.addPerson('Alice');
      p.addPerson('Bob');
      p.addItem('Dinner', 1000.0);
      p.setSplitMode(SplitMode.percentage);

      final aliceId = p.people[0].id;
      final bobId = p.people[1].id;
      p.setPersonPercentage(aliceId, 40);
      p.setPersonPercentage(bobId, 40); // sums to 80, not 100

      final sumOfShares = p.getPersonSubtotal(aliceId) + p.getPersonSubtotal(bobId);

      // Known limitation: nothing validates that percentages sum to 100,
      // so 200 (= 20% of 1000) silently never gets billed to anyone.
      expect(sumOfShares, closeTo(800.0, 0.0001));
      expect(sumOfShares, isNot(closeTo(p.subtotal, 0.0001)));
    });
  });

  group('BillProvider — shares split', () {
    test('shares split distributes the full subtotal with no leftover', () {
      final p = BillProvider();
      p.addPerson('Alice');
      p.addPerson('Bob');
      p.addItem('Groceries', 1000.0);
      p.setSplitMode(SplitMode.shares);

      final aliceId = p.people[0].id;
      final bobId = p.people[1].id;
      p.setPersonShares(aliceId, 1);
      p.setPersonShares(bobId, 3);

      expect(p.getPersonSubtotal(aliceId), closeTo(250.0, 0.0001));
      expect(p.getPersonSubtotal(bobId), closeTo(750.0, 0.0001));
      expect(
        p.getPersonSubtotal(aliceId) + p.getPersonSubtotal(bobId),
        closeTo(p.subtotal, 0.0001),
      );
    });
  });

  group('BillProvider — service charge', () {
    test('service charge is added on top of a fully-assigned bill, split by item shares', () {
      final p = BillProvider();
      p.addPerson('Alice');
      p.addPerson('Bob');
      p.addItem('Dinner', 1000.0);
      final itemId = p.items.first.id;
      final aliceId = p.people[0].id;
      final bobId = p.people[1].id;

      p.assignOneUnit(itemId, aliceId);
      p.assignOneUnit(itemId, bobId); // shared 50/50, oversharing a quantity-1 item

      p.setServiceChargePercent(10);
      p.toggleServiceCharge(true);

      expect(p.total, closeTo(1100.0, 0.0001));
      final sumOfTotals = p.getPersonTotal(aliceId) + p.getPersonTotal(bobId);
      expect(sumOfTotals, closeTo(p.total, 0.0001));
    });
  });

  group('BillProvider — weight-based items', () {
    test('setItemWeight rounds price to the nearest cent', () {
      final p = BillProvider();
      p.addItem('Cheese', 0.0, isWeightBased: true);
      final itemId = p.items.first.id;

      // 0.333 kg at 299.99 per kg = 99.896667 -> should round to 99.90
      p.setItemWeight(itemId, 0.333, 299.99);

      expect(p.items.first.price, closeTo(99.9, 0.0001));
    });
  });
}
