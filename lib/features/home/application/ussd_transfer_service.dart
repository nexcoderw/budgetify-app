import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models/transaction_models.dart';

class UssdTransferService {
  const UssdTransferService();

  static const MethodChannel _channel =
      MethodChannel('budgetify/ussd');

  static const String _momoTransferPrefix =
      '*182*1*1';

  static const String _ekashTransferPrefix =
      '*182*1*2';

  static const String _momoPayPrefix = '*182*8*1';

  bool get isSupported {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  Future<bool> prepare() async {
    if (!isSupported) {
      return false;
    }

    return await _channel.invokeMethod<bool>(
          'prepareUssd',
        ) ??
        false;
  }

  Future<void> launch({
    required TransactionTransferType transferType,
    required TransactionRecipientType recipientType,
    required String receiverIdentifier,
    required int amount,
  }) async {
    if (!isSupported) {
      throw PlatformException(
        code: 'unsupported_platform',
        message:
            'USSD transfers are only available on Android and iPhone.',
      );
    }

    final code = buildCode(
      transferType: transferType,
      recipientType: recipientType,
      receiverIdentifier: receiverIdentifier,
      amount: amount,
    );

    await _channel.invokeMethod<void>(
      'launchUssd',
      <String, dynamic>{
        'code': code,
      },
    );
  }

  String buildCode({
    required TransactionTransferType transferType,
    required TransactionRecipientType recipientType,
    required String receiverIdentifier,
    required int amount,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be greater than zero.',
      );
    }

    if (
        transferType ==
            TransactionTransferType.momoToMomo &&
        recipientType !=
            TransactionRecipientType.phone) {
      throw ArgumentError(
        'MoMo transfers require a phone recipient.',
      );
    }

    if (
        transferType == TransactionTransferType.momoPay &&
        recipientType != TransactionRecipientType.momoCode) {
      throw ArgumentError(
        'MoMo Pay requires a MoMo merchant code.',
      );
    }

    if (
        recipientType == TransactionRecipientType.momoCode &&
        transferType != TransactionTransferType.momoPay) {
      throw ArgumentError(
        'MoMo merchant codes can only be used with MoMo Pay.',
      );
    }

    final recipient = switch (recipientType) {
      TransactionRecipientType.phone => _normalizePhoneForUssd(
        receiverIdentifier,
      ),
      TransactionRecipientType.bankAccount => _normalizeBankAccount(
        receiverIdentifier,
      ),
      TransactionRecipientType.momoCode => _normalizeMomoCode(
        receiverIdentifier,
      ),
    };

    final prefix = switch (transferType) {
      TransactionTransferType.momoToMomo => _momoTransferPrefix,
      TransactionTransferType.momoToEkash => _ekashTransferPrefix,
      TransactionTransferType.momoPay => _momoPayPrefix,
    };

    return '$prefix*$recipient*$amount#';
  }

  String _normalizePhoneForUssd(
    String value,
  ) {
    final digits = value.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (RegExp(r'^07\d{8}$').hasMatch(digits)) {
      return digits;
    }

    if (
        RegExp(r'^2507\d{8}$')
            .hasMatch(digits)) {
      return '0${digits.substring(3)}';
    }

    if (RegExp(r'^7\d{8}$').hasMatch(digits)) {
      return '0$digits';
    }

    throw ArgumentError(
      'Invalid Rwanda phone number.',
    );
  }

  String _normalizeBankAccount(
    String value,
  ) {
    final digits = value.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (
        !RegExp(r'^\d{6,34}$')
            .hasMatch(digits)) {
      throw ArgumentError(
        'Invalid bank account number.',
      );
    }

    return digits;
  }

  String _normalizeMomoCode(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (!RegExp(r'^\d{3,12}$').hasMatch(digits)) {
      throw ArgumentError(
        'MoMo merchant code must contain between 3 and 12 digits.',
      );
    }

    return digits;
  }
}
