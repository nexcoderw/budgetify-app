import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/received_transaction_service.dart';
import '../../data/models/received_transaction_models.dart';
import '../widgets/transaction_detail/received_transaction_detail_content.dart';
import '../widgets/transaction_detail/transaction_detail_frame.dart';

class ReceivedTransactionDetailPage extends StatefulWidget {
  const ReceivedTransactionDetailPage({
    super.key,
    required this.receivedTransactionId,
    this.receivedTransactionService,
  });

  final String receivedTransactionId;

  final ReceivedTransactionService? receivedTransactionService;

  @override
  State<ReceivedTransactionDetailPage> createState() =>
      _ReceivedTransactionDetailPageState();
}

class _ReceivedTransactionDetailPageState
    extends State<ReceivedTransactionDetailPage> {
  late final ReceivedTransactionService _service;

  ReceivedTransaction? _transaction;

  bool _isLoading = true;

  bool _isUpdatingClassification = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _service =
        widget.receivedTransactionService ??
        ReceivedTransactionService.createDefault();

    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final transaction = await _service.getDetail(
        receivedTransactionId: widget.receivedTransactionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _transaction = transaction;
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
        _errorMessage = 'Could not load received transaction details.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _chooseClassification() async {
    if (_isUpdatingClassification) {
      return;
    }

    final transaction = _transaction;

    if (transaction == null) {
      return;
    }

    final selected = await showReceivedTransactionClassificationSheet(
      context,
      selected: transaction.classification,
    );

    if (!mounted ||
        selected == null ||
        selected == transaction.classification) {
      return;
    }

    await _updateClassification(selected);
  }

  Future<void> _updateClassification(
    ReceivedTransactionClassification classification,
  ) async {
    if (_isUpdatingClassification) {
      return;
    }

    setState(() {
      _isUpdatingClassification = true;
    });

    try {
      final updated = await _service.updateClassification(
        receivedTransactionId: widget.receivedTransactionId,
        classification: classification,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _transaction = updated;
      });

      AppToast.success(
        context,
        title: 'Classification updated',
        description:
            'This received payment is now classified as ${updated.classification.label.toLowerCase()}.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not update classification',
        description: error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not update classification',
        description:
            'Budgetify could not save this classification. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingClassification = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TransactionDetailPageFrame(
      onBack: () {
        if (_isUpdatingClassification) {
          return;
        }

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

    final transaction = _transaction;

    if (transaction == null) {
      return const SizedBox.shrink();
    }

    return ReceivedTransactionDetailContent(
      transaction: transaction,
      isUpdatingClassification: _isUpdatingClassification,
      onChangeClassification: () {
        unawaited(_chooseClassification());
      },
    );
  }
}
