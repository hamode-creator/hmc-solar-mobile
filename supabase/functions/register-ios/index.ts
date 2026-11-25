import { database, preflight, respond, rpc, withinLimit } from "../_shared/common.ts";
import { verifyIosRegistration } from "../_shared/ios_app_attest.ts";

// This handler is intentionally staged in GitHub only. Do not deploy until
// signed physical-iPhone end-to-end tests validate the Apple plugin payload.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return preflight(req);
  if (req.method !== "POST") return respond(req, { error: "method_not_allowed" }, 405);

  try {
    if (!(await withinLimit(req, "ios-register", 12))) {
      return respond(req, { error: "rate_limited" }, 429);
    }
    const raw = await req.text();
    if (raw.length > 32768) return respond(req, { error: "invalid_request" }, 400);

    let body: unknown;
    try { body = JSON.parse(raw); }
    catch { return respond(req, { error: "invalid_json" }, 400); }

    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return respond(req, { error: "invalid_request" }, 400);
    }
    const input = body as Record<string, unknown>;
    const { challenge_id: challengeId, key_id: keyId, attestation_object: attestation } = input;
    if (typeof challengeId !== "string" || !UUID.test(challengeId) ||
        typeof keyId !== "string" || keyId.length < 32 || keyId.length > 256 ||
        typeof attestation !== "string" || attestation.length < 80 || attestation.length > 30000) {
      return respond(req, { error: "invalid_request" }, 400);
    }

    const query = "hmc_integrity_challenges?id=eq." + encodeURIComponent(challengeId) +
      "&purpose=eq.ios-register&consumed_at=is.null&expires_at=gt." +
      encodeURIComponent(new Date().toISOString()) + "&select=challenge&limit=1";
    const rows = await database(query.split("?")[0], "GET", "?" + query.split("?")[1]);
    if (!Array.isArray(rows) || rows.length !== 1 || typeof rows[0].challenge !== "string") {
      return respond(req, { error: "invalid_or_expired_challenge" }, 403);
    }

    // Verify Apple's certificate chain, nonce, key binding and environment
    // BEFORE atomically persisting the public key and consuming the challenge.
    let verified;
    try { verified = await verifyIosRegistration(keyId, rows[0].challenge, attestation); }
    catch { return respond(req, { error: "app_attestation_failed" }, 403); }

    const registered = await rpc("hmc_register_ios_attested_key", {
      p_key_id: keyId,
      p_spki_base64: verified.publicKeySpkiBase64,
      p_environment: verified.environment,
      p_challenge_id: challengeId,
      p_challenge: rows[0].challenge,
    });
    if (registered !== true) {
      return respond(req, { error: "invalid_or_used_challenge" }, 403);
    }
    return respond(req, { registered: true });
  } catch (e) {
    console.error("ios_registration_unavailable", e instanceof Error ? e.message : "unknown");
    return respond(req, { error: "registration_unavailable" }, 503);
  }
});
