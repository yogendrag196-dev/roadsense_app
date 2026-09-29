import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function deg2rad(deg: number): number {
  return deg * (Math.PI / 180);
}

// Calculates Haversine distance in meters between two lat/lng points
function getHaversineDistanceMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371000; // Radius of the Earth in meters
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) *
      Math.cos(deg2rad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Parses PostGIS Point from GeoJSON, WKT, EWKB hex, or object format
function parsePointCoordinates(loc: any): { lat: number; lng: number } | null {
  if (!loc) return null;

  if (typeof loc === "object") {
    if (Array.isArray(loc.coordinates) && loc.coordinates.length >= 2) {
      return { lng: Number(loc.coordinates[0]), lat: Number(loc.coordinates[1]) };
    }
    if (loc.latitude != null && loc.longitude != null) {
      return { lat: Number(loc.latitude), lng: Number(loc.longitude) };
    }
    if (loc.lat != null && loc.lng != null) {
      return { lat: Number(loc.lat), lng: Number(loc.lng) };
    }
  }

  if (typeof loc === "string") {
    // Standard WKT format "POINT(lng lat)" or "POINT (lng lat)"
    const wktMatch = loc.match(/POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)/i);
    if (wktMatch) {
      return { lng: parseFloat(wktMatch[1]), lat: parseFloat(wktMatch[2]) };
    }

    // PostGIS EWKB / WKB Hex string
    if (/^[0-9a-fA-F]+$/.test(loc) && loc.length >= 32) {
      try {
        const hexMatches = loc.match(/.{1,2}/g);
        if (hexMatches) {
          const bytes = new Uint8Array(hexMatches.map((byte) => parseInt(byte, 16)));
          const view = new DataView(bytes.buffer);
          const isLittleEndian = bytes[0] === 1;
          let offset = 5;
          const type = view.getUint32(1, isLittleEndian);
          if ((type & 0x20000000) !== 0) {
            offset += 4; // Skip SRID
          }
          const lng = view.getFloat64(offset, isLittleEndian);
          const lat = view.getFloat64(offset + 8, isLittleEndian);
          if (!isNaN(lat) && !isNaN(lng)) {
            return { lat, lng };
          }
        }
      } catch (_) {
        // Continue to fallback
      }
    }
  }

  return null;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const complaintId = body.complaint_id || body.complaintId;
    let latitude = body.latitude ?? body.lat ?? body.gps_latitude;
    let longitude = body.longitude ?? body.lng ?? body.gps_longitude;
    let hazardType = body.hazard_type || body.hazardType || body.category;
    let timestamp = body.timestamp || body.created_at;

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseClient = createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false },
    });

    // If complaint_id is provided, retrieve missing details from complaints table
    if (complaintId) {
      const { data: complaint, error: fetchErr } = await supabaseClient
        .from("complaints")
        .select("id, category, location, created_at")
        .eq("id", complaintId)
        .maybeSingle();

      if (complaint) {
        if (!hazardType) hazardType = complaint.category;
        if (!timestamp) timestamp = complaint.created_at;
        if (latitude == null || longitude == null) {
          const parsed = parsePointCoordinates(complaint.location);
          if (parsed) {
            latitude = parsed.lat;
            longitude = parsed.lng;
          }
        }
      }
    }

    if (latitude == null || longitude == null) {
      throw new Error("GPS coordinates (latitude and longitude) are required");
    }

    if (!hazardType) {
      throw new Error("Hazard type / category is required");
    }

    const referenceDate = timestamp ? new Date(timestamp) : new Date();
    const thirtyDaysAgo = new Date(referenceDate.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

    console.log(
      `Checking duplicates for category='${hazardType}' at [${latitude}, ${longitude}] within 50m since ${thirtyDaysAgo}`
    );

    // Query existing complaints with the same hazard type reported within the last 30 days
    let query = supabaseClient
      .from("complaints")
      .select("id, category, location, created_at, status")
      .ilike("category", hazardType.trim())
      .gte("created_at", thirtyDaysAgo)
      .not("status", "in", '("completed","merged","Completed","Merged")');

    if (complaintId) {
      query = query.neq("id", complaintId);
    }

    const { data: existingComplaints, error: dbError } = await query;

    if (dbError) {
      throw new Error(`Database query failed: ${dbError.message}`);
    }

    const matchedComplaints: Array<{ id: string; distance: number }> = [];

    if (existingComplaints && existingComplaints.length > 0) {
      for (const item of existingComplaints) {
        const itemCoords = parsePointCoordinates(item.location);
        if (itemCoords) {
          const distMeters = getHaversineDistanceMeters(
            Number(latitude),
            Number(longitude),
            itemCoords.lat,
            itemCoords.lng
          );

          if (distMeters <= 50) {
            matchedComplaints.push({
              id: item.id,
              distance: Math.round(distMeters * 10) / 10,
            });
          }
        }
      }
    }

    // Sort matching complaints by distance ascending
    matchedComplaints.sort((a, b) => a.distance - b.distance);

    if (matchedComplaints.length > 0) {
      const matchedComplaintIds = matchedComplaints.map((m) => m.id);
      const closestDistance = matchedComplaints[0].distance;

      // If a complaint_id was passed, link it to the duplicate
      if (complaintId) {
        const primaryDuplicateId = matchedComplaintIds[0];

        // Mark complaint as merged
        await supabaseClient
          .from("complaints")
          .update({ status: "merged" })
          .eq("id", complaintId);

        // Update ai_assessments duplicate_of
        await supabaseClient
          .from("ai_assessments")
          .update({ duplicate_of: primaryDuplicateId })
          .eq("complaint_id", complaintId);

        // Increment upvote_count on original complaint
        const { data: origComplaint } = await supabaseClient
          .from("complaints")
          .select("upvote_count")
          .eq("id", primaryDuplicateId)
          .maybeSingle();

        const currentVotes = origComplaint?.upvote_count ?? 1;
        await supabaseClient
          .from("complaints")
          .update({ upvote_count: currentVotes + 1 })
          .eq("id", primaryDuplicateId);

        // Insert duplicate log if table exists
        await supabaseClient
          .from("duplicate_log")
          .insert({
            new_complaint_id: complaintId,
            duplicate_of_id: primaryDuplicateId,
            distance: closestDistance,
            category: hazardType,
          })
          .catch(() => {});
      }

      const responsePayload = {
        isDuplicate: true,
        matchedComplaintIds: matchedComplaintIds,
        distanceMeters: closestDistance,
      };

      return new Response(JSON.stringify(responsePayload), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    } else {
      const responsePayload = {
        isDuplicate: false,
      };

      return new Response(JSON.stringify(responsePayload), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }
  } catch (error: any) {
    console.error("detect-duplicate error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message || "An unexpected error occurred" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
