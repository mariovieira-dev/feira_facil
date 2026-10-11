import 'package:flutter/material.dart';

enum Category {
  cleaningProducts('Produtos de limpeza', Icons.cleaning_services),
  fruitsAndVegetables('Frutas e legumes', Icons.local_florist),
  pantryBasics('Despensa / Básico', Icons.kitchen),
  butcherColdCuts('Açougue / Frios', Icons.set_meal),
  dairy('Laticínios', Icons.egg),
  hygiene('Higiene', Icons.face),
  snack('Lanches', Icons.cake),
  others('Outros', Icons.other_houses);

  const Category(this.label, this.icon);
  final String label;
  final IconData icon;

  static Category fromString(String value) {
    return Category.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Category.pantryBasics,
    );
  }
}