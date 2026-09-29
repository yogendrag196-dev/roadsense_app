import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme.dart';
import '../../../models/ward.dart';
import '../../../services/db_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/exif_service.dart';
import '../widgets/report_step_widgets.dart';

class BangaloreArea {
  final String name;
  final String wardName;
  final LatLng coords;

  const BangaloreArea({
    required this.name,
    required this.wardName,
    required this.coords,
  });
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Wizard Step (0: Details & Upload, 1: EXIF Check, 2: Duplicate Check, 3: AI Vision, 4: Priority & Submit)
  int _currentStep = 0;

  // Form State
  String? _selectedCategory;
  XFile? _selectedMedia;
  final _descriptionController = TextEditingController();

  // Location & Ward State
  LatLng _selectedLocation = const LatLng(12.9716, 77.5946);
  String _detectedWardName = 'Ward 80 - Shantalanagar / MG Road';
  String? _detectedWardId;
  List<Ward> _dbWards = [];
  bool _isLocating = false;
  final MapController _mapController = MapController();

  // Step Verification Results
  ExifVerificationResult? _exifResult;
  bool _isCheckingDuplicates = false;
  DuplicateCheckResult? _duplicateResult;
  bool _isAiAnalyzing = false;
  AIValidationResult? _aiResult;
  PriorityCalculationResult? _priorityResult;
  bool _isSubmitting = false;

  // Services
  final DBService _dbService = DBService();
  final StorageService _storageService = StorageService();
  final GeminiService _geminiService = GeminiService();
  final ExifService _exifService = ExifService();

  // Bangalore Popular Area Presets
  final List<BangaloreArea> _bangaloreAreas = const [
    BangaloreArea(name: 'Koramangala', wardName: 'Ward 151 - Koramangala', coords: LatLng(12.9352, 77.6245)),
    BangaloreArea(name: 'HSR Layout', wardName: 'Ward 174 - HSR Layout', coords: LatLng(12.9121, 77.6446)),
    BangaloreArea(name: 'Indiranagar', wardName: 'Ward 112 - Domlur / Indiranagar', coords: LatLng(12.9784, 77.6408)),
    BangaloreArea(name: 'Whitefield', wardName: 'Ward 85 - Doddanekkundi / Whitefield', coords: LatLng(12.9698, 77.7499)),
    BangaloreArea(name: 'Bellandur', wardName: 'Ward 150 - Bellandur', coords: LatLng(12.9304, 77.6784)),
    BangaloreArea(name: 'MG Road', wardName: 'Ward 80 - Shantalanagar / MG Road', coords: LatLng(12.9716, 77.6006)),
    BangaloreArea(name: 'Jayanagar', wardName: 'Ward 177 - Jayanagar', coords: LatLng(12.9250, 77.5938)),
    BangaloreArea(name: 'Electronic City', wardName: 'Ward 175 - Bommanahalli / Electronic City', coords: LatLng(12.8399, 77.6770)),
    BangaloreArea(name: 'Malleshwaram', wardName: 'Ward 45 - Malleshwaram', coords: LatLng(13.0031, 77.5643)),
    BangaloreArea(name: 'Hebbal', wardName: 'Ward 7 - Thanisandra / Hebbal', coords: LatLng(13.0358, 77.5970)),
    BangaloreArea(name: 'BTM Layout', wardName: 'Ward 22 - BTM Layout', coords: LatLng(12.9166, 77.6101)),
    BangaloreArea(name: 'Rajajinagar', wardName: 'Ward 66 - Subramanya Nagar / Rajajinagar', coords: LatLng(12.9915, 77.5524)),
  ];

  final List<Map<String, dynamic>> _categories = const [
    {'name': 'Pothole', 'icon': PhosphorIconsFill.warningOctagon},
    {'name': 'Flooding', 'icon': PhosphorIconsFill.drop},
    {'name': 'Broken Drain', 'icon': PhosphorIconsFill.gridFour},
    {'name': 'Road Crack', 'icon': PhosphorIconsFill.chartLine},
    {'name': 'Open Manhole', 'icon': PhosphorIconsFill.circle},
    {'name': 'Debris / Other', 'icon': PhosphorIconsFill.dotsThreeOutline},
  ];

