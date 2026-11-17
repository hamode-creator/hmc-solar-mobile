/** Standalone, testable Play Integrity policy. Only use on Google's DECODED server response. */
export function verifyAndroidVerdict(payload, policy, now=Date.now()) {
  if (!payload || !policy || !policy.expectedRequestHash || !policy.packageName || !policy.certificateDigest) return false;
  const details=payload.requestDetails||{};
  const app=payload.appIntegrity||{};
  const device=payload.deviceIntegrity||{};
  const account=payload.accountDetails||{};
  const millis=Number(details.timestampMillis);
  if(!Number.isFinite(millis) || Math.abs(now-millis)>120_000)return false;
  if(details.requestPackageName!==policy.packageName || details.requestHash!==policy.expectedRequestHash)return false;
  if(app.packageName!==policy.packageName || app.appRecognitionVerdict!=='PLAY_RECOGNIZED')return false;
  if(!Array.isArray(app.certificateSha256Digest)||!app.certificateSha256Digest.includes(policy.certificateDigest))return false;
  if(!Array.isArray(device.deviceRecognitionVerdict)||!device.deviceRecognitionVerdict.includes('MEETS_DEVICE_INTEGRITY'))return false;
  if(policy.requireLicensed!==false && account.appLicensingVerdict!=='LICENSED')return false;
  return true;
}
/** requestHash: binds serialized action to a server-issued, single-use challenge. */
export async function requestHash(id,challenge,serial) {
  const message=`HMC_VERIFY_V1\n${id}\n${challenge}\n${serial}`;
  const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(message)));
  return btoa(String.fromCharCode(...digest)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
}
