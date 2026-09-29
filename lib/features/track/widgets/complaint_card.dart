import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/complaint.dart';
import '../../../core/theme.dart';

class ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback onTap;

  const ComplaintCard({
    super.key,
    required this.complaint,
    required this.onTap,
  });

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('pothole')) {
      return PhosphorIconsFill.warningOctagon;
    } else if (cat.contains('flood')) {
      return PhosphorIconsFill.drop;
    } else if (cat.contains('drain')) {
      return PhosphorIconsFill.gridFour;
    } else if (cat.contains('crack')) {
      return PhosphorIconsFill.chartLine;
    } else if (cat.contains('manhole')) {
      return PhosphorIconsFill.circle;
    } else {
      return PhosphorIconsFill.warning;
    }
  }

  Color _getSeverityColor(String severity) {
    final sev = severity.toLowerCase();
    if (sev.contains('crit') || sev.contains('danger')) {
      return AppTheme.dangerousRed;
    } else if (sev.contains('high')) {
      return Colors.orange;
    } else if (sev.contains('med')) {
      return AppTheme.secondaryAmber;
    } else {
      return AppTheme.successGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sevColor = _getSeverityColor(complaint.severity);
    final hasMedia = complaint.mediaUrls.isNotEmpty;
    final wardText = complaint.wardName ?? 'Bangalore BBMP';
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(complaint.category),
                      color: AppTheme.primaryTeal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint.category,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(PhosphorIconsFill.mapPin, size: 12, color: AppTheme.primaryTeal),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                wardText,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reported ${timeago.format(complaint.createdAt)}',
                          style: TextStyle(
                            color: subtextColor.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sevColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      complaint.severity.toUpperCase(),
                      style: TextStyle(
                        color: sevColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              if (complaint.description != null && complaint.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  complaint.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
              if (hasMedia) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    complaint.mediaUrls.first,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        complaint.status.toLowerCase().contains('cancel') ||
                                complaint.status.toLowerCase().contains('reject') ||
                                complaint.status.toLowerCase().contains('fake') ||
                                complaint.status.toLowerCase() == 'merged'
                            ? PhosphorIconsFill.xCircle
                            : complaint.status.toLowerCase() == 'completed' ||
                                    complaint.status.toLowerCase() == 'resolved'
                                ? PhosphorIconsFill.checkCircle
                                : PhosphorIconsFill.circle,
                        size: 14,
                        color: complaint.status.toLowerCase().contains('cancel') ||
                                complaint.status.toLowerCase().contains('reject') ||
                                complaint.status.toLowerCase().contains('fake') ||
                                complaint.status.toLowerCase() == 'merged'
                            ? Colors.redAccent
                            : complaint.status.toLowerCase() == 'completed' ||
                                    complaint.status.toLowerCase() == 'resolved'
                                ? AppTheme.successGreen
                                : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        complaint.status.toLowerCase().contains('reject') ||
                                complaint.status.toLowerCase().contains('cancel') ||
                                complaint.status.toLowerCase().contains('fake')
                            ? 'Status: Cancelled (AI Rejected)'
                            : complaint.status.toLowerCase() == 'merged'
                                ? 'Status: Merged / Closed'
                                : 'Status: ${complaint.status}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: complaint.status.toLowerCase().contains('reject') ||
                                  complaint.status.toLowerCase().contains('cancel') ||
                                  complaint.status.toLowerCase().contains('fake')
                              ? Colors.redAccent
                              : subtextColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(PhosphorIconsFill.thumbsUp, size: 14, color: AppTheme.secondaryAmber),
                      const SizedBox(width: 4),
                      Text(
                        '${complaint.upvoteCount} votes',
                        style: TextStyle(fontSize: 12, color: subtextColor),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
