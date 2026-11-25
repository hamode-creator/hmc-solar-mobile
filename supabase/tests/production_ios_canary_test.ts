const endpoint = "https://obloojlkjnagpdokofgw.supabase.co/functions/v1/check-serial-ios-canary";
async function post(input: unknown): Promise<Response> {
  return fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
    signal: AbortSignal.timeout(16000),
  });
}

Deno.test("Production iOS canary rejects malformed proof without reading inventory", async () => {
  const response = await post({
    platform: "ios",
    serial_number: "HMCSTAGINGSOLD001",
    challenge_id: "not-a-uuid",
    key_id: "fake",
    assertion_object: "invalid",
  });
  if (response.status !== 400)
    throw new Error("Malformed request unexpectedly returned " + response.status);
});

Deno.test("Production iOS canary rejects Android platform and cannot replace Android handler", async () => {
  const response = await post({platform:"android",serial_number:"HMCSTAGINGSOLD001"});
  if (response.status !== 403)
    throw new Error("Unexpected Android response " + response.status);
});

Deno.test("Production iOS canary rejects unknown one-time challenge", async () => {
  const response = await post({
    platform: "ios",
    serial_number: "HMCSTAGINGSOLD001",
    challenge_id: "1d2f6b9a-1111-4444-8aaa-112233445566",
    key_id: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    assertion_object: "A".repeat(128),
  });
  if (response.status !== 403)
    throw new Error("Unknown challenge unexpectedly returned " + response.status);
});
