enum Unit {
  unit('un', 'Unidade'),
  kilogram('kg', 'Quilograma'),
  gram('g', 'Grama'),
  liter('L', 'Litro'),
  milliliter('ml', 'Mililitro');

  const Unit(this.shortName, this.fullName);
  final String shortName;
  final String fullName;

  static Unit fromString(String value) {
    return Unit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Unit.unit,
    );
  }

  // Converter para unidade base para comparação de preços
  double toBaseUnit(double quantity) {
    switch (this) {
      case Unit.kilogram:
        return quantity * 1000; // para gramas
      case Unit.liter:
        return quantity * 1000; // para mililitros
      default:
        return quantity;
    }
  }

  Unit get baseUnit {
    switch (this) {
      case Unit.kilogram:
        return Unit.gram;
      case Unit.liter:
        return Unit.milliliter;
      default:
        return this;
    }
  }

  String get baseUnitLabel {
    switch (this) {
      case Unit.kilogram:
        return 'g';
      case Unit.liter:
        return 'ml';
      default:
        return shortName;
    }
  }
}