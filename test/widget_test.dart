import 'package:flutter_test/flutter_test.dart';
import 'package:feira_facil/models/category.dart';
import 'package:feira_facil/models/unit.dart';

void main() {
  group('Unit', () {
    test('converte kg para g e L para ml', () {
      expect(Unit.kilogram.toBaseUnit(2), 2000);
      expect(Unit.liter.toBaseUnit(1.5), 1500);
      expect(Unit.unit.toBaseUnit(3), 3);
    });

    test('unidade base e rótulo', () {
      expect(Unit.kilogram.baseUnit, Unit.gram);
      expect(Unit.liter.baseUnitLabel, 'ml');
      expect(Unit.unit.baseUnitLabel, 'un');
    });

    test('fromString usa "unidade" como padrão', () {
      expect(Unit.fromString('gram'), Unit.gram);
      expect(Unit.fromString('invalido'), Unit.unit);
    });
  });

  group('Category', () {
    test('fromString usa "Despensa / Básico" como padrão', () {
      expect(Category.fromString('dairy'), Category.dairy);
      expect(Category.fromString('invalido'), Category.pantryBasics);
    });

    test('possui as 6 categorias do app', () {
      expect(Category.values.length, 6);
    });
  });
}
