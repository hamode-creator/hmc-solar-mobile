
import {
  verifyAttestation,
  verifyAssertion,
} from "jsr:@bradford-tech/supabase-integrity-attest@0.9.1";

const APP_ID = "T86B3X9456.com.hmcsolar.verify";

// Verify a genuine Apple App Attest registration.
// The challenge MUST come from the trusted server database.
export async function verifyIosRegistration(
  keyId: string,
  storedChallenge: string,
  attestationObject: string,
) {
  if (
    !keyId ||
    !storedChallenge ||
    storedChallenge.length < 16 ||
    !attestationObject
  ) {
    throw new Error("Invalid registration input");
  }

  const clientDataHash = new Uint8Array(
    await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(storedChallenge),
    ),
  );

  const result = await verifyAttestation(
    {
      appId: APP_ID,
      developmentEnv: false,
    },
    keyId,
    clientDataHash,
    attestationObject,
  );

  if (result.signCount !== 0) {
    throw new Error("Invalid initial counter");
  }

  const publicKeySpkiBase64 = result.publicKeyPem.replace(
    /-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\s/g,
    "",
  );

  if (!publicKeySpkiBase64) {
    throw new Error("Missing verified public key");
  }

  return {
    publicKeySpkiBase64,
    environment: "production" as const,
    signCount: result.signCount,
  };
}

// Verify an assertion against a previously attested key.
// Challenge ID and challenge must be loaded from the server database.
export async function verifyIosRequest(
  assertionObject: string,
  challengeId: string,
  storedChallenge: string,
  inputSerial: string,
  publicKeySpkiBase64: string,
  previousSignCount: number,
): Promise<number> {
  const serial = inputSerial
    .replace(/[\s-]/g, "")
    .toUpperCase();

  if (!/^[A-Z0-9_./:]{6,80}$/.test(serial)) {
    throw new Error("Invalid serial number");
  }

  if (!challengeId || !storedChallenge || storedChallenge.length < 16) {
    throw new Error("Invalid server challenge");
  }

  if (
    !Number.isSafeInteger(previousSignCount) ||
    previousSignCount < 0
  ) {
    throw new Error("Invalid previous signing counter");
  }

  const publicKey = publicKeySpkiBase64.replace(/\s/g, "");

  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(publicKey)) {
    throw new Error("Invalid public key encoding");
  }

  const lines = publicKey.match(/.{1,64}/g)?.join("\n") ?? "";

  const publicKeyPem =
    `-----BEGIN PUBLIC KEY-----\n${lines}\n-----END PUBLIC KEY-----\n`;

  const trustedClientData =
    `HMC_VERIFY_V1\n${challengeId}\n${storedChallenge}\n${serial}`;

  const result = await verifyAssertion(
    { appId: APP_ID },
    assertionObject,
    trustedClientData,
    publicKeyPem,
    previousSignCount,
  );

  if (
    !Number.isSafeInteger(result.signCount) ||
    result.signCount <= previousSignCount
  ) {
    throw new Error("Invalid or replayed assertion");
  }

  return result.signCount;
}
