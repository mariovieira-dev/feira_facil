import 'package:flutter_test/flutter_test.dart';
import 'package:feira_facil/models/purchase.dart';
import 'package:feira_facil/models/product.dart';
import 'package:feira_facil/models/category.dart';
import 'package:feira_facil/models/unit.dart';

void main() {
  group('PurchaseItem - Price Calculations', () {
    test('pricePerUnit calculates correctly for unit items', () {
      final item = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Maçã',
        category: Category.fruitsAndVegetables,
        quantity: 6,
        unit: Unit.unit,
        pricePaid: 12.00,
      );

      expect(item.pricePerUnit, 2.00);
      expect(item.totalPrice, 12.00);
    });

    test('pricePerUnit calculates correctly for kg items', () {
      final item = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Arroz',
        category: Category.pantryBasics,
        quantity: 5,
        unit: Unit.kilogram,
        pricePaid: 25.00,
      );

      expect(item.pricePerUnit, 5.00); // R$ 5,00/kg
      expect(item.totalPrice, 25.00);
    });

    test('pricePerBaseUnit converts kg to g correctly', () {
      final item = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Arroz',
        category: Category.pantryBasics,
        quantity: 1,
        unit: Unit.kilogram,
        pricePaid: 5.00,
      );

      // 1 kg = 1000g, preço por grama = 5.00 / 1000 = 0.005
      expect(item.pricePerBaseUnit, 0.005);
      expect(item.unit.baseUnit, Unit.gram);
      expect(item.unit.baseUnitLabel, 'g');
    });

    test('pricePerBaseUnit converts L to ml correctly', () {
      final item = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Leite',
        category: Category.dairy,
        quantity: 1,
        unit: Unit.liter,
        pricePaid: 4.00,
      );

      // 1 L = 1000ml, preço por ml = 4.00 / 1000 = 0.004
      expect(item.pricePerBaseUnit, 0.004);
      expect(item.unit.baseUnit, Unit.milliliter);
      expect(item.unit.baseUnitLabel, 'ml');
    });

    test('pricePerBaseUnit same as pricePerUnit for base units', () {
      final item = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Sabão',
        category: Category.cleaningProducts,
        quantity: 2,
        unit: Unit.unit,
        pricePaid: 10.00,
      );

      expect(item.pricePerBaseUnit, 5.00);
      expect(item.pricePerUnit, 5.00);
      expect(item.unit.baseUnit, Unit.unit);
    });

    test('pricePerBaseUnit for grams', () {
      final item = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Queijo',
        category: Category.dairy,
        quantity: 500,
        unit: Unit.gram,
        pricePaid: 15.00,
      );

      expect(item.pricePerBaseUnit, 0.03); // 15 / 500
      expect(item.pricePerUnit, 0.03);
    });

    test('pricePerBaseUnit for milliliters', () {
      final item = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Óleo',
        category: Category.pantryBasics,
        quantity: 900,
        unit: Unit.milliliter,
        pricePaid: 9.00,
      );

      expect(item.pricePerBaseUnit, 0.01); // 9 / 900
      expect(item.pricePerUnit, 0.01);
    });

    test('handles zero quantity gracefully', () {
      final item = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Teste',
        category: Category.pantryBasics,
        quantity: 0,
        unit: Unit.unit,
        pricePaid: 10.00,
      );

      expect(item.pricePerUnit, 0);
      expect(item.pricePerBaseUnit, 0);
    });
  });

  group('Purchase - Totals', () {
    test('totalAmount sums all items correctly', () {
      final purchase = Purchase(
        date: DateTime.now(),
        location: 'Mercado',
        items: [
          PurchaseItem(
            purchaseId: 1,
            productId: 1,
            productName: 'Arroz',
            category: Category.pantryBasics,
            quantity: 1,
            unit: Unit.kilogram,
            pricePaid: 5.00,
          ),
          PurchaseItem(
            purchaseId: 1,
            productId: 2,
            productName: 'Feijão',
            category: Category.pantryBasics,
            quantity: 1,
            unit: Unit.kilogram,
            pricePaid: 8.00,
          ),
          PurchaseItem(
            purchaseId: 1,
            productId: 3,
            productName: 'Leite',
            category: Category.dairy,
            quantity: 2,
            unit: Unit.liter,
            pricePaid: 8.00,
          ),
        ],
      );

      expect(purchase.totalAmount, 21.00);
    });

    test('totalByCategory groups correctly', () {
      final purchase = Purchase(
        date: DateTime.now(),
        location: 'Mercado',
        items: [
          PurchaseItem(
            purchaseId: 1,
            productId: 1,
            productName: 'Arroz',
            category: Category.pantryBasics,
            quantity: 1,
            unit: Unit.kilogram,
            pricePaid: 5.00,
          ),
          PurchaseItem(
            purchaseId: 1,
            productId: 2,
            productName: 'Feijão',
            category: Category.pantryBasics,
            quantity: 1,
            unit: Unit.kilogram,
            pricePaid: 8.00,
          ),
          PurchaseItem(
            purchaseId: 1,
            productId: 3,
            productName: 'Leite',
            category: Category.dairy,
            quantity: 2,
            unit: Unit.liter,
            pricePaid: 8.00,
          ),
        ],
      );

      final byCategory = purchase.totalByCategory;
      expect(byCategory[Category.pantryBasics], 13.00);
      expect(byCategory[Category.dairy], 8.00);
      expect(byCategory.length, 2);
    });

    test('empty purchase has zero total', () {
      final purchase = Purchase(
        date: DateTime.now(),
        location: 'Mercado',
        items: [],
      );

      expect(purchase.totalAmount, 0.0);
      expect(purchase.totalByCategory.isEmpty, true);
    });
  });

  group('Unit - Conversion', () {
    test('toBaseUnit converts kg to g', () {
      expect(Unit.kilogram.toBaseUnit(1), 1000);
      expect(Unit.kilogram.toBaseUnit(0.5), 500);
      expect(Unit.kilogram.toBaseUnit(2.5), 2500);
    });

    test('toBaseUnit converts L to ml', () {
      expect(Unit.liter.toBaseUnit(1), 1000);
      expect(Unit.liter.toBaseUnit(0.5), 500);
      expect(Unit.liter.toBaseUnit(1.5), 1500);
    });

    test('toBaseUnit returns same value for base units', () {
      expect(Unit.unit.toBaseUnit(5), 5);
      expect(Unit.gram.toBaseUnit(500), 500);
      expect(Unit.milliliter.toBaseUnit(250), 250);
    });

    test('fromString parses correctly', () {
      expect(Unit.fromString('unit'), Unit.unit);
      expect(Unit.fromString('kilogram'), Unit.kilogram);
      expect(Unit.fromString('gram'), Unit.gram);
      expect(Unit.fromString('liter'), Unit.liter);
      expect(Unit.fromString('milliliter'), Unit.milliliter);
      expect(Unit.fromString('invalid'), Unit.unit); // default
    });
  });

  group('Category - Parsing', () {
    test('fromString parses correctly', () {
      expect(Category.fromString('cleaningProducts'), Category.cleaningProducts);
      expect(Category.fromString('fruitsAndVegetables'), Category.fruitsAndVegetables);
      expect(Category.fromString('pantryBasics'), Category.pantryBasics);
      expect(Category.fromString('butcherColdCuts'), Category.butcherColdCuts);
      expect(Category.fromString('dairy'), Category.dairy);
      expect(Category.fromString('hygiene'), Category.hygiene);
      expect(Category.fromString('invalid'), Category.pantryBasics); // default
    });

    test('labels are in Portuguese', () {
      expect(Category.cleaningProducts.label, 'Produtos de limpeza');
      expect(Category.fruitsAndVegetables.label, 'Frutas e legumes');
      expect(Category.pantryBasics.label, 'Despensa / Básico');
      expect(Category.butcherColdCuts.label, 'Açougue / Frios');
      expect(Category.dairy.label, 'Laticínios');
      expect(Category.hygiene.label, 'Higiene');
    });
  });

  group('Price Comparison', () {
    test('calculates price increase percentage correctly', () {
      final lastPrice = 5.00; // R$ 5,00/kg
      final currentPrice = 6.00; // R$ 6,00/kg
      
      final difference = currentPrice - lastPrice;
      final percentChange = (difference / lastPrice) * 100;
      
      expect(percentChange, 20.0); // 20% increase
    });

    test('calculates price decrease percentage correctly', () {
      final lastPrice = 10.00;
      final currentPrice = 8.00;
      
      final difference = currentPrice - lastPrice;
      final percentChange = (difference / lastPrice) * 100;
      
      expect(percentChange, -20.0); // 20% decrease
    });

    test('calculates no change correctly', () {
      final lastPrice = 5.00;
      final currentPrice = 5.00;
      
      final difference = currentPrice - lastPrice;
      final percentChange = (difference / lastPrice) * 100;
      
      expect(percentChange, 0.0);
    });

    test('compares prices per base unit correctly', () {
      // Última compra: 1kg de arroz por R$ 5,00 = R$ 0,005/g
      final lastItem = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Arroz',
        category: Category.pantryBasics,
        quantity: 1,
        unit: Unit.kilogram,
        pricePaid: 5.00,
      );

      // Compra atual: 500g de arroz por R$ 3,00 = R$ 0,006/g
      final currentItem = PurchaseItem(
        purchaseId: 2,
        productId: 1,
        productName: 'Arroz',
        category: Category.pantryBasics,
        quantity: 500,
        unit: Unit.gram,
        pricePaid: 3.00,
      );

      // Preço subiu de R$ 0,005/g para R$ 0,006/g = 20% de aumento
      expect(lastItem.pricePerBaseUnit, 0.005);
      expect(currentItem.pricePerBaseUnit, 0.006);
      
      final percentChange = ((currentItem.pricePerBaseUnit - lastItem.pricePerBaseUnit) 
          / lastItem.pricePerBaseUnit) * 100;
      expect(percentChange, 20.0);
    });

    test('compares different units correctly (kg vs g)', () {
      // Última compra: 1kg por R$ 20,00 = R$ 0,02/g
      final lastItem = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Carne',
        category: Category.butcherColdCuts,
        quantity: 1,
        unit: Unit.kilogram,
        pricePaid: 20.00,
      );

      // Compra atual: 500g por R$ 12,00 = R$ 0,024/g
      final currentItem = PurchaseItem(
        purchaseId: 2,
        productId: 1,
        productName: 'Carne',
        category: Category.butcherColdCuts,
        quantity: 500,
        unit: Unit.gram,
        pricePaid: 12.00,
      );

      expect(lastItem.pricePerBaseUnit, 0.02);
      expect(currentItem.pricePerBaseUnit, 0.024);
      
      final percentChange = ((currentItem.pricePerBaseUnit - lastItem.pricePerBaseUnit) 
          / lastItem.pricePerBaseUnit) * 100;
      expect(percentChange, 20.0); // 20% mais caro
    });

    test('compares liter vs milliliter correctly', () {
      // Última compra: 1L por R$ 8,00 = R$ 0,008/ml
      final lastItem = PurchaseItem(
        purchaseId: 1,
        productId: 1,
        productName: 'Suco',
        category: Category.fruitsAndVegetables,
        quantity: 1,
        unit: Unit.liter,
        pricePaid: 8.00,
      );

      // Compra atual: 500ml por R$ 5,00 = R$ 0,01/ml
      final currentItem = PurchaseItem(
        purchaseId: 2,
        productId: 1,
        productName: 'Suco',
        category: Category.fruitsAndVegetables,
        quantity: 500,
        unit: Unit.milliliter,
        pricePaid: 5.00,
      );

      expect(lastItem.pricePerBaseUnit, 0.008);
      expect(currentItem.pricePerBaseUnit, 0.01);
      
      final percentChange = ((currentItem.pricePerBaseUnit - lastItem.pricePerBaseUnit) 
          / lastItem.pricePerBaseUnit) * 100;
      expect(percentChange, 25.0); // 25% mais caro
    });
  });

  group('Product - Essentials', () {
    test('isEssential flag works correctly', () {
      final essentialProduct = Product(
        name: 'Arroz',
        category: Category.pantryBasics,
        isEssential: true,
      );

      final normalProduct = Product(
        name: 'Chocolate',
        category: Category.pantryBasics,
        isEssential: false,
      );

      expect(essentialProduct.isEssential, true);
      expect(normalProduct.isEssential, false);
    });

    test('copyWith preserves essential flag', () {
      final product = Product(
        name: 'Arroz',
        category: Category.pantryBasics,
        isEssential: true,
      );

      final updated = product.copyWith(name: 'Arroz Integral');
      expect(updated.isEssential, true);
      expect(updated.name, 'Arroz Integral');
    });
  });
}