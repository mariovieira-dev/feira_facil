import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormat = NumberFormat.compactCurrency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 1,
  );

  static String format(double value) {
    return _currencyFormat.format(value);
  }

  static String formatCompact(double value) {
    return _compactFormat.format(value);
  }

  static String formatPricePerUnit(double price, String unit) {
    return '${format(price)}/$unit';
  }
}

class DateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'pt_BR');
  static final DateFormat _shortDateFormat = DateFormat('dd/MM', 'pt_BR');
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'pt_BR');

  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${formatTime(date)}';
  }
}

class NumberFormatter {
  static final NumberFormat _numberFormat = NumberFormat('#,##0.###', 'pt_BR');
  static final NumberFormat _percentFormat = NumberFormat.percentPattern('pt_BR');

  static String format(double value, {int? decimals}) {
    if (decimals != null) {
      return NumberFormat('#,##0.${'#' * decimals}', 'pt_BR').format(value);
    }
    return _numberFormat.format(value);
  }

  static String formatPercent(double value) {
    return _percentFormat.format(value);
  }

  static String formatQuantity(double quantity, String unit) {
    return '${format(quantity)} $unit';
  }
}