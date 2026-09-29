import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    let severity = body.severity;
    let duplicateReports = body.duplicate_reports ?? body.duplicateReports ?? body.duplicate_count ?? body.upvote_count;
    let hazardType = body.hazard_type || body.hazardType || body.category;
    let timeOpenHours = body.time_open_hours ?? body.hours_open;
    let timeOpenDays = body.time_open_days ?? body.days_open;
    let createdAt = body.created_at || body.timestamp;

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseClient = createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false },
    });

    // If complaint_id is provided, retrieve missing fields from complaints / ai_assessments
    if (complaintId) {
      const { data: complaint } = await supabaseClient
        .from("complaints")
        .select("id, category, severity, upvote_count, created_at")
        .eq("id", complaintId)
        .maybeSingle();

      if (complaint) {
        if (!hazardType) hazardType = complaint.category;
        if (!severity) severity = complaint.severity;
        if (duplicateReports == null && complaint.upvote_count != null) {
          duplicateReports = Math.max(0, complaint.upvote_count - 1);
        }
        if (!createdAt) createdAt = complaint.created_at;
      }

      // If severity is still missing, check ai_assessments table
      if (!severity) {
        const { data: assessment } = await supabaseClient
          .from("ai_assessments")
          .select("severity")
          .eq("complaint_id", complaintId)
          .maybeSingle();

        if (assessment?.severity) {
          severity = assessment.severity;
        }
      }
    }

    // Default values
    severity = severity || "Medium";
    hazardType = hazardType || "road hazard";
    const duplicates = typeof duplicateReports === "number" ? Math.max(0, duplicateReports) : 0;

    // Calculate hours open
    let totalHoursOpen = 0;
    if (timeOpenHours != null) {
      totalHoursOpen = Number(timeOpenHours);
    } else if (timeOpenDays != null) {
      totalHoursOpen = Number(timeOpenDays) * 24;
    } else if (createdAt) {
      const createdDate = new Date(createdAt);
      const now = new Date();
      totalHoursOpen = Math.max(0, (now.getTime() - createdDate.getTime()) / (1000 * 60 * 60));
    }

    // 1. Severity Score (0 - 45 points)
    let severityScore = 20;
    let slaHours = 72; // default SLA
    const normSeverity = String(severity).toLowerCase();

    if (normSeverity.includes("crit") || normSeverity.includes("danger")) {
      severityScore = 45;
      slaHours = 12;
    } else if (normSeverity.includes("high")) {
      severityScore = 35;
      slaHours = 24;
    } else if (normSeverity.includes("med")) {
      severityScore = 20;
      slaHours = 72;
    } else if (normSeverity.includes("low") || normSeverity.includes("minor")) {
      severityScore = 10;
      slaHours = 168; // 7 days
    }

    // 2. Duplicate Reports Score (0 - 30 points)
    // Up to 5 duplicate reports, each adding 6 points
    const duplicateScore = Math.min(duplicates * 6, 30);

    // 3. Time Open Score (0 - 15 points)
    // +3 points per 24 hours (day) open, max 15 points after 5 days
    const timeScore = Math.min((totalHoursOpen / 24) * 3, 15);

    // 4. Hazard Type Base Weight (0 - 10 points)
    const normHazard = String(hazardType).toLowerCase();
    let hazardScore = 5;
    if (
      normHazard.includes("flood") ||
      normHazard.includes("sinkhole") ||
      normHazard.includes("drain") ||
      normHazard.includes("collapse")
    ) {
      hazardScore = 10;
    } else if (normHazard.includes("pothole") || normHazard.includes("manhole")) {
      hazardScore = 8;
    } else {
      hazardScore = 5;
    }

    // Compute final priority score (0 - 100)
    const rawTotal = severityScore + duplicateScore + timeScore + hazardScore;
    const priorityScore = Math.min(100, Math.max(0, Math.round(rawTotal)));

    // Determine Priority Label
    let priorityLabel: "Low" | "Medium" | "High" | "Urgent" = "Low";
    if (priorityScore >= 80) {
      priorityLabel = "Urgent";
    } else if (priorityScore >= 60) {
      priorityLabel = "High";
    } else if (priorityScore >= 35) {
      priorityLabel = "Medium";
    } else {
      priorityLabel = "Low";
    }

    const responsePayload = {
      priorityScore,
      priorityLabel,
    };

    // Write result to database if complaint_id is available
    if (complaintId) {
      // 1. Update complaints table
      try {
        await supabaseClient
          .from("complaints")
          .update({
            severity: severity,
          })
          .eq("id", complaintId);
      } catch (err) {
        console.warn("Could not update complaints table:", err);
      }

      // 2. Create or update work_orders table
      const slaDeadline = new Date(Date.now() + slaHours * 60 * 60 * 1000).toISOString();
      try {
        const { error: woError } = await supabaseClient
          .from("work_orders")
          .upsert(
            {
              complaint_id: complaintId,
              priority: priorityLabel,
              stage: "Assigned",
              sla_deadline: slaDeadline,
            },
            { onConflict: "complaint_id" }
          );

        if (woError) {
          // If upsert fails (e.g. missing primary key constraint), attempt standard insert
          await supabaseClient
            .from("work_orders")
            .insert({
              complaint_id: complaintId,
              priority: priorityLabel,
              stage: "Assigned",
              sla_deadline: slaDeadline,
            })
            .catch(() => {});
        }
      } catch (err) {
        console.warn("Could not update work_orders table:", err);
      }
    }

    return new Response(JSON.stringify(responsePayload), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error: any) {
    console.error("compute-priority error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message || "An unexpected error occurred" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
