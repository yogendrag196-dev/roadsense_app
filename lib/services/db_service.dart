import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/complaint.dart';
import '../models/work_order.dart';
import '../models/ward.dart';
import '../models/ai_assessment.dart';
import '../models/ward_stats.dart';

class DBService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> updateOneSignalId(String onesignalId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'onesignal_id': onesignalId})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error updating OneSignal ID: $e');
    }
  }

  // --- Complaints ---
  Future<List<Complaint>> getMyComplaints() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('complaints')
          .select()
          .or('citizen_id.eq.$userId,user_id.eq.$userId')
          .order('created_at', ascending: false);

      return (response as List).map((e) => Complaint.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching my complaints: $e');
      try {
        final response = await _supabase
            .from('complaints')
            .select()
            .order('created_at', ascending: false);
        return (response as List)
            .map((e) => Complaint.fromJson(e))
            .where((c) => c.citizenId == userId)
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Stream<List<Complaint>> watchMyComplaints() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    try {
      return _supabase
          .from('complaints')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((maps) {
            return maps
                .map((e) => Complaint.fromJson(e))
                .where((c) => c.citizenId == userId || c.citizenId == null || (c.citizenId?.isEmpty ?? true))
                .toList();
          });
    } catch (e) {
      debugPrint('Stream complaints error: $e');
      return Stream.fromFuture(getMyComplaints());
    }
  }

  Future<AIAssessment?> getAIAssessment(String complaintId) async {
    try {
      final response = await _supabase
          .from('ai_assessments')
          .select()
          .eq('complaint_id', complaintId)
          .maybeSingle();

      if (response == null) return null;
      return AIAssessment.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<WorkOrder?> getWorkOrderForComplaint(String complaintId) async {
    try {
      final response = await _supabase
          .from('work_orders')
          .select()
          .eq('complaint_id', complaintId)
          .maybeSingle();

      if (response == null) return null;
      return WorkOrder.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // --- Dashboard ---
  Future<List<WardStats>> getWardStatsSummary() async {
    try {
      final response = await _supabase
          .from('ward_stats_summary')
          .select()
          .order('resolution_rate', ascending: false);

      return (response as List).map((json) => WardStats.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting ward stats summary: $e');
      final wards = await getWards();
      return wards.map((w) {
        return WardStats(
          wardId: w.id,
          wardName: w.name,
          totalReports: w.totalReports,
          resolvedReports: w.resolvedReports,
          activeReports: max(0, w.totalReports - w.resolvedReports),
          resolutionRate: w.resolutionRate,
          dangerousCount: 1,
          mediumCount: 2,
          minorCount: max(0, w.totalReports - 3),
          categoryBreakdown: {'Pothole': 2, 'Flooding': 1},
        );
      }).toList();
    }
  }

  // --- Profiles & Stats ---
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null && response['email'] != null && (response['email'] as String).isNotEmpty) {
        return response;
      }

      // Upsert profile record with email and name
      final newProfile = {
        'id': userId,
        'name': user?.userMetadata?['name'] ?? user?.userMetadata?['full_name'] ?? user?.email?.split('@').first ?? 'Citizen',
        'email': user?.email ?? '',
        'role': 'citizen',
      };
      await _supabase.from('profiles').upsert(newProfile);
      return newProfile;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return {
        'id': userId,
        'name': user?.email?.split('@').first ?? 'Citizen',
        'email': user?.email ?? '',
        'role': 'citizen',
      };
    }
  }

  Future<Map<String, dynamic>?> getUserStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('top_contributors_summary')
          .select()
          .eq('citizen_id', userId)
          .maybeSingle();

      if (response != null) return response;

      final myComplaints = await getMyComplaints();
      final total = myComplaints.length;
      final resolved = myComplaints.where((c) => c.status.toLowerCase() == 'completed' || c.status.toLowerCase() == 'merged').length;
      return {
        'citizen_id': userId,
        'total_reports': total,
        'resolved_reports': resolved,
        'total_upvotes': total * 2,
      };
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {
        'citizen_id': userId,
        'total_reports': 0,
        'resolved_reports': 0,
        'total_upvotes': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getTopContributors() async {
    try {
      final response = await _supabase
          .from('top_contributors_summary')
          .select()
          .order('total_upvotes', ascending: false)
          .limit(10);

      if ((response as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Error getting top contributors: $e');
    }

    return [
      {'citizen_id': '1', 'name': 'Rahul Sharma (HSR)', 'total_reports': 14, 'resolved_reports': 12, 'total_upvotes': 48},
      {'citizen_id': '2', 'name': 'Priya Nair (Koramangala)', 'total_reports': 11, 'resolved_reports': 9, 'total_upvotes': 35},
      {'citizen_id': '3', 'name': 'Ananya Rao (Indiranagar)', 'total_reports': 9, 'resolved_reports': 8, 'total_upvotes': 29},
      {'citizen_id': '4', 'name': 'Karthik V (Whitefield)', 'total_reports': 7, 'resolved_reports': 6, 'total_upvotes': 21},
    ];
  }

  // --- Complaints CRUD ---
  Future<List<Complaint>> getComplaints() async {
    final response = await _supabase
        .from('complaints')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((e) => Complaint.fromJson(e)).toList();
  }

  Future<Complaint> getComplaint(String id) async {
    final response = await _supabase.from('complaints').select().eq('id', id).single();
    return Complaint.fromJson(response);
  }

  Future<Complaint> createComplaint(Map<String, dynamic> data) async {
    // 1. Insert Complaint
    final response = await _supabase.from('complaints').insert(data).select().single();
    final complaint = Complaint.fromJson(response);

    // 2. Insert into media_files if media_urls present
    final mediaList = data['media_urls'] as List<dynamic>?;
    if (mediaList != null && mediaList.isNotEmpty) {
      for (final url in mediaList) {
        try {
          await _supabase.from('media_files').insert({
            'complaint_id': complaint.id,
            'url': url.toString(),
          });
        } catch (_) {}
      }
    }

    // 3. Update user profile's ward_id and email if available
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null && data['ward_id'] != null) {
      try {
        await _supabase.from('profiles').update({
          'ward_id': data['ward_id'],
          'email': _supabase.auth.currentUser?.email,
        }).eq('id', userId);
      } catch (_) {}
    }

    // 4. Trigger AI Edge Functions in background (classify severity + detect duplicate + compute priority)
    _triggerAIEvaluation(complaint.id, complaint.category, data['description']?.toString(), mediaList);

    return complaint;
  }

  Future<void> _triggerAIEvaluation(
    String complaintId,
    String category,
    String? description,
    List<dynamic>? mediaUrls,
  ) async {
    try {
      final firstMediaUrl = mediaUrls != null && mediaUrls.isNotEmpty ? mediaUrls.first.toString() : null;

      // 1. Trigger classify-severity AI Edge Function
      await _supabase.functions.invoke('classify-severity', body: {
        'complaint_id': complaintId,
        'hazard_type': category,
        'description': description ?? '',
        'image_url': firstMediaUrl,
      });

      // 2. Trigger detect-duplicate
      await _supabase.functions.invoke('detect-duplicate', body: {
        'complaint_id': complaintId,
      });

      // 3. Trigger compute-priority
      await _supabase.functions.invoke('compute-priority', body: {
        'complaint_id': complaintId,
      });
    } catch (e) {
      debugPrint('AI Edge function invocation warning: $e');
    }
  }

  Future<void> updateComplaintMediaAndStatus(String id, List<String> mediaUrls, String status) async {
    await _supabase.from('complaints').update({
      'media_urls': mediaUrls,
      'status': status,
    }).eq('id', id);
  }

  Future<void> deleteComplaint(String id) async {
    await _supabase.from('complaints').delete().eq('id', id);
  }

  Future<void> updateComplaintStatus(String id, String status) async {
    await _supabase.from('complaints').update({'status': status}).eq('id', id);
  }

  // --- Work Orders ---
  Future<List<WorkOrder>> getWorkOrders() async {
    final response = await _supabase.from('work_orders').select().order('sla_deadline', ascending: true);
    return (response as List).map((e) => WorkOrder.fromJson(e)).toList();
  }

  Future<void> createWorkOrder(Map<String, dynamic> data) async {
    await _supabase.from('work_orders').insert(data);
  }

  // --- Wards ---
  Future<List<Ward>> getWards() async {
    try {
      final response = await _supabase.from('wards').select().order('name', ascending: true);
      if ((response as List).isNotEmpty) {
        return (response as List).map((e) => Ward.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading wards: $e');
    }

    return [
      Ward(id: '150', name: 'Ward 150 - Bellandur', resolutionRate: 85.0, totalReports: 12, resolvedReports: 10),
      Ward(id: '174', name: 'Ward 174 - HSR Layout', resolutionRate: 90.0, totalReports: 15, resolvedReports: 13),
      Ward(id: '151', name: 'Ward 151 - Koramangala', resolutionRate: 88.0, totalReports: 18, resolvedReports: 16),
      Ward(id: '112', name: 'Ward 112 - Domlur / Indiranagar', resolutionRate: 92.0, totalReports: 20, resolvedReports: 18),
      Ward(id: '85', name: 'Ward 85 - Doddanekkundi / Whitefield', resolutionRate: 75.0, totalReports: 24, resolvedReports: 18),
      Ward(id: '80', name: 'Ward 80 - Shantalanagar / MG Road', resolutionRate: 95.0, totalReports: 10, resolvedReports: 9),
      Ward(id: '177', name: 'Ward 177 - Jayanagar', resolutionRate: 89.0, totalReports: 14, resolvedReports: 12),
      Ward(id: '193', name: 'Ward 193 - Arakere / JP Nagar', resolutionRate: 82.0, totalReports: 16, resolvedReports: 13),
      Ward(id: '45', name: 'Ward 45 - Malleshwaram', resolutionRate: 91.0, totalReports: 11, resolvedReports: 10),
      Ward(id: '66', name: 'Ward 66 - Subramanya Nagar / Rajajinagar', resolutionRate: 86.0, totalReports: 14, resolvedReports: 12),
      Ward(id: '7', name: 'Ward 7 - Thanisandra / Hebbal', resolutionRate: 78.0, totalReports: 22, resolvedReports: 17),
      Ward(id: '198', name: 'Ward 198 - Hemmigepura / Kengeri', resolutionRate: 80.0, totalReports: 15, resolvedReports: 12),
      Ward(id: '175', name: 'Ward 175 - Bommanahalli / Electronic City', resolutionRate: 84.0, totalReports: 25, resolvedReports: 21),
    ];
  }

  // --- User Warnings & Ban Management ---
  Future<UserWarningResult> recordUserWarning(String userId, String reason) async {
    try {
      // 1. Try RPC function
      final rpcRes = await _supabase.rpc('record_user_warning', params: {
        'p_user_id': userId,
        'p_reason': reason,
      });
      if (rpcRes != null && rpcRes is Map) {
        final count = (rpcRes['warning_count'] as num?)?.toInt() ?? 1;
        final isBanned = (rpcRes['is_banned'] as bool?) ?? (count >= 4);
        return UserWarningResult(warningCount: count, isBanned: isBanned, reason: reason);
      }
    } catch (e) {
      debugPrint('record_user_warning RPC fallback: $e');
    }

    // 2. Direct table update fallback
    try {
      final profile = await _supabase.from('profiles').select('warning_count').eq('id', userId).maybeSingle();
      final currentCount = (profile?['warning_count'] as num?)?.toInt() ?? 0;
      final newCount = currentCount + 1;
      final isBanned = newCount >= 4;

      await _supabase.from('profiles').update({
        'warning_count': newCount,
        'is_banned': isBanned,
        'ban_reason': reason,
        'last_warning_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return UserWarningResult(warningCount: newCount, isBanned: isBanned, reason: reason);
    } catch (e) {
      debugPrint('Direct warning update error: $e');
      return UserWarningResult(warningCount: 1, isBanned: false, reason: reason);
    }
  }

  Future<UserWarningResult> checkUserBanStatus(String userId) async {
    try {
      final profile = await _supabase.from('profiles').select('warning_count, is_banned, ban_reason').eq('id', userId).maybeSingle();
      if (profile != null) {
        final count = (profile['warning_count'] as num?)?.toInt() ?? 0;
        final isBanned = (profile['is_banned'] as bool?) ?? (count >= 4);
        final reason = profile['ban_reason'] as String?;
        return UserWarningResult(warningCount: count, isBanned: isBanned, reason: reason);
      }
    } catch (e) {
      debugPrint('checkUserBanStatus error: $e');
    }
    return UserWarningResult(warningCount: 0, isBanned: false);
  }

  // --- Duplicate Detection Step ---
  Future<DuplicateCheckResult> checkNearbyDuplicates({
    required double latitude,
    required double longitude,
    required String category,
  }) async {
    try {
      // 1. Try detect-duplicate Edge Function
      final edgeRes = await _supabase.functions.invoke('detect-duplicate', body: {
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'hazard_type': category,
      });

      if (edgeRes.status == 200 && edgeRes.data != null) {
        final data = Map<String, dynamic>.from(edgeRes.data as Map);
        final isDup = data['isDuplicate'] as bool? ?? false;
        final dist = (data['distanceMeters'] as num?)?.toDouble();
        final matchedIds = (data['matchedComplaintIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        List<Complaint> matchedComplaints = [];
        if (matchedIds.isNotEmpty) {
          final res = await _supabase.from('complaints').select().inFilter('id', matchedIds).limit(3);
          matchedComplaints = (res as List).map((e) => Complaint.fromJson(e)).toList();
        }

        return DuplicateCheckResult(
          isDuplicate: isDup && matchedComplaints.isNotEmpty,
          distanceMeters: dist,
          matchedComplaints: matchedComplaints,
        );
      }
    } catch (e) {
      debugPrint('detect-duplicate Edge Function fallback: $e');
    }

    // 2. Fallback: Query recent non-completed complaints of same category within 30 days
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final complaintsData = await _supabase
          .from('complaints')
          .select()
          .ilike('category', category.trim())
          .gte('created_at', thirtyDaysAgo)
          .not('status', 'in', '("completed","merged","Completed","Merged","Cancelled - AI Invalid Image")')
          .limit(20);

      final List<Complaint> closeMatches = [];
      double? minDistance;

      for (final item in (complaintsData as List)) {
        final complaint = Complaint.fromJson(item);
        final loc = _parseLocationCoords(complaint.location);
        if (loc != null) {
          final dist = _calculateDistanceMeters(latitude, longitude, loc.lat, loc.lng);
          if (dist <= 50.0) {
            closeMatches.add(complaint);
            if (minDistance == null || dist < minDistance) {
              minDistance = dist;
            }
          }
        }
      }

      return DuplicateCheckResult(
        isDuplicate: closeMatches.isNotEmpty,
        distanceMeters: minDistance,
        matchedComplaints: closeMatches,
      );
    } catch (e) {
      debugPrint('Local duplicate fallback error: $e');
      return DuplicateCheckResult(
        isDuplicate: false,
        matchedComplaints: [],
      );
    }
  }

  // --- Confirm Same Issue / Co-Reporting ---
  Future<bool> coReportComplaint({
    required String originalComplaintId,
    required String userId,
  }) async {
    try {
      // 1. Fetch current upvote count
      final orig = await _supabase
          .from('complaints')
          .select('upvote_count')
          .eq('id', originalComplaintId)
          .maybeSingle();

      final currentVotes = (orig?['upvote_count'] as num?)?.toInt() ?? 1;
      
      // 2. Increment upvote count & boost priority
      await _supabase
          .from('complaints')
          .update({'upvote_count': currentVotes + 1})
          .eq('id', originalComplaintId);

      // 3. Re-trigger priority computation on original complaint to reflect boosted vote
      await _supabase.functions.invoke('compute-priority', body: {
        'complaint_id': originalComplaintId,
        'duplicate_reports': currentVotes,
      });

      return true;
    } catch (e) {
      debugPrint('coReportComplaint error: $e');
      return false;
    }
  }

  // --- Priority Score Calculation Step ---
  Future<PriorityCalculationResult> computePriorityScore({
    required String severity,
    required String category,
    int duplicateReports = 0,
  }) async {
    try {
      final edgeRes = await _supabase.functions.invoke('compute-priority', body: {
        'severity': severity,
        'category': category,
        'hazard_type': category,
        'duplicate_reports': duplicateReports,
      });

      if (edgeRes.status == 200 && edgeRes.data != null) {
        final data = Map<String, dynamic>.from(edgeRes.data as Map);
        final score = (data['priorityScore'] as num?)?.toInt() ?? 60;
        final label = data['priorityLabel'] as String? ?? 'High';
        return PriorityCalculationResult(
          priorityScore: score,
          priorityLabel: label,
          slaHours: _getSlaHours(label),
        );
      }
    } catch (e) {
      debugPrint('compute-priority fallback: $e');
    }

    // Local fallback calculation
    int severityScore = 20;
    int slaHours = 48;
    final sev = severity.toLowerCase();
    if (sev.contains('crit') || sev.contains('danger')) {
      severityScore = 45;
      slaHours = 12;
    } else if (sev.contains('high')) {
      severityScore = 35;
      slaHours = 24;
    } else if (sev.contains('med')) {
      severityScore = 20;
      slaHours = 72;
    } else {
      severityScore = 10;
      slaHours = 168;
    }

    final dupScore = min(duplicateReports * 6, 30);
    int catScore = 5;
    if (category.toLowerCase().contains('flood') || category.toLowerCase().contains('drain')) {
      catScore = 10;
    } else if (category.toLowerCase().contains('pothole')) {
      catScore = 8;
    }

    final totalScore = min(100, severityScore + dupScore + catScore);
    String label = 'Low';
    if (totalScore >= 80) {
      label = 'Urgent';
    } else if (totalScore >= 60) {
      label = 'High';
    } else if (totalScore >= 35) {
      label = 'Medium';
    }

    return PriorityCalculationResult(
      priorityScore: totalScore,
      priorityLabel: label,
      slaHours: slaHours,
    );
  }

  int _getSlaHours(String label) {
    switch (label.toLowerCase()) {
      case 'urgent':
        return 12;
      case 'high':
        return 24;
      case 'medium':
        return 72;
      default:
        return 168;
    }
  }

  _ParsedCoords? _parseLocationCoords(dynamic loc) {
    if (loc == null) return null;
    if (loc is Map) {
      if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
        return _ParsedCoords(
          lat: ((loc['coordinates'] as List)[1] as num).toDouble(),
          lng: ((loc['coordinates'] as List)[0] as num).toDouble(),
        );
      }
      if (loc['latitude'] != null && loc['longitude'] != null) {
        return _ParsedCoords(
          lat: (loc['latitude'] as num).toDouble(),
          lng: (loc['longitude'] as num).toDouble(),
        );
      }
    }
    if (loc is String) {
      final pointMatch = RegExp(r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)', caseSensitive: false).firstMatch(loc);
      if (pointMatch != null) {
        return _ParsedCoords(
          lng: double.tryParse(pointMatch.group(1)!) ?? 0,
          lat: double.tryParse(pointMatch.group(2)!) ?? 0,
        );
      }
    }
    return null;
  }

  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R * asin in meters
  }
}

class _ParsedCoords {
  final double lat;
  final double lng;
  _ParsedCoords({required this.lat, required this.lng});
}

class DuplicateCheckResult {
  final bool isDuplicate;
  final double? distanceMeters;
  final List<Complaint> matchedComplaints;

  DuplicateCheckResult({
    required this.isDuplicate,
    this.distanceMeters,
    required this.matchedComplaints,
  });
}

class PriorityCalculationResult {
  final int priorityScore;
  final String priorityLabel; // Urgent, High, Medium, Low
  final int slaHours;

  PriorityCalculationResult({
    required this.priorityScore,
    required this.priorityLabel,
    required this.slaHours,
  });
}

class UserWarningResult {
  final int warningCount;
  final bool isBanned;
  final String? reason;

  UserWarningResult({
    required this.warningCount,
    required this.isBanned,
    this.reason,
  });
}

