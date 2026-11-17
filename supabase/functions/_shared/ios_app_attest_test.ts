
import {
  verifyIosRegistration,
  verifyIosRequest,
} from "./ios_app_attest.ts";

async function mustReject(
  action: () => Promise<unknown>,
): Promise<void> {
  let rejected = false;

  try {
    await action();
  } catch {
    rejected = true;
  }

  if (!rejected) {
    throw new Error("Security check failed");
  }
}

Deno.test("Reject missing registration key", async () => {
  await mustReject(() =>
    verifyIosRegistration("", "valid-challenge-123456", "fake")
  );
});

Deno.test("Reject empty registration challenge", async () => {
  await mustReject(() =>
    verifyIosRegistration("test-key", "", "fake")
  );
});

Deno.test("Reject invalid serial", async () => {
  await mustReject(() =>
    verifyIosRequest(
      "fake",
      "challenge-id",
      "valid-challenge-123456",
      "INVALID!",
      "AA==",
      0,
    )
  );
});

Deno.test("Reject invalid signing counter", async () => {
  await mustReject(() =>
    verifyIosRequest(
      "fake",
      "challenge-id",
      "valid-challenge-123456",
      "ABC123456",
      "AA==",
      -1,
    )
  );
});

Deno.test("Reject missing server challenge", async () => {
  await mustReject(() =>
    verifyIosRequest(
      "fake",
      "challenge-id",
      "",
      "ABC123456",
      "AA==",
      0,
    )
  );
});
