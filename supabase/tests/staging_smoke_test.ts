const endpoint = "https://uyinxppcgcnhfzxwqtzi.supabase.co/functions/v1/check-serial";

async function call(body: unknown): Promise<Response> {
  return fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  });
}

Deno.test("staging check-serial does not permit anonymous invalid iOS requests", async () => {
  const response = await call({
    platform: "ios",
    serial_number: "HMCSTAGINGSOLD001",
    challenge_id: "not-a-valid-uuid",
    key_id: "invalid",
    assertion_object: "fabricated",
  });
  if (response.status !== 400) {
    throw new Error(`Expected HTTP 400; got ${response.status}`);
  }
});

Deno.test("staging check-serial does not accept Android through iOS-only endpoint", async () => {
  const response = await call({ platform: "android", serial_number: "HMCSTAGINGSOLD001" });
  if (response.status !== 403) {
    throw new Error(`Expected HTTP 403; got ${response.status}`);
  }
});
