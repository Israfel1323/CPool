import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/verification_request.dart';
import '../providers/operations_provider.dart';

class VerificationDetailsPage extends StatefulWidget {
  const VerificationDetailsPage({super.key, required this.verificationId});

  final String verificationId;

  @override
  State<VerificationDetailsPage> createState() =>
      _VerificationDetailsPageState();
}

class _VerificationDetailsPageState extends State<VerificationDetailsPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OperationsProvider>().loadVerificationRequest(
        widget.verificationId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Verification Details'),
      ),
      body: Consumer<OperationsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingDetails) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = provider.selectedRequest;

          if (request == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load verification request.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        provider.loadVerificationRequest(widget.verificationId);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _DetailsContent(request: request, provider: provider);
        },
      ),
    );
  }
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({required this.request, required this.provider});

  final VerificationRequest request;
  final OperationsProvider provider;

  bool get isDriver => request.verificationType == 'driver';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusCard(request: request),

          const SizedBox(height: 20),

          _SectionCard(
            title: 'Applicant',
            icon: Icons.person_outline_rounded,
            children: [
              _DetailRow(
                label: 'Name',
                value: request.fullName ?? 'Not available',
              ),
              _DetailRow(
                label: 'Email',
                value: request.email ?? 'Not available',
              ),
              _DetailRow(label: 'Type', value: isDriver ? 'Driver' : 'Student'),
            ],
          ),

          const SizedBox(height: 16),

          if (isDriver)
            _DriverDetailsCard(request: request)
          else
            _StudentDetailsCard(request: request),

          const SizedBox(height: 24),

          if (request.status == 'pending')
            _ActionButtons(request: request, provider: provider),

          if (request.status == 'rejected' &&
              request.rejectionReason != null &&
              request.rejectionReason!.isNotEmpty)
            _SectionCard(
              title: 'Rejection Reason',
              icon: Icons.info_outline_rounded,
              children: [
                Text(
                  request.rejectionReason!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.request});

  final VerificationRequest request;

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == 'pending';
    final isApproved = request.status == 'approved';

    final color = isPending
        ? Colors.orange
        : isApproved
        ? Colors.green
        : Colors.red;

    final icon = isPending
        ? Icons.pending_actions_rounded
        : isApproved
        ? Icons.check_circle_outline_rounded
        : Icons.cancel_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verification Status',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.status.toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentDetailsCard extends StatelessWidget {
  const _StudentDetailsCard({required this.request});

  final VerificationRequest request;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Student Verification',
      icon: Icons.school_outlined,
      children: [
        _DetailRow(
          label: 'Institution',
          value: request.institutionName ?? 'Not available',
        ),

        _DetailRow(
          label: 'Reference ID',
          value: request.referenceId ?? 'Not available',
        ),

        _DocumentLink(
          label: 'College ID Front',
          url: request.idCardFrontUrl,
          verificationId: request.id,
          side: 'front',
        ),

        _DocumentLink(
          label: 'College ID Back',
          url: request.idCardBackUrl,
          verificationId: request.id,
          side: 'back',
        ),
      ],
    );
  }
}

class _DriverDetailsCard extends StatelessWidget {
  const _DriverDetailsCard({required this.request});

  final VerificationRequest request;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Driver Verification',
      icon: Icons.directions_car_outlined,
      children: [
        _DetailRow(
          label: 'Vehicle',
          value: request.vehicleName ?? 'Not available',
        ),
        _DetailRow(
          label: 'Vehicle Type',
          value: request.vehicleType ?? 'Not available',
        ),
        _DetailRow(
          label: 'Vehicle Number',
          value: request.vehicleNumber ?? 'Not available',
        ),
        _DetailRow(
          label: 'Vehicle Color',
          value: request.vehicleColor ?? 'Not available',
        ),
        _DocumentLink(
          label: 'License Front',
          url: request.licenseFrontUrl,
          verificationId: request.id,
          side: 'front',
        ),
        _DocumentLink(
          label: 'License Back',
          url: request.licenseBackUrl,
          verificationId: request.id,
          side: 'back',
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 21),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _DocumentLink extends StatelessWidget {
  const _DocumentLink({
    required this.label,
    required this.url,
    required this.verificationId,
    required this.side,
  });

  final String label;
  final String? url;
  final String verificationId;
  final String side;
  Future<void> _openDocument(BuildContext context) async {
    if (url == null || url!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document is not available.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              actions: [
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 28),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
            body: FutureBuilder<String>(
              future: dialogContext
                  .read<OperationsProvider>()
                  .getVerificationDocumentUrl(
                    verificationId: verificationId,
                    side: side,
                  ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Loading document...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to load document',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final signedUrl = snapshot.data;

                if (signedUrl == null || signedUrl.isEmpty) {
                  return const Center(
                    child: Text(
                      'Document URL was not returned.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                return Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.network(
                      signedUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Unable to display this document.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = url != null && url!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (hasDocument)
            TextButton.icon(
              onPressed: () => _openDocument(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('View'),
            )
          else
            Text('Not available', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.request, required this.provider});

  final VerificationRequest request;
  final OperationsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isUpdatingVerification) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _reject(context),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _approve(context),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Approve'),
          ),
        ),
      ],
    );
  }

  Future<void> _approve(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve verification?'),
          content: const Text('This will approve the verification request.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await provider.approveVerification(request.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification approved successfully.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to approve: $e')));
    }
  }

  Future<void> _reject(BuildContext context) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject verification'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Enter the reason for rejection',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null || reason.trim().isEmpty || !context.mounted) {
      return;
    }

    try {
      await provider.rejectVerification(request.id, reason.trim());

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification rejected successfully.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to reject: $e')));
    }
  }
}