  @override
  void initState() {
    super.initState();
    _loadWardsAndDetect();
    _determinePosition(silent: true);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWardsAndDetect() async {
    try {
      final wards = await _dbService.getWards();
      if (mounted) {
        setState(() {
          _dbWards = wards;
        });
        _updateAssignedWard(_selectedLocation);
      }
    } catch (_) {
      _updateAssignedWard(_selectedLocation);
    }
  }

  void _updateAssignedWard(LatLng point) {
    if (_dbWards.isNotEmpty) {
      Ward? closestDbWard;
      double minDbDist = double.infinity;
      for (final w in _dbWards) {
        if (w.centerLat != null && w.centerLng != null) {
          final dLat = w.centerLat! - point.latitude;
          final dLng = w.centerLng! - point.longitude;
          final dist = dLat * dLat + dLng * dLng;
          if (dist < minDbDist) {
            minDbDist = dist;
            closestDbWard = w;
          }
        }
      }

      if (closestDbWard != null) {
        setState(() {
          _detectedWardName = closestDbWard!.name;
          _detectedWardId = closestDbWard.id;
        });
        return;
      }
    }

    BangaloreArea closest = _bangaloreAreas.first;
    double minDistance = double.infinity;

    for (final area in _bangaloreAreas) {
      final dLat = area.coords.latitude - point.latitude;
      final dLng = area.coords.longitude - point.longitude;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < minDistance) {
        minDistance = dist;
        closest = area;
      }
    }

    String? matchedId;
    for (final w in _dbWards) {
      if (w.name.toLowerCase().contains(closest.name.toLowerCase())) {
        matchedId = w.id;
        break;
      }
    }

    setState(() {
      _detectedWardName = closest.wardName;
      _detectedWardId = matchedId ?? (_dbWards.isNotEmpty ? _dbWards.first.id : null);
    });
  }

