import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/transaction_service.dart';
import '../../application/transaction_sms_reconciliation_service.dart';
import '../../data/models/provider_sms_message.dart';
import '../../data/models/transaction_models.dart';
import '../widgets/transaction_detail/sent_transaction_detail_content.dart';
import '../widgets/transaction_detail/transaction_detail_frame.dart';
import '../widgets/transaction_manual_confirmation_sheet.dart';

class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({
    super.key,
    required this.transactionId,
    this.transactionService,
    this.smsReconciliationService,
  });

  final String transactionId;

  final TransactionService? transactionService;

  final TransactionSmsReconciliationService? smsReconciliationService;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  late final TransactionService _transactionService;

  late final TransactionSmsReconciliationService _smsReconciliationService;

  TransactionDetail? _detail;

  bool _isLoading = true;

  bool _isCheckingStatus = false;

  String? _errorMessage;

  String? _reconciliationMessage;

  DateTime? _lastCheckedAt;

  @override
  void initState() {
    super.initState();

    _transactionService =
        widget.transactionService ?? TransactionService.createDefault();

    _smsReconciliationService =
        widget.smsReconciliationService ??
        TransactionSmsReconciliationService.createDefault(
          transactionService: _transactionService,
        );

    unawaited(_load());
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final detail = await _transactionService.getDetail(
        transactionId: widget.transactionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not load transaction details.';
      });
    } finally {
      if (mounted && showLoader) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkTransactionStatus() async {
    if (_isCheckingStatus) {
      return;
    }

    final detail = _detail;

    if (detail == null) {
      return;
    }

    setState(() {
      _isCheckingStatus = true;
      _reconciliationMessage = null;
    });

    try {
      var result = await _smsReconciliationService.reconcileTransaction(
        detail.transaction,
      );

      if (result.outcome == TransactionReconciliationOutcome.permissionDenied) {
        final permission = await _smsReconciliationService.requestPermission();

        if (!mounted) {
          return;
        }

        if (permission != DeviceSmsPermission.granted) {
          setState(() {
            _lastCheckedAt = result.checkedAt;
            _reconciliationMessage =
                'SMS access is disabled. The transaction remains unchanged.';
          });

          AppToast.error(
            context,
            title: 'SMS access required',
            description:
                'Enable SMS access to let Budgetify check MTN transaction evidence.',
          );

          return;
        }

        result = await _smsReconciliationService.reconcileTransaction(
          detail.transaction,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _lastCheckedAt = result.checkedAt;
        _reconciliationMessage = _messageForResult(result);
      });

      switch (result.outcome) {
        case TransactionReconciliationOutcome.updated:
          await _load(showLoader: false);

          if (!mounted) {
            return;
          }

          final updated = result.transaction;

          if (updated.status == TransactionStatus.completed) {
            AppToast.success(
              context,
              title: 'Transaction updated',
              description:
                  'Budgetify matched MTN SMS evidence to this transaction.',
            );
          } else {
            AppToast.info(
              context,
              title: 'Transaction status updated',
              description:
                  'MTN SMS evidence indicates ${updated.status.label.toLowerCase()}.',
            );
          }

        case TransactionReconciliationOutcome.alreadyResolved:
          await _load(showLoader: false);

        case TransactionReconciliationOutcome.noMatch:
          AppToast.info(
            context,
            title: 'No matching evidence',
            description:
                'Budgetify found no matching MTN transaction message for this transaction. Its current status was not changed.',
          );

        case TransactionReconciliationOutcome.ambiguous:
          AppToast.info(
            context,
            title: 'Evidence needs review',
            description:
                'More than one MTN message could match this transaction. Budgetify did not guess or change its status.',
          );

        case TransactionReconciliationOutcome.unsupported:
          AppToast.info(
            context,
            title: 'Automatic check unavailable',
            description:
                'Automatic SMS evidence matching is currently available on Android only.',
          );

        case TransactionReconciliationOutcome.permissionDenied:
          break;
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not check transaction',
        description: error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not check transaction',
        description:
            'Budgetify could not safely reconcile this transaction. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  Future<void> _confirmTransactionManually() async {
    if (_isCheckingStatus) {
      return;
    }

    final detail = _detail;

    if (detail == null) {
      return;
    }

    final transaction = detail.transaction;

    if (transaction.status != TransactionStatus.pending &&
        transaction.status != TransactionStatus.processing) {
      return;
    }

    final choice = await showManualTransactionConfirmationSheet(
      context,
      transaction: transaction,
    );

    if (!mounted || choice == null) {
      return;
    }

    if (choice == ManualTransactionConfirmationChoice.notSure) {
      AppToast.info(
        context,
        title: 'Transaction unchanged',
        description: 'The payment remains open until you confirm its result.',
      );

      return;
    }

    final status = choice.status;

    if (status == null) {
      return;
    }

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final updated = await _transactionService.recordManualResult(
        transactionId: transaction.id,
        status: status,
      );

      await _load(showLoader: false);

      if (!mounted) {
        return;
      }

      if (updated.status == TransactionStatus.completed) {
        AppToast.success(
          context,
          title: 'Payment confirmed',
          description: 'The transaction was manually confirmed as successful.',
        );
      } else {
        AppToast.info(
          context,
          title: 'Payment result recorded',
          description: 'The transaction was manually confirmed as failed.',
        );
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      await _load(showLoader: false);

      if (!mounted) {
        return;
      }

      final latest = _detail?.transaction;

      if (latest != null &&
          latest.status != TransactionStatus.pending &&
          latest.status != TransactionStatus.processing) {
        AppToast.info(
          context,
          title: 'Transaction refreshed',
          description: 'The transaction already has a final status.',
        );

        return;
      }

      AppToast.error(
        context,
        title: 'Could not record result',
        description: error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not record result',
        description:
            'Budgetify could not save your manual confirmation. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  String _messageForResult(TransactionReconciliationResult result) {
    return switch (result.outcome) {
      TransactionReconciliationOutcome.updated =>
        'Matching MTN SMS evidence was found and the transaction was updated.',
      TransactionReconciliationOutcome.alreadyResolved =>
        'This transaction already has a final status.',
      TransactionReconciliationOutcome.noMatch =>
        'No matching MTN SMS evidence was found. This does not mean the transfer failed.',
      TransactionReconciliationOutcome.ambiguous =>
        'Multiple MTN messages could match. Budgetify left the transaction unchanged rather than guessing.',
      TransactionReconciliationOutcome.permissionDenied =>
        'SMS access is required to check transaction evidence.',
      TransactionReconciliationOutcome.unsupported =>
        'Automatic SMS evidence matching is unavailable on this device.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return TransactionDetailPageFrame(
      onBack: () {
        Navigator.of(context).pop();
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const TransactionDetailLoading();
    }

    final error = _errorMessage;

    if (error != null) {
      return TransactionDetailError(
        message: error,
        onRetry: () {
          unawaited(_load());
        },
      );
    }

    final detail = _detail;

    if (detail == null) {
      return const SizedBox.shrink();
    }

    return SentTransactionDetailContent(
      detail: detail,
      isCheckingStatus: _isCheckingStatus,
      lastCheckedAt: _lastCheckedAt,
      reconciliationMessage: _reconciliationMessage,
      onCheckStatus: () {
        unawaited(_checkTransactionStatus());
      },
      onConfirmManually: () {
        unawaited(_confirmTransactionManually());
      },
    );
  }
}
