
import {
  verifyIosRegistration,
  verifyIosRequest,
  iosBoundClientData,
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

Deno.test("iOS signed request uses exact client/server canonical data", () => {
  const id = "a08bd124-99d4-4a22-81cc-6cb3bdc4291d";
  const nonce = "secure-server-challenge-123456";
  const serial = "ABC123456";
  const bound = iosBoundClientData(id, nonce, serial);
  if (bound !== ["HMC_VERIFY_V1", id, nonce, serial].join("\n")) {
    throw new Error("iOS client/server canonical request mismatch");
  }
});

Deno.test("iOS signing payload binds serial, nonce and challenge id independently", () => {
  const base = iosBoundClientData("id-1", "nonce-1", "ABC123456");
  const variations = [
    iosBoundClientData("id-2", "nonce-1", "ABC123456"),
    iosBoundClientData("id-1", "nonce-2", "ABC123456"),
    iosBoundClientData("id-1", "nonce-1", "ABC123457"),
  ];
  if (variations.some((value) => value === base)) {
    throw new Error("A changed serial or challenge retained the same signed data");
  }
});
