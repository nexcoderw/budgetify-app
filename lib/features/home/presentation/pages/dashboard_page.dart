import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../application/transaction_analytics_period.dart';
import '../../application/transaction_service.dart';
import '../../data/models/transaction_analytics_models.dart';
import '../widgets/dashboard/dashboard_activity_sections.dart';
import '../widgets/dashboard/dashboard_breakdown_sections.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/dashboard_states.dart';
import '../widgets/dashboard/dashboard_summary_section.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.transactionService,
    this.refreshToken = 0,
  });

  final TransactionService? transactionService;

  final int refreshToken;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final TransactionService _transactionService;

  TransactionAnalyticsPeriodPreset _selectedPeriod =
      TransactionAnalyticsPeriodPreset.thisMonth;

  TransactionAnalytics? _analytics;

  String? _errorMessage;

  bool _isLoading = true;

  int _requestId = 0;

  @override
  void initState() {
    super.initState();

    _transactionService =
        widget.transactionService ?? TransactionService.createDefault();

    unawaited(_loadAnalytics());
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_loadAnalytics(preserveCurrent: true));
    }
  }

  Future<void> _loadAnalytics({bool preserveCurrent = false}) async {
    final requestId = ++_requestId;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;

        if (!preserveCurrent) {
          _analytics = null;
        }
      });
    }

    final range = _selectedPeriod.rangeFor(DateTime.now());

    try {
      final analytics = await _transactionService.analytics(
        from: range.from,
        to: range.to,
      );

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _analytics = analytics;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not load your money analytics.';
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectPeriod(TransactionAnalyticsPeriodPreset period) {
    if (period == _selectedPeriod) {
      return;
    }

    setState(() {
      _selectedPeriod = period;
    });

    unawaited(_loadAnalytics());
  }

  void _refreshAnalytics() {
    unawaited(_loadAnalytics(preserveCurrent: true));
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _analytics;

    if (_isLoading && analytics == null) {
      return const DashboardSkeleton();
    }

    if (analytics == null) {
      return DashboardError(
        message: _errorMessage ?? 'Could not load money analytics.',
        onRetry: () {
          unawaited(_loadAnalytics());
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardHeader(
          selectedPeriod: _selectedPeriod,
          period: analytics.period,
          isLoading: _isLoading,
          onPeriodSelected: _selectPeriod,
          onRefresh: _refreshAnalytics,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          DashboardRefreshErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 18),
        DashboardSummarySection(analytics: analytics),
        const SizedBox(height: 16),
        DashboardStatusSection(summary: analytics.summary),
        const SizedBox(height: 16),
        DashboardReceivedClassificationSection(
          classifications: analytics.receivedClassifications,
          currency: analytics.currency,
        ),
        const SizedBox(height: 16),
        DashboardReceivedEvidenceSection(evidence: analytics.receivedEvidence),
        const SizedBox(height: 16),
        DashboardOutgoingConfirmationSection(
          confirmation: analytics.confirmation,
        ),
        const SizedBox(height: 16),
        DashboardCategorySection(
          categories: analytics.categories,
          currency: analytics.currency,
        ),
        const SizedBox(height: 16),
        DashboardTransferTypeSection(
          transferTypes: analytics.transferTypes,
          currency: analytics.currency,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