  Future<void> _determinePosition({bool silent = false}) async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS / Location on your device.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Enable in app settings.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        final userCoords = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLocation = userCoords;
        });
        _updateAssignedWard(userCoords);

        try {
          _mapController.move(userCoords, 16.0);
        } catch (_) {}

        if (!silent && mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 Location Detected: $_detectedWardName'),
              backgroundColor: AppTheme.primaryTeal,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Geolocator error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  // --- Media Pickers ---
  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        setState(() => _selectedMedia = photo);
      }
    } catch (e) {
      debugPrint('Camera photo error: $e');
    }
  }

  Future<void> _recordVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null) {
        setState(() => _selectedMedia = video);
      }
    } catch (e) {
      debugPrint('Camera video error: $e');
    }
  }

  Future<void> _pickGalleryPhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (photo != null) {
        setState(() => _selectedMedia = photo);
      }
    } catch (e) {
      debugPrint('Gallery photo error: $e');
    }
  }

  Future<void> _pickGalleryVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null) {
        setState(() => _selectedMedia = video);
      }
    } catch (e) {
      debugPrint('Gallery video error: $e');
    }
  }

  // --- Step 1: Start EXIF Authenticity Check ---
  Future<void> _startExifVerification() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hazard category.')),
      );
      return;
    }

    if (_selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or upload a photo / video of the hazard.')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 1;
    });

    final file = File(_selectedMedia!.path);
    final exifResult = await _exifService.analyzePhotoAuthenticity(
      file: file,
      currentLocation: _selectedLocation,
    );

    if (mounted) {
      setState(() {
        _exifResult = exifResult;
      });
    }
  }

  // --- Step 2: Start Duplicate Search ---
  Future<void> _startDuplicateCheck() async {
    HapticFeedback.lightImpact();
    setState(() {
      _currentStep = 2;
      _isCheckingDuplicates = true;
      _duplicateResult = null;
    });

    final res = await _dbService.checkNearbyDuplicates(
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      category: _selectedCategory!,
    );

    if (mounted) {
      setState(() {
        _isCheckingDuplicates = false;
        _duplicateResult = res;
      });
    }
  }

  // --- Handle Duplicate Co-Reporting ---
  Future<void> _handleConfirmDuplicate(String originalComplaintId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to confirm reports.')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryTeal),
      ),
    );

    final success = await _dbService.coReportComplaint(
      originalComplaintId: originalComplaintId,
      userId: user.id,
    );

    if (mounted) {
      Navigator.pop(context); // Close loading
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Added as co-reporter! Priority boosted for BBMP team.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.go('/track');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to confirm report. Continuing as new.')),
        );
        _startAiAnalysis();
      }
    }
  }

  // --- Step 3: Start AI Multimodal Analysis ---
  Future<void> _startAiAnalysis() async {
    HapticFeedback.lightImpact();
    setState(() {
      _currentStep = 3;
      _isAiAnalyzing = true;
      _aiResult = null;
    });

    final file = File(_selectedMedia!.path);
    final res = await _geminiService.validateHazardAndAuthenticity(
      imageFile: file,
      category: _selectedCategory!,
      description: _descriptionController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isAiAnalyzing = false;
        _aiResult = res;
      });
    }
  }

  // --- Step 4: Compute Priority ---
  Future<void> _startPriorityComputation() async {
    if (_aiResult == null || !_aiResult!.isValidHazard) return;

    HapticFeedback.lightImpact();
    setState(() {
      _currentStep = 4;
    });

    final priority = await _dbService.computePriorityScore(
      severity: _aiResult!.severity,
      category: _selectedCategory!,
      duplicateReports: 0,
    );

    if (mounted) {
      setState(() {
        _priorityResult = priority;
      });
    }
  }

  Future<File?> _compressImage(File file) async {
    final filePath = file.absolute.path;
    final extension = p.extension(filePath).toLowerCase();
    if (extension == '.mp4' || extension == '.mov') return file;

    try {
      final outPath = "${filePath.substring(0, filePath.lastIndexOf('.'))}_compressed.jpg";
      final result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: 75,
        minWidth: 1024,
        minHeight: 1024,
      );
      return result != null ? File(result.path) : file;
    } catch (_) {
      return file;
    }
  }

  // --- Final Submit ---
  Future<void> _submitFinalReport() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a complaint.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final complaintId = const Uuid().v4();
      final rawFile = File(_selectedMedia!.path);
      File fileToUpload = rawFile;

      if (!rawFile.path.toLowerCase().endsWith('.mp4') && !rawFile.path.toLowerCase().endsWith('.mov')) {
        fileToUpload = await _compressImage(rawFile) ?? rawFile;
      }

      List<String> uploadedUrls = [];
      try {
        final url = await _storageService.uploadComplaintMedia(fileToUpload, complaintId);
        uploadedUrls.add(url);
      } catch (e) {
        debugPrint('Media upload warning: $e');
      }

      final severity = _aiResult?.severity ?? 'Medium';

      // 1. Insert Complaint
      await _dbService.createComplaint({
        'id': complaintId,
        'citizen_id': userId,
        'user_id': userId,
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'location': 'SRID=4326;POINT(${_selectedLocation.longitude} ${_selectedLocation.latitude})',
        'ward_id': _detectedWardId,
        'ward_name': _detectedWardName,
        'severity': severity,
        'status': 'Submitted',
        'media_urls': uploadedUrls,
        'upvote_count': 1,
      });

      // 2. Save AI Assessment & EXIF Verification Data
      try {
        await Supabase.instance.client.from('ai_assessments').upsert({
          'complaint_id': complaintId,
          'severity': severity,
          'confidence': _aiResult?.confidence ?? 0.88,
          'reason': _aiResult?.reasoning ?? 'AI multi-modal visual inspection verified.',
          'reasoning': _aiResult?.reasoning ?? 'AI multi-modal visual inspection verified.',
          'photo_verdict': _aiResult?.photoVerdict ?? 'Real Photo',
          'is_authentic': _exifResult?.isVerified ?? true,
          'authenticity_score': _aiResult?.authenticityScore ?? 0.92,
          'is_ai_generated': _aiResult?.photoVerdict == 'AI Generated',
        });
      } catch (aiDbErr) {
        debugPrint('ai_assessments error: $aiDbErr');
      }

      // 3. Save Work Order with Computed Priority
      try {
        final priorityLabel = _priorityResult?.priorityLabel ?? 'High';
        final slaHours = _priorityResult?.slaHours ?? 24;
        final slaDeadline = DateTime.now().add(Duration(hours: slaHours)).toIso8601String();

        await Supabase.instance.client.from('work_orders').upsert({
          'complaint_id': complaintId,
          'priority': priorityLabel,
          'stage': 'Assigned',
          'sla_deadline': slaDeadline,
        });
      } catch (woErr) {
        debugPrint('work_orders error: $woErr');
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        context.push('/report-success', extra: complaintId);
      }
    } catch (e) {
      debugPrint('Submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: AppTheme.dangerousRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = AppTheme.getScaffoldColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text('Report a Road Hazard', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.caretLeft, color: textColor),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Container(
        decoration: AppTheme.adaptiveBackgroundGradient(context),
        child: SafeArea(
          child: Column(
            children: [
              ReportFlowStepIndicator(currentStep: _currentStep),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _buildCurrentStepView(cardColor, borderColor, textColor, subtextColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStep0DetailsAndMedia(cardColor, borderColor, textColor, subtextColor);
      case 1:
        return _exifResult != null
            ? AnimatedExifChecklistWidget(
                result: _exifResult!,
                onProceed: _startDuplicateCheck,
                onRetake: () => setState(() => _currentStep = 0),
              )
            : const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal));
      case 2:
        return AnimatedDuplicateRadarWidget(
          isScanning: _isCheckingDuplicates,
          result: _duplicateResult,
          onConfirmSameIssue: () {
            if (_duplicateResult?.matchedComplaints.isNotEmpty ?? false) {
              _handleConfirmDuplicate(_duplicateResult!.matchedComplaints.first.id);
            }
          },
          onReportAsNew: _startAiAnalysis,
        );
      case 3:
        return AnimatedAiScannerWidget(
          isAnalyzing: _isAiAnalyzing,
          aiResult: _aiResult,
          onProceed: _startPriorityComputation,
          onReupload: () => setState(() => _currentStep = 0),
        );
      case 4:
        return AnimatedPriorityMeterWidget(
          priorityResult: _priorityResult,
          isSubmitting: _isSubmitting,
          onSubmit: _submitFinalReport,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep0DetailsAndMedia(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Column(
      key: const ValueKey('step0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Media Upload Card
        Text(
          '1. Photo or Video Evidence',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 10),
        MediaUploadPreviewCard(
          mediaFile: _selectedMedia,
          onTakePhoto: _takePhoto,
          onRecordVideo: _recordVideo,
          onPickGalleryPhoto: _pickGalleryPhoto,
          onPickGalleryVideo: _pickGalleryVideo,
          onClearMedia: () => setState(() => _selectedMedia = null),
        ),
        const SizedBox(height: 24),

        // 2. Hazard Category Selection
        Text(
          '2. Hazard Category',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory == cat['name'];
            final icon = cat['icon'] as IconData;
            final name = cat['name'] as String;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = name);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryTeal.withValues(alpha: 0.18)
                      : cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryTeal : borderColor,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: AppTheme.softShadows,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? AppTheme.primaryTeal : subtextColor,
                      size: 26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryTeal : textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // 3. Location & Ward Detection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '3. Physical Location & BBMP Ward',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
            TextButton.icon(
              onPressed: () => _determinePosition(),
              icon: _isLocating
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal),
                    )
                  : const Icon(PhosphorIconsBold.crosshair, size: 14, color: AppTheme.primaryTeal),
              label: Text(
                _isLocating ? 'Locating...' : 'GPS Detect',
                style: const TextStyle(fontSize: 12, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: AppTheme.softShadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.5,
                    onTap: (tapPos, point) {
                      setState(() {
                        _selectedLocation = point;
                      });
                      _updateAssignedWard(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.roadsense.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            PhosphorIconsFill.mapPin,
                            color: AppTheme.dangerousRed,
                            size: 38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsFill.mapPin, color: AppTheme.primaryTeal, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _detectedWardName,
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 4. Description
        Text(
          '4. Description (Optional)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 2,
          style: TextStyle(color: textColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Deep pothole right before the signal causing vehicle slowdowns...',
            hintStyle: TextStyle(color: subtextColor.withValues(alpha: 0.6), fontSize: 12.5),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Continue Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startExifVerification,
            icon: const Icon(PhosphorIconsFill.shieldCheck, size: 18),
            label: const Text(
              'Proceed to Authenticity & Verification',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
