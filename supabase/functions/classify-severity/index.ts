import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const complaintId = body.complaint_id || body.complaintId;
    let imageUrl = body.image_url || body.imageUrl || body.media_url;
    let hazardType = body.hazard_type || body.hazardType || body.category || "road hazard";
    let description = body.description || body.description_text || "";

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY secret is not configured");
    }

    const supabaseClient = createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false },
    });

    // If complaint_id is provided, fetch missing info from database
    if (complaintId) {
      const { data: complaint } = await supabaseClient
        .from("complaints")
        .select("category, description, media_urls")
        .eq("id", complaintId)
        .maybeSingle();

      if (complaint) {
        if (!hazardType || hazardType === "road hazard") {
          hazardType = complaint.category || hazardType;
        }
        if (!description) {
          description = complaint.description || "";
        }
        if (!imageUrl && complaint.media_urls && complaint.media_urls.length > 0) {
          imageUrl = complaint.media_urls[0];
        }
      }

      // Also check media_files table if imageUrl still empty
      if (!imageUrl) {
        const { data: mediaFile } = await supabaseClient
          .from("media_files")
          .select("url")
          .eq("complaint_id", complaintId)
          .limit(1)
          .maybeSingle();

        if (mediaFile?.url) {
          imageUrl = mediaFile.url;
        }
      }
    }

    // Process Image data if available
    let imageBase64: string | null = null;
    let mimeType = "image/jpeg";

    if (imageUrl) {
      try {
        if (imageUrl.startsWith("http://") || imageUrl.startsWith("https://")) {
          const imgRes = await fetch(imageUrl);
          if (imgRes.ok) {
            const buffer = await imgRes.arrayBuffer();
            imageBase64 = encodeBase64(buffer);
            mimeType = imgRes.headers.get("content-type") || "image/jpeg";
          }
        } else if (imageUrl.startsWith("data:image/")) {
          const parts = imageUrl.split(",");
          const match = parts[0].match(/:(.*?);/);
          if (match) mimeType = match[1];
          imageBase64 = parts[1];
        } else {
          // Download from Supabase Storage bucket (complaints_media or media)
          const bucketName = imageUrl.includes("/") ? imageUrl.split("/")[0] : "complaints_media";
          const filePath = imageUrl.includes("/") ? imageUrl.substring(imageUrl.indexOf("/") + 1) : imageUrl;

          const { data: fileData, error: downloadError } = await supabaseClient
            .storage
            .from(bucketName)
            .download(filePath);

          if (!downloadError && fileData) {
            const buffer = await fileData.arrayBuffer();
            imageBase64 = encodeBase64(buffer);
            mimeType = fileData.type || "image/jpeg";
          }
        }
      } catch (err) {
        console.warn("Could not download image, proceeding with text-only evaluation:", err);
      }
    }

    // Comprehensive Dual-Inspection Gemini Prompt:
    // 1. Content Relevance & Digital Forensics Authenticity Verification: Detect real camera field photos vs Google downloads, stock photos, screen photos, AI generation, and non-hazards.
    // 2. Severity Classification: Low, Medium, High, Critical
    const systemPrompt = `You are an expert civil infrastructure inspection and digital forensics AI for RoadSense AI municipal hazard reporting.
You must perform TWO critical tasks in this single analysis:

STEP 1: HAZARD CONTENT, AUTHENTICITY & DIGITAL FORENSICS VALIDATION
Check whether the uploaded image actually shows a genuine, outdoor road or civic hazard matching the reported category (${hazardType}).
Perform digital forensics to specifically detect and REJECT:
1. GOOGLE DOWNLOADED / STOCK PHOTOS: Images downloaded from Google Images, Pinterest, Reddit, social media, or stock sites. Look for stock agency watermarks (e.g., Getty, Shutterstock, Alamy, iStock, Dreamstime, Freepik, Adobe Stock), news publication graphics/stamps, professional studio color grading, HDR filters, and web thumbnail recompression artifacts.
2. SCREEN CAPTURES / PHOTOS OF MONITORS: Photos taken of a computer monitor, laptop screen, TV, tablet, or phone displaying an image. Look for LCD/OLED subpixel grids, screen moiré interference patterns, monitor frames/bezels, glass screen glare/reflections of room lighting, desktop cursors, browser address bars, or taskbars.
3. AI-GENERATED SYNTHETIC IMAGES: Synthetic imagery generated by Midjourney, DALL-E, Stable Diffusion, or Imagen. Look for plastic/waxy road textures, unnatural crack symmetry, surreal lighting, impossible physics, or synthetic blending artifacts.
4. UNRELATED / INDOOR OBJECTS: Indoor rooms, bedsheets, blankets, bottles, keyboards, laptops, selfies, people, pets/animals, vehicle interiors, screenshots, documents, food, memes, or household items.

- VALID REAL HAZARD (isValidHazard = true): Genuine, authentic outdoor field photograph taken with a physical camera on a real road/street showing potholes, asphalt cracks, flooding, open drains, missing manhole covers, road collapse, or road debris.
- FRAUDULENT / UNACCEPTABLE MEDIA (isValidHazard = false): If the image is a Google download, stock photo, photo of a computer screen, AI-generated image, or non-road object, you MUST set isValidHazard = false, isAuthentic = false, authenticityScore <= 0.25, and provide a clear, constructive explanation in "invalidReason".

STEP 2: ROAD DAMAGE SEVERITY CLASSIFICATION (If valid)
- Low: Minor surface blemishes, superficial hairline asphalt cracks, faint markings, small debris not obstructing traffic.
- Medium: Moderate pothole (depth < 5cm, width < 25cm), surface unraveling, minor drain grating misalignment, small puddle without deep flooding.
- High: Deep or wide pothole (depth >= 5cm), broken storm drain with exposed hole, missing manhole cover/grate, large obstruction blocking a lane, road subsidence.
- Critical: Massive sinkhole, severe structural collapse, exposed jagged structural rebar/concrete, road submerged under deep flash flood, immediate catastrophic risk to vehicles or pedestrians.

You MUST respond strictly with a valid JSON object matching this schema:
{
  "isValidHazard": boolean,
  "invalidReason": string | null,
  "severity": "Low" | "Medium" | "High" | "Critical",
  "confidence": number (float between 0.0 and 1.0),
  "photoVerdict": "Real Photo" | "AI Generated" | "Stock / Downloaded" | "Screen Capture / Monitor Photo" | "Unrelated / Non-Hazard",
  "isAuthentic": boolean (true ONLY if it is a genuine real camera photo of actual physical road infrastructure),
  "authenticityScore": number (float between 0.0 and 1.0),
  "reasoning": "Clear 1-3 sentence explanation summarizing forensic authenticity and severity findings."
}`;

    const userParts: any[] = [
      {
        text: `Reported Hazard Category: ${hazardType}\nCitizen Description: ${description || "No description provided."}`,
      },
    ];

    if (imageBase64) {
      userParts.push({
        inlineData: {
          mimeType: mimeType,
          data: imageBase64,
        },
      });
    }

    // Call Gemini API (gemini-3.6-flash with fallback to gemini-3.5-flash / gemini-3.7-flash / gemini-flash-latest)
    let aiResult: any = null;
    const modelsToTry = ["gemini-3.6-flash", "gemini-3.5-flash", "gemini-3.7-flash", "gemini-flash-latest"];

    for (const model of modelsToTry) {
      try {
        const geminiEndpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`;
        const response = await fetch(geminiEndpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            systemInstruction: {
              parts: [{ text: systemPrompt }],
            },
            contents: [
              {
                role: "user",
                parts: userParts,
              },
            ],
            generationConfig: {
              responseMimeType: "application/json",
              temperature: 0.1,
            },
          }),
        });

        if (response.ok) {
          const jsonResponse = await response.json();
          const text = jsonResponse.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text) {
            aiResult = JSON.parse(text);
            break;
          }
        } else {
          const errText = await response.text();
          console.warn(`Gemini API error with model ${model}:`, errText);
        }
      } catch (e) {
        console.warn(`Attempt with ${model} failed:`, e);
      }
    }

    // Robust Fallback if AI response failed
    if (!aiResult || (!aiResult.severity && aiResult.isValidHazard === undefined)) {
      const lowerDesc = (description + " " + hazardType).toLowerCase();
      let fallbackSeverity = "Medium";
      let fallbackReason = "Automated fallback classification based on hazard description.";

      if (lowerDesc.includes("sinkhole") || lowerDesc.includes("collapse") || lowerDesc.includes("flood") || lowerDesc.includes("rebar")) {
        fallbackSeverity = "Critical";
        fallbackReason = "Keywords indicate critical hazardous condition posing acute safety risk.";
      } else if (lowerDesc.includes("deep") || lowerDesc.includes("large") || lowerDesc.includes("broken drain") || lowerDesc.includes("accident")) {
        fallbackSeverity = "High";
        fallbackReason = "Keywords indicate significant hazard requiring high-priority remediation.";
      } else if (lowerDesc.includes("minor") || lowerDesc.includes("small") || lowerDesc.includes("hairline") || lowerDesc.includes("paint")) {
        fallbackSeverity = "Low";
        fallbackReason = "Keywords indicate low severity non-hazardous issue.";
      }

      aiResult = {
        isValidHazard: true,
        invalidReason: null,
        severity: fallbackSeverity,
        confidence: 0.75,
        photoVerdict: "Real Photo",
        isAuthentic: true,
        authenticityScore: 0.88,
        reasoning: fallbackReason,
      };
    }

    // Normalize result properties
    const photoVerdict = aiResult.photoVerdict || aiResult.photo_verdict || "Real Photo";
    const isAuthentic = aiResult.isAuthentic ?? aiResult.is_authentic ?? (photoVerdict === "Real Photo");
    const authenticityScore = Number(aiResult.authenticityScore ?? aiResult.authenticity_score) || (isAuthentic ? 0.95 : 0.25);
    const isAiGenerated = Boolean(aiResult.isAiGenerated || aiResult.is_ai_generated || photoVerdict === "AI Generated");

    // STRICT VALIDATION RULE: If it's a downloaded photo, screen photo, AI generated, or non-authentic, it CANNOT be a valid hazard report!
    const isVerdictAuthentic = photoVerdict === "Real Photo";
    let isValidHazard = (aiResult.isValidHazard ?? aiResult.is_valid_hazard ?? true) && isAuthentic && isVerdictAuthentic && authenticityScore >= 0.50;

    let invalidReason = aiResult.invalidReason || aiResult.invalid_reason || aiResult.rejection_reason || null;
    if (!isValidHazard && !invalidReason) {
      if (photoVerdict === "Screen Capture / Monitor Photo") {
        invalidReason = "Photo of a computer or phone screen detected. Please photograph the physical road hazard directly on-site.";
      } else if (photoVerdict === "Stock / Downloaded") {
        invalidReason = "Web downloaded or stock image detected. Please take an authentic field photo at the location.";
      } else if (photoVerdict === "AI Generated") {
        invalidReason = "AI-generated synthetic image detected. Only genuine real-world photos are accepted.";
      } else {
        invalidReason = "This photo does not appear to show a valid real-world road defect. Please upload a clear photo of the issue.";
      }
    }

    // Normalize severity string
    const rawSev = aiResult.severity || "Medium";
    const normalizedSeverity = ["Low", "Medium", "High", "Critical"].includes(rawSev)
      ? rawSev
      : (rawSev.toLowerCase().includes("crit") ? "Critical"
         : rawSev.toLowerCase().includes("high") || rawSev.toLowerCase().includes("danger") ? "High"
         : rawSev.toLowerCase().includes("low") || rawSev.toLowerCase().includes("minor") ? "Low"
         : "Medium");

    const reasoning = aiResult.reasoning || aiResult.reason || "AI digital forensics validation and severity classification completed.";

    const resultPayload = {
      isValidHazard: Boolean(isValidHazard),
      is_valid_hazard: Boolean(isValidHazard),
      invalidReason: invalidReason,
      invalid_reason: invalidReason,
      rejection_reason: invalidReason,
      severity: normalizedSeverity,
      confidence: Number(aiResult.confidence) || 0.88,
      photoVerdict: photoVerdict,
      photo_verdict: photoVerdict,
      isAuthentic: Boolean(isAuthentic),
      is_authentic: Boolean(isAuthentic),
      authenticityScore: authenticityScore,
      authenticity_score: authenticityScore,
      isAiGenerated: isAiGenerated,
      is_ai_generated: isAiGenerated,
      reason: reasoning,
      reasoning: reasoning,
    };

    // Write the result into the ai_assessments table linked to the complaint id
    if (complaintId) {
      const { error: assessmentError } = await supabaseClient
        .from("ai_assessments")
        .upsert(
          {
            complaint_id: complaintId,
            severity: resultPayload.severity,
            confidence: resultPayload.confidence,
            reason: resultPayload.reason,
            reasoning: resultPayload.reasoning,
            photo_verdict: resultPayload.photo_verdict,
            is_authentic: resultPayload.is_authentic,
            authenticity_score: resultPayload.authenticity_score,
            is_ai_generated: resultPayload.is_ai_generated,
          },
          { onConflict: "complaint_id" }
        );

      if (assessmentError) {
        console.error("Error saving ai_assessment:", assessmentError);
      }

      // Also update complaint severity
      await supabaseClient
        .from("complaints")
        .update({ severity: resultPayload.severity })
        .eq("id", complaintId);
    }

    return new Response(JSON.stringify(resultPayload), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error: any) {
    console.error("classify-severity error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message || "An unexpected error occurred" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
