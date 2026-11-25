
const env=(name:string):string=>{
  const v=Deno.env.get(name);
  if(!v||v.startsWith("YOUR_"))throw new Error("Missing "+name);
  return v;
};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{
  status,headers:{"Content-Type":"application/json","Cache-Control":"no-store",
  "Access-Control-Allow-Origin":"null",
  "Access-Control-Allow-Headers":"authorization,apikey,content-type",
  "Access-Control-Allow-Methods":"POST,OPTIONS"}
});
async function db(path:string,method:string,body?:unknown,extra:Record<string,string>={}){
  const key=env("SUPABASE_SERVICE_ROLE_KEY");
  const headers:Record<string,string>={apikey:key,"Content-Type":"application/json",...extra};
  if(!key.startsWith("sb_secret_"))headers.Authorization="Bearer "+key;
  const res=await fetch(env("SUPABASE_URL")+"/rest/v1/"+path,{
    method,headers,...(body===undefined?{}:{body:JSON.stringify(body)})
  });
  if(!res.ok)throw new Error("DB "+res.status);
  const text=await res.text();
  return text?JSON.parse(text):null;
}
async function hash(bytes:Uint8Array):Promise<Uint8Array>{
  return new Uint8Array(await crypto.subtle.digest("SHA-256",bytes));
}
const utf8=(s:string)=>new TextEncoder().encode(s);
const b64url=(bytes:Uint8Array)=>btoa(String.fromCharCode(...bytes)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/g,"");
async function limit(req:Request){
  const ip=req.headers.get("cf-connecting-ip")||
    req.headers.get("x-real-ip")||"unknown";
  const key=await crypto.subtle.importKey("raw",
    utf8(Deno.env.get("HMC_RATE_SALT")||env("SUPABASE_SERVICE_ROLE_KEY")),
    {name:"HMAC",hash:"SHA-256"},false,["sign"]);
  const digest=new Uint8Array(await crypto.subtle.sign("HMAC",key,utf8("lookup|"+ip)));
  const identity=Array.from(digest).map(x=>x.toString(16).padStart(2,"0")).join("");
  return await db("rpc/hmc_check_rate_limit","POST",{p_identity_hash:identity,p_max:30,p_window_seconds:600})===true;
}
async function googleAccessToken(){
  const acct=JSON.parse(env("GOOGLE_SERVICE_ACCOUNT_JSON"));
  if(typeof acct.private_key!=="string"||typeof acct.client_email!=="string")throw new Error("Invalid service account");
  const keyBytes=Uint8Array.from(atob(acct.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,"")),c=>c.charCodeAt(0));
  const privateKey=await crypto.subtle.importKey("pkcs8",keyBytes,{name:"RSASSA-PKCS1-v1_5",hash:"SHA-256"},false,["sign"]);
  const now=Math.floor(Date.now()/1000);
  const header=b64url(utf8(JSON.stringify({alg:"RS256",typ:"JWT"})));
  const claims=b64url(utf8(JSON.stringify({
    iss:acct.client_email,
    scope:"https://www.googleapis.com/auth/playintegrity",
    aud:"https://oauth2.googleapis.com/token",
    iat:now,exp:now+3000
  })));
  const text=header+"."+claims;
  const sig=await crypto.subtle.sign("RSASSA-PKCS1-v1_5",privateKey,utf8(text));
  const jwt=text+"."+b64url(new Uint8Array(sig));
  const resp=await fetch("https://oauth2.googleapis.com/token",{
    method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},
    body:new URLSearchParams({
      grant_type:"urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion:jwt
    })
  });
  if(!resp.ok)throw new Error("Google account authorization unavailable");
  const token=await resp.json();
  if(typeof token.access_token!=="string")throw new Error("Google token missing");
  return token.access_token;
}
async function googleVerdict(token:string,challengeId:string,secret:string,serial:string){
  const pkg=env("ANDROID_PACKAGE_NAME");
  const cert=env("ANDROID_CERT_SHA256");
  const licenseRequired=env("GOOGLE_REQUIRE_LICENSED")==="true";
  const wanted=b64url(await hash(utf8("HMC_VERIFY_V1\n"+challengeId+"\n"+secret+"\n"+serial)));
  const access=await googleAccessToken();
  const resp=await fetch(
    "https://playintegrity.googleapis.com/v1/"+encodeURIComponent(pkg)+":decodeIntegrityToken",{
    method:"POST",headers:{"Content-Type":"application/json",Authorization:"Bearer "+access},
    body:JSON.stringify({integrity_token:token})
  });
  if(!resp.ok)throw new Error("Play Integrity unavailable "+resp.status);
  const payload=(await resp.json()).tokenPayloadExternal;
  const details=payload?.requestDetails||{};
  const app=payload?.appIntegrity||{};
  const device=payload?.deviceIntegrity||{};
  const account=payload?.accountDetails||{};
  const millis=Number(details.timestampMillis);
  return Number.isFinite(millis)&&Math.abs(Date.now()-millis)<=120000
    && details.requestHash===wanted
    && details.requestPackageName===pkg
    && app.packageName===pkg
    && app.appRecognitionVerdict==="PLAY_RECOGNIZED"
    && Array.isArray(app.certificateSha256Digest)
    && app.certificateSha256Digest.includes(cert)
    && Array.isArray(device.deviceRecognitionVerdict)
    && device.deviceRecognitionVerdict.includes("MEETS_DEVICE_INTEGRITY")
    && (!licenseRequired||account.appLicensingVerdict==="LICENSED");
}
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:{
    "Access-Control-Allow-Origin":"null",
    "Access-Control-Allow-Headers":"authorization,apikey,content-type",
    "Access-Control-Allow-Methods":"POST,OPTIONS"}});
  if(req.method!=="POST")return reply({error:"method_not_allowed"},405);
  try{
    // Never permit iOS until a real App Attest verifier is provisioned.
    const input=await req.json();
    if(input?.platform!=="android")return reply({error:"platform_not_enabled"},403);
    const serial=typeof input.serial_number==="string"
      ?input.serial_number.replace(/[\s-]/g,"").toUpperCase():"";
    const id=input?.challenge_id;
    const token=input?.integrity_token;
    if(!/^[A-Z0-9_./:]{6,80}$/.test(serial)
      ||typeof id!=="string"
      ||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)
      ||typeof token!=="string"||token.length<40||token.length>30000)
      return reply({error:"invalid_request"},400);
    if(!(await limit(req)))return reply({error:"rate_limited"},429);
    const query="hmc_integrity_challenges?id=eq."+encodeURIComponent(id)
      +"&purpose=eq.verify&consumed_at=is.null&expires_at=gt."
      +encodeURIComponent(new Date().toISOString())+"&select=challenge&limit=1";
    const rows=await db(query,"GET");
    if(!Array.isArray(rows)||rows.length!==1)
      return reply({error:"invalid_or_expired_challenge"},403);
    if(!(await googleVerdict(token,id,rows[0].challenge,serial)))
      return reply({error:"app_integrity_failed"},403);
    const consumed=await db("rpc/hmc_consume_challenge","POST",{p_id:id,p_purpose:"verify"});
    if(consumed!==rows[0].challenge)return reply({error:"challenge_already_used"},403);
    const found=await db(
      "hmc_devices?serial_number=eq."+encodeURIComponent(serial)
        +"&status=eq.sold&select=id&limit=1",
      "GET"
    );
    return reply({confirmed:Array.isArray(found)&&found.length>0});
  }catch(e){
    console.error("serial_verification_unavailable",e instanceof Error?e.message:"unknown");
    return reply({error:"verification_unavailable"},503);
  }
});
