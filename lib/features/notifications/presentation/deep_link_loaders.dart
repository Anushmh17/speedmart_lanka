import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speedmart_lanka/features/proposals/data/proposal_repository.dart';
import 'package:speedmart_lanka/features/proposals/presentation/screens/customer_proposal_details_screen.dart';
import 'package:speedmart_lanka/features/requests/data/request_repository.dart';
import 'package:speedmart_lanka/features/requests/presentation/screens/request_details_screen.dart';
import 'package:speedmart_lanka/features/orders/data/order_repository.dart';
import 'package:speedmart_lanka/features/orders/presentation/screens/order_tracking_screen.dart';

class ProposalDeepLinkLoader extends ConsumerStatefulWidget {
  final String proposalId;
  const ProposalDeepLinkLoader({super.key, required this.proposalId});

  @override
  ConsumerState<ProposalDeepLinkLoader> createState() => _ProposalDeepLinkLoaderState();
}

class _ProposalDeepLinkLoaderState extends ConsumerState<ProposalDeepLinkLoader> {
  bool _loading = true;
  dynamic _proposal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await ProposalRepository.instance.ensureInitialized();
      final p = await ProposalRepository.instance.getProposalById(widget.proposalId);
      setState(() {
        _proposal = p;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_proposal == null) return const Scaffold(body: Center(child: Text('Proposal not found')));
    return CustomerProposalDetailsScreen(proposal: _proposal, requestId: _proposal.requestId);
  }
}

class RequestDeepLinkLoader extends ConsumerStatefulWidget {
  final String requestId;
  const RequestDeepLinkLoader({super.key, required this.requestId});

  @override
  ConsumerState<RequestDeepLinkLoader> createState() => _RequestDeepLinkLoaderState();
}

class _RequestDeepLinkLoaderState extends ConsumerState<RequestDeepLinkLoader> {
  bool _loading = true;
  dynamic _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await RequestRepository.instance.ensureInitialized();
      final r = await RequestRepository.instance.getRequestById(widget.requestId);
      setState(() {
        _request = r;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_request == null) return const Scaffold(body: Center(child: Text('Request not found')));
    return RequestDetailsScreen(request: _request);
  }
}

class OrderDeepLinkLoader extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDeepLinkLoader({super.key, required this.orderId});

  @override
  ConsumerState<OrderDeepLinkLoader> createState() => _OrderDeepLinkLoaderState();
}

class _OrderDeepLinkLoaderState extends ConsumerState<OrderDeepLinkLoader> {
  bool _loading = true;
  dynamic _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await OrderRepository.instance.ensureInitialized();
      final o = await OrderRepository.instance.getOrderById(widget.orderId);
      setState(() {
        _order = o;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_order == null) return const Scaffold(body: Center(child: Text('Order not found')));
    return OrderTrackingScreen(order: _order);
  }
}
