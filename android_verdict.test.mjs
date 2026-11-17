import test from 'node:test';
import assert from 'node:assert/strict';
import {requestHash, verifyAndroidVerdict} from './helpers/verify-android-verdict.mjs';

const p={packageName:'com.hmcsolar.verify',certificateDigest:'CERT_BASE64URL',expectedRequestHash:'rhash',requireLicensed:true};
const valid=()=>({
  requestDetails:{requestPackageName:p.packageName,requestHash:p.expectedRequestHash,timestampMillis:String(Date.now())},
  appIntegrity:{appRecognitionVerdict:'PLAY_RECOGNIZED',packageName:p.packageName,certificateSha256Digest:[p.certificateDigest]},
  deviceIntegrity:{deviceRecognitionVerdict:['MEETS_DEVICE_INTEGRITY']},
  accountDetails:{appLicensingVerdict:'LICENSED'},
});
test('only Google-decoded, matching integrity verdicts pass',()=>{
  assert.equal(verifyAndroidVerdict(valid(),p),true);
  for(const mutation of [
    obj=>obj.requestDetails.requestHash='different',
    obj=>obj.requestDetails.requestPackageName='malicious.pkg',
    obj=>obj.requestDetails.timestampMillis=String(Date.now()-250000),
    obj=>obj.appIntegrity.packageName='malicious.pkg',
    obj=>obj.appIntegrity.appRecognitionVerdict='UNRECOGNIZED_VERSION',
    obj=>obj.appIntegrity.certificateSha256Digest=['DIFFERENT'],
    obj=>obj.deviceIntegrity.deviceRecognitionVerdict=[],
    obj=>obj.accountDetails.appLicensingVerdict='UNLICENSED',
  ]){
    const v=valid();mutation(v);assert.equal(verifyAndroidVerdict(v,p),false);
  }
  assert.equal(verifyAndroidVerdict(null,p),false);
  assert.equal(verifyAndroidVerdict(valid(),{...p,certificateDigest:''}),false);
});
test('hash is bound to both the nonce and serial and deterministic',async()=>{
  const a=await requestHash('7b345','c0ffee','123ABC');
  assert.equal(a,await requestHash('7b345','c0ffee','123ABC'));
  assert.notEqual(a,await requestHash('7b345','c0ffee','123ABD'));
  assert.notEqual(a,await requestHash('7b345','different','123ABC'));
  assert.match(a,/^[A-Za-z0-9_-]{43}$/);
});

test('Flutter and backend request hash format agrees on golden vector',async()=>{
  assert.equal(await requestHash(
    '5a1bc073-b539-4e03-92d6-36ffb173ac39',
    'a9b8c7d6e5f400112233445566778899','DEYE12345678'),
    'hzEhJRYVw-J5U2yVDd_19idCpDbDKfSckERfKmS6qEA');
});
