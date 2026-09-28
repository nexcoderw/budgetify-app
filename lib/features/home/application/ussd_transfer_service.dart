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

  bool get isSupported {
    return !kIsWeb &&
        defaultTargetPlatform ==
            TargetPlatform.android;
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
            'Direct USSD transfers are currently available on Android only.',
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

    final recipient =
        recipientType ==
                TransactionRecipientType.phone
            ? _normalizePhoneForUssd(
                receiverIdentifier,
              )
            : _normalizeBankAccount(
                receiverIdentifier,
              );

    final prefix =
        transferType ==
                TransactionTransferType.momoToMomo
            ? _momoTransferPrefix
            : _ekashTransferPrefix;

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
}
