import { checkIosSerial } from "./ios_check.ts";

const request = () => new Request("https://example.invalid/check-serial", {
  method: "POST",
  headers: { "content-type": "application/json" },
});

Deno.test("iOS rejects missing assertion before accessing database", async () => {
  const response = await checkIosSerial(request(), {
    platform: "ios",
    serial_number: "ABC123456",
    challenge_id: "a08bd124-99d4-4a22-81cc-6cb3bdc4291d",
    key_id: "abcdefghijklmnopqrstuvwxyz0123456789",
  });
  if (response.status !== 400) throw new Error("Expected HTTP 400");
});

Deno.test("iOS rejects invalid serial before accessing database", async () => {
  const response = await checkIosSerial(request(), {
    platform: "ios",
    serial_number: "INVALID!",
    challenge_id: "a08bd124-99d4-4a22-81cc-6cb3bdc4291d",
    key_id: "abcdefghijklmnopqrstuvwxyz0123456789",
    assertion_object: "a".repeat(100),
  });
  if (response.status !== 400) throw new Error("Expected HTTP 400");
});

Deno.test("iOS rejects malformed challenge ID before accessing database", async () => {
  const response = await checkIosSerial(request(), {
    platform: "ios",
    serial_number: "ABC123456",
    challenge_id: "made-up-challenge",
    key_id: "abcdefghijklmnopqrstuvwxyz0123456789",
    assertion_object: "a".repeat(100),
  });
  if (response.status !== 400) throw new Error("Expected HTTP 400");
});
