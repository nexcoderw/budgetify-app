enum TransactionTransferType {
  momoToMomo(
    apiValue: 'MOMO_TO_MOMO',
    label: 'MTN MoMo',
  ),
  momoToEkash(
    apiValue: 'MOMO_TO_EKASH',
    label: 'eKash',
  ),
  momoPay(
    apiValue: 'MOMO_PAY',
    label: 'MoMo Pay',
  );

  const TransactionTransferType({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;
}

enum TransactionRecipientType {
  phone('PHONE'),
  bankAccount('BANK_ACCOUNT'),
  momoCode('MOMO_CODE');

  const TransactionRecipientType(this.apiValue);

  final String apiValue;
}

enum TransactionCategory {
  transport('TRANSPORT'),
  groceries('GROCERIES'),
  bills('BILLS'),
  rent('RENT'),
  healthcare('HEALTHCARE'),
  education('EDUCATION'),
  foodDining('FOOD_DINING'),
  shopping('SHOPPING'),
  family('FAMILY'),
  entertainment('ENTERTAINMENT'),
  other('OTHER');

  const TransactionCategory(this.apiValue);

  final String apiValue;

  static TransactionCategory fromLabel(String label) {
    return switch (label.trim().toLowerCase()) {
      'transport' => TransactionCategory.transport,
      'groceries' => TransactionCategory.groceries,
      'bills' => TransactionCategory.bills,
      'rent' => TransactionCategory.rent,
      'health' || 'healthcare' =>
        TransactionCategory.healthcare,
      'education' => TransactionCategory.education,
      'dining' || 'food & dining' =>
        TransactionCategory.foodDining,
      'shopping' => TransactionCategory.shopping,
      'family' => TransactionCategory.family,
      'entertainment' =>
        TransactionCategory.entertainment,
      _ => TransactionCategory.other,
    };
  }
}

TransactionRecipientType inferTransactionRecipientType(
  String value,
) {
  final digits = value.replaceAll(
    RegExp(r'\D'),
    '',
  );

  final isPhone =
      RegExp(r'^07\d{8}$').hasMatch(digits) ||
      RegExp(r'^2507\d{8}$').hasMatch(digits) ||
      RegExp(r'^7\d{8}$').hasMatch(digits);

  if (isPhone) {
    return TransactionRecipientType.phone;
  }

  if (RegExp(r'^\d{3,9}$').hasMatch(digits)) {
    return TransactionRecipientType.momoCode;
  }

  return TransactionRecipientType.bankAccount;
}

bool isValidTransactionRecipient(
  String value,
  TransactionRecipientType type,
) {
  final digits = value.replaceAll(
    RegExp(r'\D'),
    '',
  );

  if (type == TransactionRecipientType.phone) {
    return RegExp(r'^07\d{8}$').hasMatch(digits) ||
        RegExp(r'^2507\d{8}$').hasMatch(digits) ||
        RegExp(r'^7\d{8}$').hasMatch(digits);
  }

  if (type == TransactionRecipientType.momoCode) {
    return RegExp(r'^\d{3,12}$').hasMatch(digits);
  }

  return RegExp(r'^\d{6,34}$').hasMatch(digits);
}

TransactionTransferType inferTransactionTransferType({
  required String recipientIdentifier,
  required TransactionRecipientType recipientType,
}) {
  if (recipientType == TransactionRecipientType.momoCode) {
    return TransactionTransferType.momoPay;
  }

  if (recipientType == TransactionRecipientType.bankAccount) {
    return TransactionTransferType.momoToEkash;
  }

  final digits = recipientIdentifier.replaceAll(
    RegExp(r'\D'),
    '',
  );
  final localNumber = digits.startsWith('250')
      ? '0${digits.substring(3)}'
      : digits.startsWith('7')
          ? '0$digits'
          : digits;

  final isMtnNumber = localNumber.startsWith('078') ||
      localNumber.startsWith('079');

  return isMtnNumber
      ? TransactionTransferType.momoToMomo
      : TransactionTransferType.momoToEkash;
}

class TransactionQuote {
  const TransactionQuote({
    required this.transferType,
    required this.currency,
    required this.amount,
    required this.feeAmount,
    required this.totalAmount,
    required this.tariffVersion,
    required this.tariffSource,
  });

  factory TransactionQuote.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransactionQuote(
      transferType: json['transferType'] as String,
      currency: json['currency'] as String,
      amount: json['amount'] as int,
      feeAmount: json['feeAmount'] as int,
      totalAmount: json['totalAmount'] as int,
      tariffVersion: json['tariffVersion'] as String,
      tariffSource: json['tariffSource'] as String,
    );
  }

  final String transferType;
  final String currency;
  final int amount;
  final int feeAmount;
  final int totalAmount;
  final String tariffVersion;
  final String tariffSource;
}

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.reference,
    required this.transferType,
    required this.status,
    required this.category,
    required this.currency,
    required this.amount,
    required this.feeAmount,
    required this.totalAmount,
    required this.recipientType,
    required this.receiverIdentifier,
    required this.receiverName,
    required this.createdAt,
  });

  factory PaymentTransaction.fromJson(
    Map<String, dynamic> json,
  ) {
    return PaymentTransaction(
      id: json['id'] as String,
      reference: json['reference'] as String,
      transferType: json['transferType'] as String,
      status: json['status'] as String,
      category: json['category'] as String,
      currency: json['currency'] as String,
      amount: json['amount'] as int,
      feeAmount: json['feeAmount'] as int,
      totalAmount: json['totalAmount'] as int,
      recipientType: json['recipientType'] as String,
      receiverIdentifier:
          json['receiverIdentifier'] as String,
      receiverName: json['receiverName'] as String?,
      createdAt: DateTime.parse(
        json['createdAt'] as String,
      ),
    );
  }

  final String id;
  final String reference;
  final String transferType;
  final String status;
  final String category;
  final String currency;
  final int amount;
  final int feeAmount;
  final int totalAmount;
  final String recipientType;
  final String receiverIdentifier;
  final String? receiverName;
  final DateTime createdAt;
}
