import { database, respond, rpc, validSerial, withinLimit } from "./common.ts";
import { verifyIosRequest } from "./ios_app_attest.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * iOS-only path. The Android branch is deliberately unchanged.
 * Never return an inventory result without a genuine, fresh App Attest assertion.
 */
export async function checkIosSerial(req: Request, input: Record<string, unknown>): Promise<Response> {
  const serial = validSerial(input.serial_number);
  const id = input.challenge_id;
  const keyId = input.key_id;
  const assertion = input.assertion_object;
  if (!serial || typeof id !== "string" || !UUID.test(id) ||
      typeof keyId !== "string" || keyId.length < 32 || keyId.length > 256 ||
      typeof assertion !== "string" || assertion.length < 30 || assertion.length > 30000) {
    return respond(req, { error: "invalid_request" }, 400);
  }

  try {
    if (!(await withinLimit(req, "lookup", 30))) {
      return respond(req, { error: "rate_limited" }, 429);
    }

    // Load the trusted one-time challenge; never use challenge data from the client.
    const challengeQuery = "?id=eq." + encodeURIComponent(id) +
      "&purpose=eq.verify&consumed_at=is.null&expires_at=gt." +
      encodeURIComponent(new Date().toISOString()) + "&select=challenge&limit=1";
    const challenges = await database("hmc_integrity_challenges", "GET", challengeQuery);
    if (!Array.isArray(challenges) || challenges.length !== 1 ||
        typeof challenges[0].challenge !== "string") {
      return respond(req, { error: "invalid_or_expired_challenge" }, 403);
    }

    // A registered public key is trusted only if it was verified at registration.
    const keys = await database("hmc_ios_attested_keys", "GET",
      "?key_id=eq." + encodeURIComponent(keyId) +
      "&environment=eq.production&select=public_key_spki_base64,sign_count&limit=1");
    if (!Array.isArray(keys) || keys.length !== 1 ||
        typeof keys[0].public_key_spki_base64 !== "string" ||
        typeof keys[0].sign_count !== "number" ||
        !Number.isSafeInteger(keys[0].sign_count)) {
      return respond(req, { error: "unregistered_device" }, 403);
    }

    let nextCounter: number;
    try {
      nextCounter = await verifyIosRequest(
        assertion, id, challenges[0].challenge, serial,
        keys[0].public_key_spki_base64, keys[0].sign_count,
      );
    } catch {
      return respond(req, { error: "app_integrity_failed" }, 403);
    }

    // This transaction must atomically advance the counter AND consume the challenge.
    // Concurrent/replayed requests fail even if they previously passed signature checks.
    const accepted = await rpc("hmc_accept_ios_assertion", {
      p_key_id: keyId,
      p_next_counter: nextCounter,
      p_challenge_id: id,
      p_expected_challenge: challenges[0].challenge,
    });
    if (accepted !== true) {
      return respond(req, { error: "challenge_already_used" }, 403);
    }

    const found = await database("hmc_devices", "GET",
      "?serial_number=eq." + encodeURIComponent(serial) +
      "&status=eq.sold&select=id&limit=1");
    return respond(req, { confirmed: Array.isArray(found) && found.length > 0 });
  } catch (error) {
    console.error("ios_verification_unavailable",
      error instanceof Error ? error.message : "unknown");
    return respond(req, { error: "verification_unavailable" }, 503);
  }
}
