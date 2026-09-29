import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../services/exif_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/db_service.dart';

/// 1. Step Indicator Widget
class ReportFlowStepIndicator extends StatelessWidget {
  final int currentStep; // 0 to 4
  final int totalSteps;

  const ReportFlowStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 5,
  });

  static const List<String> stepLabels = [
    'Details',
    'Authenticity',
    'Duplicates',
    'AI Vision',
    'Priority',
  ];

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.getTextColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps, (index) {
              final isPassed = index < currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        decoration: BoxDecoration(
                          color: isPassed
                              ? AppTheme.primaryTeal
                              : isCurrent
                                  ? AppTheme.secondaryAmber
                                  : (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white12
                                      : Colors.black12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    if (index < totalSteps - 1) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${currentStep + 1} of $totalSteps: ${stepLabels[currentStep]}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                '${((currentStep + 1) / totalSteps * 100).toInt()}% Completed',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. Media Upload & Preview Card Widget (Supports Photo & Short Video with Retake/Change)
class MediaUploadPreviewCard extends StatelessWidget {
  final XFile? mediaFile;
  final VoidCallback onTakePhoto;
  final VoidCallback onRecordVideo;
  final VoidCallback onPickGalleryPhoto;
  final VoidCallback onPickGalleryVideo;
  final VoidCallback onClearMedia;

  const MediaUploadPreviewCard({
    super.key,
    required this.mediaFile,
    required this.onTakePhoto,
    required this.onRecordVideo,
    required this.onPickGalleryPhoto,
    required this.onPickGalleryVideo,
    required this.onClearMedia,
  });

  bool get _isVideo {
    if (mediaFile == null) return false;
    final path = mediaFile!.path.toLowerCase();
    return path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.mkv') || path.endsWith('.avi');
  }

  void _showMediaPickerSheet(BuildContext context) {
    final cardColor = AppTheme.getCardColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Capture or Upload Evidence',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload a clear photo or short video (max 30s) of the road hazard',
                style: TextStyle(fontSize: 12, color: subtextColor),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildPickerOption(
                      context,
                      icon: PhosphorIconsFill.camera,
                      label: 'Take Photo',
                      color: AppTheme.primaryTeal,
                      onTap: () {
                        Navigator.pop(ctx);
                        onTakePhoto();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPickerOption(
                      context,
                      icon: PhosphorIconsFill.videoCamera,
                      label: 'Record Video',
                      color: AppTheme.secondaryAmber,
                      onTap: () {
                        Navigator.pop(ctx);
                        onRecordVideo();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPickerOption(
                      context,
                      icon: PhosphorIconsFill.image,
                      label: 'Gallery Photo',
                      color: AppTheme.infoBlue,
                      onTap: () {
                        Navigator.pop(ctx);
                        onPickGalleryPhoto();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPickerOption(
                      context,
                      icon: PhosphorIconsFill.filmStrip,
                      label: 'Gallery Video',
                      color: Colors.purpleAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        onPickGalleryVideo();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    if (mediaFile != null) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: AppTheme.softShadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _isVideo
                        ? Container(
                            color: Colors.black87,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(PhosphorIconsFill.playCircle, size: 56, color: Colors.white),
                                  SizedBox(height: 6),
                                  Text(
                                    'Video Captured (Max 30s)',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Image.file(
                            File(mediaFile!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(PhosphorIconsFill.warning, color: Colors.amber),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isVideo ? PhosphorIconsFill.videoCamera : PhosphorIconsFill.camera,
                          size: 13,
                          color: _isVideo ? AppTheme.secondaryAmber : AppTheme.primaryTeal,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isVideo ? 'VIDEO EVIDENCE' : 'PHOTO EVIDENCE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showMediaPickerSheet(context),
                      icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
                      label: const Text('Retake / Change'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryTeal,
                        side: const BorderSide(color: AppTheme.primaryTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: onClearMedia,
                    icon: const Icon(PhosphorIconsRegular.trash, color: AppTheme.dangerousRed),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _showMediaPickerSheet(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryTeal.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: AppTheme.softShadows,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsFill.cameraPlus,
                size: 36,
                color: AppTheme.primaryTeal,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Add Photo or Video Evidence',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Take a real photo or 30s video with camera, or choose from gallery',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: subtextColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsFill.sparkle, size: 14, color: AppTheme.primaryTeal),
                  SizedBox(width: 6),
                  Text(
                    'AI Authenticity & EXIF Verified',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTeal,
                    ),
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

/// 3. Animated EXIF Checklist Widget
class AnimatedExifChecklistWidget extends StatefulWidget {
  final ExifVerificationResult result;
  final VoidCallback onProceed;
  final VoidCallback onRetake;

  const AnimatedExifChecklistWidget({
    super.key,
    required this.result,
    required this.onProceed,
    required this.onRetake,
  });

  @override
  State<AnimatedExifChecklistWidget> createState() => _AnimatedExifChecklistWidgetState();
}

class _AnimatedExifChecklistWidgetState extends State<AnimatedExifChecklistWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _revealedCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _revealItemsSequentially();
  }

  Future<void> _revealItemsSequentially() async {
    for (int i = 0; i < widget.result.checks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _revealedCount = i + 1;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    final isAllRevealed = _revealedCount >= widget.result.checks.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.softShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.result.isVerified
                      ? AppTheme.successGreen.withValues(alpha: 0.15)
                      : AppTheme.secondaryAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.result.isVerified ? PhosphorIconsFill.shieldCheck : PhosphorIconsFill.shieldWarning,
                  color: widget.result.isVerified ? AppTheme.successGreen : AppTheme.secondaryAmber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verifying Photo Authenticity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      widget.result.statusTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.result.isVerified ? AppTheme.successGreen : AppTheme.secondaryAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Checklist items
          Column(
            children: List.generate(widget.result.checks.length, (index) {
              final check = widget.result.checks[index];
              final isVisible = index < _revealedCount;

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: isVisible ? 1.0 : 0.0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isVisible
                          ? (check.passed
                              ? AppTheme.successGreen.withValues(alpha: 0.3)
                              : AppTheme.secondaryAmber.withValues(alpha: 0.3))
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        check.passed ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warningCircle,
                        color: check.passed ? AppTheme.successGreen : AppTheme.secondaryAmber,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              check.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              check.description,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          if (widget.result.warningMessage != null && isAllRevealed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondaryAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.secondaryAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(PhosphorIconsFill.info, color: AppTheme.secondaryAmber, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.result.warningMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (isAllRevealed)
            Row(
              children: [
                if (!widget.result.isVerified) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onRetake,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: subtextColor,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Change Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: widget.onProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      widget.result.isVerified ? 'Continue to Duplicate Check' : 'Proceed as Unverified',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            )
          else
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal),
                  ),
                  SizedBox(width: 10),
                  Text('Inspecting EXIF & Geotags...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 4. Animated Duplicate Radar Widget
class AnimatedDuplicateRadarWidget extends StatelessWidget {
  final bool isScanning;
  final DuplicateCheckResult? result;
  final VoidCallback onConfirmSameIssue;
  final VoidCallback onReportAsNew;

  const AnimatedDuplicateRadarWidget({
    super.key,
    required this.isScanning,
    required this.result,
    required this.onConfirmSameIssue,
    required this.onReportAsNew,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    if (isScanning || result == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: AppTheme.softShadows,
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Checking for Existing Reports Nearby',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scanning 50m radius for active civic complaints in this ward...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
          ],
        ),
      );
    }

    final hasDuplicates = result!.isDuplicate && result!.matchedComplaints.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.softShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasDuplicates
                      ? AppTheme.secondaryAmber.withValues(alpha: 0.15)
                      : AppTheme.successGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasDuplicates ? PhosphorIconsFill.copy : PhosphorIconsFill.checkCircle,
                  color: hasDuplicates ? AppTheme.secondaryAmber : AppTheme.successGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDuplicates ? 'Existing Reports Found Nearby' : 'No Nearby Duplicates Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      hasDuplicates
                          ? 'Found ${result!.matchedComplaints.length} matching report(s) within 50m'
                          : 'Clear 50-meter radius — Ready for new report',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasDuplicates ? AppTheme.secondaryAmber : AppTheme.successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasDuplicates) ...[
            Text(
              'A similar issue was already reported near this location. You can confirm it to add yourself as a co-reporter (boosts municipal priority) or report it as a separate issue:',
              style: TextStyle(fontSize: 12, color: subtextColor, height: 1.35),
            ),
            const SizedBox(height: 14),
            ...result!.matchedComplaints.map((comp) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.secondaryAmber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryAmber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(PhosphorIconsFill.warning, color: AppTheme.secondaryAmber, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comp.category,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                          ),
                          if (comp.description != null && comp.description!.isNotEmpty)
                            Text(
                              comp.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: subtextColor),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${result!.distanceMeters?.toStringAsFixed(1) ?? "12"}m away',
                                style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${comp.upvoteCount} supporters',
                                style: TextStyle(fontSize: 11, color: subtextColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReportAsNew,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Report as New'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onConfirmSameIssue,
                    icon: const Icon(PhosphorIconsFill.thumbsUp, size: 16),
                    label: const Text('Confirm Same Issue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(PhosphorIconsFill.sparkle, color: AppTheme.successGreen, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No duplicate complaints found nearby. Your report will be registered as a primary incident.',
                      style: TextStyle(fontSize: 12, color: AppTheme.successGreen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onReportAsNew,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue to AI Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 5. Animated AI Vision & Severity Validation Widget
class AnimatedAiScannerWidget extends StatelessWidget {
  final bool isAnalyzing;
  final AIValidationResult? aiResult;
  final VoidCallback onProceed;
  final VoidCallback onReupload;

  const AnimatedAiScannerWidget({
    super.key,
    required this.isAnalyzing,
    required this.aiResult,
    required this.onProceed,
    required this.onReupload,
  });

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    if (isAnalyzing || aiResult == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: AppTheme.softShadows,
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsFill.brain,
                  color: AppTheme.primaryTeal,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Gemini AI Multimodal Vision Analysis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Checking photo content & relevance\n2. Estimating structural hazard severity',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: subtextColor, height: 1.4),
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: AppTheme.primaryTeal),
          ],
        ),
      );
    }

    final isValid = aiResult!.isValidHazard;
    final sevColor = _getSeverityColor(aiResult!.severity);

    if (!isValid) {
      IconData verdictIcon = PhosphorIconsFill.xCircle;
      String verdictTitle = 'Hazard Validation Failed';
      if (aiResult!.photoVerdict == 'Stock / Downloaded') {
        verdictIcon = PhosphorIconsFill.globe;
        verdictTitle = 'Web / Google Downloaded Image';
      } else if (aiResult!.photoVerdict == 'Screen Capture / Monitor Photo') {
        verdictIcon = PhosphorIconsFill.monitor;
        verdictTitle = 'Photo of Screen Detected';
      } else if (aiResult!.photoVerdict == 'AI Generated') {
        verdictIcon = PhosphorIconsFill.robot;
        verdictTitle = 'AI-Generated Synthetic Image';
      } else if (aiResult!.photoVerdict == 'Unrelated / Non-Hazard') {
        verdictIcon = PhosphorIconsFill.prohibit;
        verdictTitle = 'Non-Road Object Detected';
      }

      // Rejection Card
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dangerousRed.withValues(alpha: 0.5)),
          boxShadow: AppTheme.softShadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerousRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(verdictIcon, color: AppTheme.dangerousRed, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verdictTitle,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Text(
                        'AI Verdict: ${aiResult!.photoVerdict} (${(aiResult!.authenticityScore * 100).toInt()}% Authenticity)',
                        style: const TextStyle(fontSize: 12, color: AppTheme.dangerousRed, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.dangerousRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dangerousRed.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aiResult!.invalidReason ?? 'This photo does not appear to show an authentic, real-world road defect.',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.red.shade200 : Colors.red.shade900, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                  if (aiResult!.reasoning.isNotEmpty && aiResult!.reasoning != aiResult!.invalidReason) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Forensic Analysis: ${aiResult!.reasoning}',
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.red.shade300 : Colors.red.shade800, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReupload,
                icon: const Icon(PhosphorIconsRegular.camera, size: 18),
                label: const Text('Take / Choose Real Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Valid Hazard Card
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sevColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.softShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsFill.checkCircle, color: AppTheme.successGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Hazard Verified',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Text(
                      '${aiResult!.photoVerdict} • ${(aiResult!.confidence * 100).toInt()}% Confidence',
                      style: const TextStyle(fontSize: 12, color: AppTheme.successGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sevColor),
                ),
                child: Text(
                  '${aiResult!.severity.toUpperCase()} SEVERITY',
                  style: TextStyle(color: sevColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(PhosphorIconsFill.sparkle, color: AppTheme.primaryTeal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aiResult!.reasoning,
                    style: TextStyle(fontSize: 12.5, color: subtextColor, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue to Priority Computation', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 6. Animated Priority Meter Widget
class AnimatedPriorityMeterWidget extends StatelessWidget {
  final PriorityCalculationResult? priorityResult;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const AnimatedPriorityMeterWidget({
    super.key,
    required this.priorityResult,
    required this.isSubmitting,
    required this.onSubmit,
  });

  Color _getPriorityColor(String label) {
    switch (label.toLowerCase()) {
      case 'urgent':
        return AppTheme.dangerousRed;
      case 'high':
        return Colors.orange;
      case 'medium':
        return AppTheme.secondaryAmber;
      default:
        return AppTheme.successGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    final score = priorityResult?.priorityScore ?? 75;
    final label = priorityResult?.priorityLabel ?? 'High';
    final sla = priorityResult?.slaHours ?? 24;
    final priColor = _getPriorityColor(label);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: priColor.withValues(alpha: 0.4)),
        boxShadow: AppTheme.softShadows,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: priColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(PhosphorIconsFill.gauge, color: priColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Computed Municipal Priority',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Text(
                      'Automated BBMP Escalation Engine',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: priColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Priority Score gauge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    '$score / 100',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: priColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Priority Score', style: TextStyle(fontSize: 11, color: subtextColor)),
                ],
              ),
              Container(height: 36, width: 1, color: borderColor),
              Column(
                children: [
                  Text(
                    '${sla}h SLA',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Target Resolution', style: TextStyle(fontSize: 11, color: subtextColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsFill.paperPlaneRight, size: 20),
              label: Text(
                isSubmitting ? 'Submitting to BBMP...' : 'Submit Verified Road Report',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
