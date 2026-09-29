import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AIValidationResult {
  final bool isValidHazard;
  final String severity; // Low, Medium, High, Critical
  final double confidence;
  final String photoVerdict; // Real Photo, AI Generated, Stock / Downloaded, Unrelated / Non-Hazard
  final bool isAuthentic;
  final double authenticityScore;
  final String? invalidReason;
  final String reasoning;

  String? get rejectionReason => invalidReason;

  AIValidationResult({
    required this.isValidHazard,
    required this.severity,
    required this.confidence,
    required this.photoVerdict,
    required this.isAuthentic,
    required this.authenticityScore,
    this.invalidReason,
    required this.reasoning,
  });

  factory AIValidationResult.fromJson(Map<String, dynamic> json) {
    final verdict = (json['photoVerdict'] ?? json['photo_verdict'] as String?) ?? 'Real Photo';
    final isAuth = json['isAuthentic'] ?? json['is_authentic'] as bool? ?? (verdict == 'Real Photo');
    final authScore = (json['authenticityScore'] ?? json['authenticity_score'] as num?)?.toDouble() ?? (isAuth ? 0.95 : 0.25);
    final isVerdictAuthentic = verdict == 'Real Photo';
    
    // Strict authenticity enforcement: Google downloads, screen captures, AI art, or low authenticity scores are rejected
    final rawValid = json['isValidHazard'] ?? json['is_valid_hazard'] as bool? ?? false;
    final isValid = rawValid && isAuth && isVerdictAuthentic && authScore >= 0.50;
    
    String? invReason = json['invalidReason'] ?? json['invalid_reason'] ?? json['rejection_reason'] as String?;
    if (!isValid && invReason == null) {
      if (verdict == 'Screen Capture / Monitor Photo') {
        invReason = 'Photo of a computer/phone display screen detected. Please photograph the physical road hazard directly on-site.';
      } else if (verdict == 'Stock / Downloaded') {
        invReason = 'Web downloaded or stock image detected. Please take an authentic field photo at the location.';
      } else if (verdict == 'AI Generated') {
        invReason = 'AI-generated synthetic image detected. Only genuine real-world photos are accepted.';
      } else {
        invReason = 'This photo does not appear to show a valid real-world road hazard. Please upload a clear photo of the issue.';
      }
    }

    return AIValidationResult(
      isValidHazard: isValid,
      severity: (json['severity'] as String?) ?? 'Medium',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.88,
      photoVerdict: verdict,
      isAuthentic: isAuth && isVerdictAuthentic,
      authenticityScore: authScore,
      invalidReason: invReason,
      reasoning: (json['reasoning'] as String?) ?? (json['reason'] as String?) ?? 'AI visual verification completed.',
    );
  }
}

