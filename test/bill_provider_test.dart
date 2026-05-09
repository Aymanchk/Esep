import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fairsplitter/providers/bill_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  BillProvider providerWithPeople(List<String> names) {
    final provider = BillProvider();
    for (final name in names) {
      provider.addPerson(name);
    }
    return provider;
  }

  group('BillProvider split calculations', () {
    test('equal split with zero participants returns zero for subtotal', () {
      final provider = BillProvider();
      addTearDown(provider.dispose);

      provider.addItem('Dinner', 100);
      provider.setSplitMode(SplitMode.equal);

      expect(provider.subtotal, 100);
      expect(provider.getPersonSubtotal('missing_person'), 0);
      expect(provider.getPersonTotal('missing_person'), 0);
    });

    test('equal split with one participant assigns the full subtotal', () {
      final provider = providerWithPeople(['Alice']);
      addTearDown(provider.dispose);
      final alice = provider.people.first;

      provider.addItem('Coffee', 12.75);
      provider.setSplitMode(SplitMode.equal);

      expect(provider.getPersonSubtotal(alice.id), closeTo(12.75, 0.001));
      expect(provider.getPersonTotal(alice.id), closeTo(12.75, 0.001));
    });

    test('equal split preserves decimal amounts', () {
      final provider = providerWithPeople(['Alice', 'Bob']);
      addTearDown(provider.dispose);

      provider.addItem('Shared dessert', 10.50);
      provider.setSplitMode(SplitMode.equal);

      expect(
        provider.getPersonSubtotal(provider.people[0].id),
        closeTo(5.25, 0.001),
      );
      expect(
        provider.getPersonSubtotal(provider.people[1].id),
        closeTo(5.25, 0.001),
      );
    });

    test('by-items split supports unequal item assignment', () {
      final provider = providerWithPeople(['Alice', 'Bob']);
      addTearDown(provider.dispose);

      provider.addItem('Pasta', 30);
      provider.addItem('Tea', 10, quantity: 2);
      provider.setSplitMode(SplitMode.byItems);

      final alice = provider.people[0];
      final bob = provider.people[1];
      provider.assignOneUnit('item_0', alice.id);
      provider.assignOneUnit('item_1', bob.id);
      provider.assignOneUnit('item_1', bob.id);

      expect(provider.getPersonSubtotal(alice.id), closeTo(30, 0.001));
      expect(provider.getPersonSubtotal(bob.id), closeTo(20, 0.001));
    });

    test('by-items split divides an over-assigned shared item proportionally', () {
      final provider = providerWithPeople(['Alice', 'Bob', 'Cara']);
      addTearDown(provider.dispose);

      provider.addItem('Pizza', 90);
      provider.setSplitMode(SplitMode.byItems);

      for (final person in provider.people) {
        provider.assignOneUnit('item_0', person.id);
      }

      for (final person in provider.people) {
        expect(provider.getPersonSubtotal(person.id), closeTo(30, 0.001));
      }
    });

    test('by-items split charges per unit when assigned shares fit quantity', () {
      final provider = providerWithPeople(['Alice', 'Bob']);
      addTearDown(provider.dispose);

      provider.addItem('Dumplings', 10, quantity: 3);
      provider.setSplitMode(SplitMode.byItems);

      final alice = provider.people[0];
      final bob = provider.people[1];
      provider.assignOneUnit('item_0', alice.id);
      provider.assignOneUnit('item_0', alice.id);
      provider.assignOneUnit('item_0', bob.id);

      expect(provider.getPersonSubtotal(alice.id), closeTo(20, 0.001));
      expect(provider.getPersonSubtotal(bob.id), closeTo(10, 0.001));
    });

    test('percentage split uses each participant percentage', () {
      final provider = providerWithPeople(['Alice', 'Bob']);
      addTearDown(provider.dispose);

      provider.addItem('Groceries', 200);
      provider.setSplitMode(SplitMode.percentage);
      provider.setPersonPercentage(provider.people[0].id, 25);
      provider.setPersonPercentage(provider.people[1].id, 75);

      expect(
        provider.getPersonSubtotal(provider.people[0].id),
        closeTo(50, 0.001),
      );
      expect(
        provider.getPersonSubtotal(provider.people[1].id),
        closeTo(150, 0.001),
      );
    });

    test('shares split divides subtotal by configured shares', () {
      final provider = providerWithPeople(['Alice', 'Bob']);
      addTearDown(provider.dispose);

      provider.addItem('Rent', 120);
      provider.setSplitMode(SplitMode.shares);
      provider.setPersonShares(provider.people[0].id, 1);
      provider.setPersonShares(provider.people[1].id, 3);

      expect(
        provider.getPersonSubtotal(provider.people[0].id),
        closeTo(30, 0.001),
      );
      expect(
        provider.getPersonSubtotal(provider.people[1].id),
        closeTo(90, 0.001),
      );
    });

    test('shares split returns zero when no shares are configured', () {
      final provider = providerWithPeople(['Alice', 'Bob']);
      addTearDown(provider.dispose);

      provider.addItem('Trip', 100);
      provider.setSplitMode(SplitMode.shares);

      expect(provider.getPersonSubtotal(provider.people[0].id), 0);
      expect(provider.getPersonSubtotal(provider.people[1].id), 0);
    });

    test('local guest participant can be assigned items', () {
      final provider = BillProvider();
      addTearDown(provider.dispose);

      provider.addPerson('Local Guest');
      provider.addItem('Snack', 8.40);
      provider.setSplitMode(SplitMode.byItems);
      provider.assignOneUnit('item_0', provider.people.first.id);

      expect(provider.people.first.userId, isNull);
      expect(
        provider.getPersonSubtotal(provider.people.first.id),
        closeTo(8.40, 0.001),
      );
    });

    test('service charge affects person total but not subtotal', () {
      final provider = providerWithPeople(['Alice', 'Bob']);
      addTearDown(provider.dispose);

      provider.addItem('Meal', 100);
      provider.setSplitMode(SplitMode.equal);
      provider.toggleServiceCharge(true);
      provider.setServiceChargePercent(12.5);

      expect(
        provider.getPersonSubtotal(provider.people[0].id),
        closeTo(50, 0.001),
      );
      expect(
        provider.getPersonTotal(provider.people[0].id),
        closeTo(56.25, 0.001),
      );
    });
  });
}
