import 'dart:io';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class ExifCheckItem {
  final String title;
  final String description;
  final bool passed;
  final bool isWarning;

  const ExifCheckItem({
    required this.title,
    required this.description,
    required this.passed,
    this.isWarning = false,
  });
}

class ExifVerificationResult {
  final bool hasExif;
  final String? deviceModel;
  final DateTime? captureTime;
  final LatLng? photoGps;
  final double? distanceMeters;
  final bool isGpsMatched;
  final bool isVerified;
  final String statusTitle;
  final String? warningMessage;
  final List<ExifCheckItem> checks;

  ExifVerificationResult({
    required this.hasExif,
    this.deviceModel,
    this.captureTime,
    this.photoGps,
    this.distanceMeters,
    required this.isGpsMatched,
    required this.isVerified,
    required this.statusTitle,
    this.warningMessage,
    required this.checks,
  });
}

class ExifService {
  /// Analyzes image EXIF metadata and compares coordinates with current user position
  Future<ExifVerificationResult> analyzePhotoAuthenticity({
    required File file,
    required LatLng currentLocation,
  }) async {
    final path = file.path.toLowerCase();
    final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.mkv') || path.endsWith('.avi');

    if (isVideo) {
      // Videos don't contain standard image EXIF
      final lastModified = await file.lastModified();
      return ExifVerificationResult(
        hasExif: false,
        captureTime: lastModified,
        isGpsMatched: false,
        isVerified: false,
        statusTitle: 'Video Media — Unverified EXIF',
        warningMessage: 'Video files do not embed standard EXIF geotags. Report will proceed with Unverified media status.',
        checks: [
          const ExifCheckItem(
            title: 'Media Format',
            description: 'Direct video recording / clip',
            passed: true,
          ),
          ExifCheckItem(
            title: 'File Timestamp',
            description: 'Recorded: ${lastModified.toLocal().toString().split('.')[0]}',
            passed: true,
          ),
          const ExifCheckItem(
            title: 'GPS Geotag Extraction',
            description: 'Not available for video container formats',
            passed: false,
            isWarning: true,
          ),
        ],
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final data = await readExifFromBytes(bytes);

      if (data.isEmpty) {
        final lastModified = await file.lastModified();
        return ExifVerificationResult(
          hasExif: false,
          captureTime: lastModified,
          isGpsMatched: false,
          isVerified: false,
          statusTitle: 'Metadata Stripped — Unverified Capture',
          warningMessage: 'No EXIF metadata was found. Images shared via WhatsApp or web downloads often strip EXIF data. You can still proceed with your report.',
          checks: [
            const ExifCheckItem(
              title: 'Camera Device Sensor',
              description: 'No hardware sensor metadata found (stripped or web download)',
              passed: false,
              isWarning: true,
            ),
            ExifCheckItem(
              title: 'Capture Timestamp',
              description: 'Fallback file time: ${lastModified.toLocal().toString().split('.')[0]}',
              passed: true,
            ),
            const ExifCheckItem(
              title: 'GPS Geotag Verification',
              description: 'No coordinates found in photo',
              passed: false,
              isWarning: true,
            ),
          ],
        );
      }

      // 1. Device Make & Model
      String? make = data['Image Make']?.printable;
      String? model = data['Image Model']?.printable;
      String? software = data['Image Software']?.printable ?? data['Software']?.printable;
      String? deviceModel;
      if (model != null && model.isNotEmpty) {
        deviceModel = (make != null && !model.toLowerCase().contains(make.toLowerCase())) ? '$make $model' : model;
      } else if (make != null && make.isNotEmpty) {
        deviceModel = make;
      }

      bool isSoftwareEdited = false;
      if (software != null && software.isNotEmpty) {
        final s = software.toLowerCase();
        if (s.contains('photoshop') || s.contains('gimp') || s.contains('canva') || s.contains('snapseed') || s.contains('lightroom') || s.contains('paint')) {
          isSoftwareEdited = true;
        }
      }

      // 2. Timestamp
      DateTime? captureTime;
      final dateStr = data['EXIF DateTimeOriginal']?.printable ??
          data['Image DateTime']?.printable ??
          data['EXIF DateTimeDigitized']?.printable;

      if (dateStr != null && dateStr.length >= 19) {
        try {
          // Format is usually "YYYY:MM:DD HH:MM:SS"
          final parts = dateStr.split(' ');
          final datePart = parts[0].replaceAll(':', '-');
          final timePart = parts[1];
          captureTime = DateTime.tryParse('$datePart $timePart');
        } catch (_) {}
      }
      captureTime ??= await file.lastModified();

      // 3. GPS Coordinates
      LatLng? photoGps;
      final latTag = data['GPS GPSLatitude'];
      final latRef = data['GPS GPSLatitudeRef']?.printable ?? 'N';
      final lngTag = data['GPS GPSLongitude'];
      final lngRef = data['GPS GPSLongitudeRef']?.printable ?? 'E';

      if (latTag != null && lngTag != null) {
        final lat = _convertGpsToDecimal(latTag, latRef);
        final lng = _convertGpsToDecimal(lngTag, lngRef);
        if (lat != null && lng != null && lat != 0 && lng != 0) {
          photoGps = LatLng(lat, lng);
        }
      }

      // 4. GPS Distance Check against current user location
      double? distanceMeters;
      bool isGpsMatched = false;

      if (photoGps != null) {
        distanceMeters = Geolocator.distanceBetween(
          photoGps.latitude,
          photoGps.longitude,
          currentLocation.latitude,
          currentLocation.longitude,
        );
        // Match if within 500 meters of current position
        isGpsMatched = distanceMeters <= 500.0;
      }

      final hasDevice = deviceModel != null && deviceModel.isNotEmpty;
      final hasGps = photoGps != null;
      final isVerified = hasDevice && hasGps && isGpsMatched && !isSoftwareEdited;

      String statusTitle;
      String? warningMessage;

      if (isVerified) {
        statusTitle = 'Authentic Geotagged Capture';
      } else if (isSoftwareEdited) {
        statusTitle = 'Edited Media Detected';
        warningMessage = 'Photo was modified using $software. Authentic raw field photos are required.';
      } else if (!hasGps) {
        statusTitle = 'GPS Missing — Unverified Capture';
        warningMessage = 'Photo lacks GPS geotag metadata (common in web downloads or disabled camera GPS). Report marked Unverified.';
      } else if (!isGpsMatched) {
        statusTitle = 'Location Mismatch — Unverified Capture';
        final distKm = (distanceMeters! / 1000).toStringAsFixed(1);
        warningMessage = 'Photo was captured approximately $distKm km away from your current location (likely a downloaded or remote photo). Marked Unverified.';
      } else {
        statusTitle = 'Partially Verified Capture';
      }

      final checks = [
        ExifCheckItem(
          title: 'Camera Device Sensor',
          description: hasDevice ? 'Captured on $deviceModel' : 'Hardware model not specified in EXIF (typical of web downloads)',
          passed: hasDevice,
          isWarning: !hasDevice,
        ),
        ExifCheckItem(
          title: 'Capture Timestamp',
          description: 'Recorded: ${captureTime.toLocal().toString().split('.')[0]}',
          passed: true,
        ),
        ExifCheckItem(
          title: 'GPS Geotag Verification',
          description: photoGps != null
              ? (isGpsMatched
                  ? 'Matches current location (~${distanceMeters?.toStringAsFixed(0)}m away)'
                  : 'Coordinates differ (${(distanceMeters! / 1000).toStringAsFixed(1)} km away — location mismatch)')
              : 'No GPS coordinates found in image metadata (stripped in web downloads)',
          passed: hasGps && isGpsMatched,
          isWarning: !hasGps || !isGpsMatched,
        ),
      ];

      if (software != null && software.isNotEmpty) {
        checks.add(
          ExifCheckItem(
            title: 'Image Software Tag',
            description: isSoftwareEdited
                ? 'Edited with $software (potential non-authentic photo)'
                : 'Processed by $software',
            passed: !isSoftwareEdited,
            isWarning: isSoftwareEdited,
          ),
        );
      }

      return ExifVerificationResult(
        hasExif: true,
        deviceModel: deviceModel,
        captureTime: captureTime,
        photoGps: photoGps,
        distanceMeters: distanceMeters,
        isGpsMatched: isGpsMatched,
        isVerified: isVerified,
        statusTitle: statusTitle,
        warningMessage: warningMessage,
        checks: checks,
      );
    } catch (e) {
      debugPrint('EXIF read error: $e');
      final lastModified = await file.lastModified();
      return ExifVerificationResult(
        hasExif: false,
        captureTime: lastModified,
        isGpsMatched: false,
        isVerified: false,
        statusTitle: 'Unverified Media Capture',
        warningMessage: 'Could not read EXIF data. You can still proceed with your complaint.',
        checks: [
          const ExifCheckItem(
            title: 'Metadata Check',
            description: 'Could not parse EXIF metadata table',
            passed: false,
            isWarning: true,
          ),
        ],
      );
    }
  }

  double? _convertGpsToDecimal(dynamic gpsTag, String ref) {
    try {
      final values = gpsTag.values;
      if (values == null || values.length < 3) return null;

      double degrees = _ratioToDouble(values[0]);
      double minutes = _ratioToDouble(values[1]);
      double seconds = _ratioToDouble(values[2]);

      double result = degrees + (minutes / 60.0) + (seconds / 3600.0);
      if (ref == 'S' || ref == 'W') {
        result = -result;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  double _ratioToDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val.numerator != null && val.denominator != null) {
      return val.denominator == 0 ? 0.0 : (val.numerator as int) / (val.denominator as int);
    }
    return 0.0;
  }
}