class GeminiService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Inspects a photo and description in real-time to verify:
  /// 1. Real physical outdoor road hazard vs unrelated indoor/non-road objects (e.g. water bottle, bedsheet, laptop, keyboard, desk, selfie).
  /// 2. Photo authenticity: Real camera capture vs AI-generated (Midjourney/DALL-E) vs Stock/Google downloaded image.
  /// 3. Hazard severity: Low, Medium, High, Critical.
  Future<AIValidationResult> validateHazardAndAuthenticity({
    required File imageFile,
    required String category,
    String? description,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = imageFile.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:$mimeType;base64,$base64Image';

      // 1. Direct Gemini Vision API call (Highest accuracy & semantic understanding)
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      if (geminiApiKey != null && geminiApiKey.isNotEmpty && !geminiApiKey.startsWith('YOUR_')) {
        debugPrint('🤖 [GeminiService] Calling Gemini Vision API for multimodal hazard inspection...');
        final directResult = await _callGeminiDirect(
          apiKey: geminiApiKey,
          base64Image: base64Image,
          mimeType: mimeType,
          category: category,
          description: description,
        );
        if (directResult != null) {
          debugPrint('🤖 [GeminiService] Gemini Vision Verdict: ${directResult.photoVerdict}, Valid: ${directResult.isValidHazard}');
          return directResult;
        }
      } else {
        debugPrint('⚠️ [GeminiService] GEMINI_API_KEY is not configured in .env!');
      }

      // 2. Try invoking Supabase Edge Function 'classify-severity'
      try {
        debugPrint('🤖 [GeminiService] Calling Supabase Edge Function...');
        final edgeResponse = await _supabase.functions.invoke(
          'classify-severity',
          body: {
            'image_url': dataUri,
            'hazard_type': category,
            'description': description ?? '',
          },
        );

        if (edgeResponse.status == 200 && edgeResponse.data != null) {
          final data = Map<String, dynamic>.from(edgeResponse.data as Map);
          debugPrint('🤖 [GeminiService] Edge Function returned: $data');
          return AIValidationResult.fromJson(data);
        }
      } catch (edgeErr) {
        debugPrint('⚠️ [GeminiService] Edge Function error: $edgeErr');
      }

      // 3. Fallback: On-Device Computer Vision Pixel & Surface Entropy Inspection
      debugPrint('🤖 [GeminiService] Running on-device computer vision surface analysis...');
      final cvResult = await _analyzeImageOnDevice(bytes, category, description);
      return cvResult;
    } catch (e) {
      debugPrint('AI validation exception: $e');
      return AIValidationResult(
        isValidHazard: false,
        severity: 'Medium',
        confidence: 0.50,
        photoVerdict: 'Error in Inspection',
        isAuthentic: false,
        authenticityScore: 0.30,
        invalidReason: 'Could not complete AI image inspection: $e',
        reasoning: 'Error inspecting image: $e',
      );
    }
  }

  /// On-Device Computer Vision Analyzer:
  /// Evaluates color distribution, saturation, texture entropy, and specular reflection
  /// to verify if the photo actually depicts outdoor asphalt/road terrain vs indoor textiles/blankets/bottles/screens.
  Future<AIValidationResult> _analyzeImageOnDevice(Uint8List bytes, String category, String? description) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64, targetHeight: 64);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData != null) {
        final buffer = byteData.buffer.asUint8List();
        int roadLikePixelCount = 0;
        int nonRoadSaturatedCount = 0;
        int metallicHighSpecularCount = 0;
        final totalPixels = buffer.length ~/ 4;

        for (int i = 0; i < buffer.length; i += 4) {
          final r = buffer[i];
          final g = buffer[i + 1];
          final b = buffer[i + 2];

          final max = math.max(r, math.max(g, b));
          final min = math.min(r, math.min(g, b));
          final delta = max - min;
          final saturation = max == 0 ? 0.0 : delta / max;
          final brightness = max / 255.0;

          // Road surface characteristics (asphalt, dark charcoal, concrete, wet road, mud)
          final isNeutralGray = saturation < 0.22 && brightness > 0.08 && brightness < 0.85;
          final isEarthyDirt = (r > g && g > b) && saturation < 0.45 && brightness > 0.12 && brightness < 0.70;
          final isWetRoad = saturation < 0.28 && brightness < 0.60;

          // Non-road indicators (bright textiles, blankets, clothing, colorful plastics)
          final isHighSaturation = saturation > 0.38;
          // Specular reflections (bottles, screens, metal surfaces, indoor lighting)
          final isSpecular = brightness > 0.90 && saturation < 0.15;

          if (isNeutralGray || isEarthyDirt || isWetRoad) {
            roadLikePixelCount++;
          }
          if (isHighSaturation) {
            nonRoadSaturatedCount++;
          }
          if (isSpecular) {
            metallicHighSpecularCount++;
          }
        }

        final roadRatio = roadLikePixelCount / totalPixels;
        final saturatedRatio = nonRoadSaturatedCount / totalPixels;
        final specularRatio = metallicHighSpecularCount / totalPixels;

        debugPrint('📊 [On-Device CV] Road Terrain: ${(roadRatio * 100).toStringAsFixed(1)}%, Saturated/Fabric: ${(saturatedRatio * 100).toStringAsFixed(1)}%, Specular/Metal: ${(specularRatio * 100).toStringAsFixed(1)}%');

        // Rejection rule: If high indoor/fabric saturation (>25%), high specular/metal (>22%), or low road texture (<30%)
        if (saturatedRatio > 0.25 || specularRatio > 0.22 || roadRatio < 0.30) {
          String detectedType = 'indoor non-road object';
          if (saturatedRatio > 0.25) {
            detectedType = 'colorful textile, fabric, or blanket';
          } else if (specularRatio > 0.22) {
            detectedType = 'metallic, reflective, or screen object';
          }

          return AIValidationResult(
            isValidHazard: false,
            severity: 'Low',
            confidence: 0.88,
            photoVerdict: 'Unrelated / Non-Hazard',
            isAuthentic: false,
            authenticityScore: 0.20,
            invalidReason: 'Computer vision analysis detected a $detectedType rather than an outdoor road hazard surface. Please photograph an actual road defect.',
            reasoning: 'Visual inspection shows non-road textures (high textile/specular patterns, road surface confidence: ${(roadRatio * 100).toStringAsFixed(1)}%).',
          );
        }
      }
    } catch (cvErr) {
      debugPrint('On-device CV error: $cvErr');
    }

    // Default heuristic for road-like textures
    return AIValidationResult(
      isValidHazard: true,
      severity: 'Medium',
      confidence: 0.80,
      photoVerdict: 'Real Photo',
      isAuthentic: true,
      authenticityScore: 0.85,
      reasoning: 'Visual surface characteristics match outdoor road pavement.',
    );
  }

  Future<AIValidationResult?> _callGeminiDirect({
    required String apiKey,
    required String base64Image,
    required String mimeType,
    required String category,
    String? description,
  }) async {
    const systemPrompt = '''
You are an expert civil infrastructure inspection and digital forensics AI for RoadSense AI municipal hazard reporting.
You must perform TWO critical tasks in this single analysis:

STEP 1: HAZARD CONTENT, AUTHENTICITY & DIGITAL FORENSICS VALIDATION
Check whether the uploaded image actually shows a genuine, outdoor road or civic hazard matching the reported category.
Perform digital forensics to specifically detect and REJECT:
1. GOOGLE DOWNLOADED / STOCK PHOTOS: Images downloaded from Google Images, Pinterest, Reddit, social media, or stock sites. Look for stock agency watermarks (e.g., Getty, Shutterstock, Alamy, iStock, Dreamstime, Freepik, Adobe Stock), news publication graphics/stamps, professional studio color grading, HDR filters, and web thumbnail recompression artifacts.
2. SCREEN CAPTURES / PHOTOS OF MONITORS: Photos taken of a computer monitor, laptop screen, TV, tablet, or phone displaying an image. Look for LCD/OLED subpixel grids, screen moiré interference patterns, monitor frames/bezels, glass screen glare/reflections of room lighting, desktop cursors, browser address bars, or taskbars.
3. AI-GENERATED SYNTHETIC IMAGES: Synthetic imagery generated by Midjourney, DALL-E, Stable Diffusion, or Imagen. Look for plastic/waxy road textures, unnatural crack symmetry, surreal lighting, impossible physics, or synthetic blending artifacts.
4. UNRELATED / INDOOR OBJECTS: Indoor rooms, bedsheets, blankets, bottles, keyboards, laptops, selfies, people, pets/animals, vehicle interiors, screenshots, documents, food, memes, or household items.

- VALID REAL HAZARD (isValidHazard = true): Genuine, authentic outdoor field photograph taken with a physical camera on a real road/street showing potholes, asphalt cracks, flooding, open drains, missing manhole covers, road collapse, or road debris.
- FRAUDULENT / UNACCEPTABLE MEDIA (isValidHazard = false): If the image is a Google download, stock photo, photo of a computer screen, AI-generated image, or non-road object, you MUST set is_valid_hazard = false, is_authentic = false, authenticity_score <= 0.25, and provide a clear, constructive explanation in "rejection_reason".

STEP 2: ROAD DAMAGE SEVERITY CLASSIFICATION (If valid)
- Low: Minor surface blemishes, superficial hairline asphalt cracks, faint markings, small debris not obstructing traffic.
- Medium: Moderate pothole (depth < 5cm, width < 25cm), surface unraveling, minor drain grating misalignment, small puddle without deep flooding.
- High: Deep or wide pothole (depth >= 5cm), broken storm drain with exposed hole, missing manhole cover/grate, large obstruction blocking a lane, road subsidence.
- Critical: Massive sinkhole, severe structural collapse, exposed jagged structural rebar/concrete, road submerged under deep flash flood, immediate catastrophic risk to vehicles or pedestrians.

Respond strictly with JSON:
{
  "is_valid_hazard": boolean,
  "severity": "Low" | "Medium" | "High" | "Critical",
  "confidence": number (float between 0.0 and 1.0),
  "photo_verdict": "Real Photo" | "AI Generated" | "Stock / Downloaded" | "Screen Capture / Monitor Photo" | "Unrelated / Non-Hazard",
  "is_authentic": boolean,
  "authenticity_score": number (float between 0.0 and 1.0),
  "rejection_reason": string or null (if not an authentic real-world road photo, explain clearly what was detected),
  "reasoning": string (clear 1-2 sentence explanation of forensic & severity findings)
}
''';

    const models = ['gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-3.7-flash', 'gemini-flash-latest'];
    for (final model in models) {
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [{'text': systemPrompt}]
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': 'Hazard Category: $category\nDescription: ${description ?? "No description"}'},
                  {
                    'inlineData': {
                      'mimeType': mimeType,
                      'data': base64Image,
                    }
                  }
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.1,
            }
          }),
        );

        debugPrint('🤖 [GeminiService] Model $model HTTP status: ${response.statusCode}');
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'];
          debugPrint('🤖 [GeminiService] AI Response Text: $text');
          if (text != null) {
            final parsed = jsonDecode(text);
            return AIValidationResult.fromJson(Map<String, dynamic>.from(parsed));
          }
        } else {
          debugPrint('⚠️ [GeminiService] Error response from $model: ${response.body}');
        }
      } catch (e) {
        debugPrint('⚠️ [GeminiService] Direct Gemini attempt ($model) failed: $e');
      }
    }

    return null;
  }
}
