import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY");
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID");

serve(async (req) => {
  try {
    const payload = await req.json();

    // Only process UPDATE events on work_orders where stage has changed
    if (payload.type !== "UPDATE" || payload.table !== "work_orders") {
      return new Response("Not an update to work_orders", { status: 200 });
    }

    const newRecord = payload.record;
    const oldRecord = payload.old_record;

    if (newRecord.stage === oldRecord.stage) {
      return new Response("Stage unchanged, skipping", { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Fetch complaint to get citizen_id and category
    const { data: complaint, error: complaintError } = await supabase
      .from("complaints")
      .select("citizen_id, category")
      .eq("id", newRecord.complaint_id)
      .single();

    if (complaintError || !complaint) {
      console.error("Complaint not found:", complaintError);
      return new Response("Complaint not found", { status: 404 });
    }

    // 2. Fetch citizen's profile to get onesignal_id
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("onesignal_id")
      .eq("id", complaint.citizen_id)
      .single();

    if (profileError || !profile || !profile.onesignal_id) {
      console.log("No onesignal_id found for citizen, skipping notification.");
      return new Response("Citizen has no onesignal_id", { status: 200 });
    }

    // 3. Send Push Notification via OneSignal REST API
    // Mapping internal stage keys to friendly text
    const stageMap: Record<string, string> = {
      'assigned': 'Assigned',
      'en_route': 'En Route',
      'in_progress': 'Repairing',
      'completed': 'Completed'
    };
    
    const friendlyStage = stageMap[newRecord.stage] || newRecord.stage;
    const message = `Your ${complaint.category} report is now ${friendlyStage}.`;

    const oneSignalPayload = {
      app_id: ONESIGNAL_APP_ID,
      include_player_ids: [profile.onesignal_id],
      headings: { en: "Status Update" },
      contents: { en: message },
      data: { complaint_id: newRecord.complaint_id } // Custom data for deep linking
    };

    const osResponse = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`
      },
      body: JSON.stringify(oneSignalPayload)
    });

    if (!osResponse.ok) {
      const errorText = await osResponse.text();
      console.error("OneSignal API Error:", errorText);
      return new Response("Error sending notification", { status: 500 });
    }

    return new Response(JSON.stringify({ success: true, message: "Notification sent" }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Error processing webhook:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
