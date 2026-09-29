import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucketName = 'complaint-media';

  Future<String> uploadComplaintMedia(File file, String complaintId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final path = '$complaintId/$fileName';

      // Upload file to Supabase Storage
      await _supabase.storage.from(_bucketName).upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Return public URL
      final publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }
}
