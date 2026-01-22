import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@13.10.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") as string, {
  apiVersion: "2023-10-16",
});

const supabaseUrl = Deno.env.get("SUPABASE_URL") as string;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") as string;
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") as string;

serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  if (!signature) return new Response("No signature", { status: 400 });

  try {
    const body = await req.text();
    const event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        if (session.mode === "subscription" && session.subscription) {
          const subscription = await stripe.subscriptions.retrieve(session.subscription as string);
          const userId = session.metadata?.user_id;
          if (userId) {
            await supabase.from("subscriptions").upsert({
              user_id: userId,
              stripe_customer_id: session.customer as string,
              stripe_subscription_id: subscription.id,
              status: "active",
              current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
              current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
              created_at: new Date().toISOString(),
            }, { onConflict: "user_id" });
            console.log(`✅ Subscription activated for: ${userId}`);
          }
        }
        break;
      }
      case "invoice.payment_succeeded": {
        const invoice = event.data.object as Stripe.Invoice;
        if (invoice.subscription && invoice.billing_reason === "subscription_cycle") {
          const subscription = await stripe.subscriptions.retrieve(invoice.subscription as string);
          await supabase.from("subscriptions").update({
            status: "active",
            current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
            current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
          }).eq("stripe_subscription_id", subscription.id);
        }
        break;
      }
      case "invoice.payment_failed": {
        const invoice = event.data.object as Stripe.Invoice;
        if (invoice.subscription) {
          await supabase.from("subscriptions").update({ status: "past_due" }).eq("stripe_subscription_id", invoice.subscription);
        }
        break;
      }
      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        await supabase.from("subscriptions").update({ status: "cancelled" }).eq("stripe_subscription_id", subscription.id);
        break;
      }
      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        let status = subscription.cancel_at_period_end ? "cancelling" : "active";
        if (subscription.status === "past_due") status = "past_due";
        if (subscription.status === "canceled") status = "cancelled";
        await supabase.from("subscriptions").update({
          status,
          current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
        }).eq("stripe_subscription_id", subscription.id);
        break;
      }
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 });
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(`Webhook Error: ${error.message}`, { status: 400 });
  }
});
