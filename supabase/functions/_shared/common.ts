
export const configured = (name: string): string => {
  const v = Deno.env.get(name);
  if (!v || v.startsWith("YOUR_") || v.startsWith("SET_")) throw new Error("Missing " + name);
  return v;
};
const creds = () => ({
  url: configured("SUPABASE_URL"),
  key: configured("SUPABASE_SERVICE_ROLE_KEY")
});
export async function database(table:string, method:string, query="", body?:unknown, extra:Record<string,string>={}) {
  const {url,key}=creds();
  const headers:Record<string,string>={
    apikey:key, "Content-Type":"application/json",...extra
  };
  if(!key.startsWith("sb_secret_")) headers.Authorization="Bearer " + key;
  const res = await fetch(url+"/rest/v1/"+table+query,{
    method,headers,...(body===undefined?{}:{body:JSON.stringify(body)})
  });
  if(!res.ok) throw new Error("DB request failed " + res.status);
  const content=await res.text();
  return content?JSON.parse(content):null;
}
export async function rpc(name:string,body:unknown){
  return database("rpc/"+name,"POST","",body);
}
export async function sha256(s:string):Promise<Uint8Array>{
  return new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s)));
}
export const base64url=(bytes:Uint8Array)=>btoa(String.fromCharCode(...bytes)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/g,"");
export const validSerial=(value:unknown):string=>{
  if(typeof value!=="string")return "";
  const s=value.replace(/[\s-]/g,"").toUpperCase();
  return /^[A-Z0-9_./:]{6,80}$/.test(s)?s:"";
};
export const allowedOrigin=(req:Request):string=>{
  const origin=req.headers.get("origin")||"";
  const allow=Deno.env.get("HMC_ADMIN_ORIGIN")||"";
  return origin && allow && origin===allow ? origin : "null";
};
export const respond=(req:Request, data:unknown, status=200):Response=>
  new Response(JSON.stringify(data),{status,headers:{
    "Content-Type":"application/json", "Cache-Control":"no-store",
    "Access-Control-Allow-Origin":allowedOrigin(req),
    "Access-Control-Allow-Headers":"authorization,apikey,content-type",
    "Access-Control-Allow-Methods":"POST,OPTIONS",
    "Vary":"Origin"
  }});
export const preflight=(req:Request)=>new Response(null,{status:204,headers:{
  "Access-Control-Allow-Origin":allowedOrigin(req),
  "Access-Control-Allow-Headers":"authorization,apikey,content-type",
  "Access-Control-Allow-Methods":"POST,OPTIONS",
  "Vary":"Origin"
}});
export async function withinLimit(req:Request,scope:string,max=30):Promise<boolean>{
  // Use only reverse-proxy IP headers. Never trust arbitrary client X-Forwarded-For.
  const ip=req.headers.get("cf-connecting-ip")||
           req.headers.get("x-real-ip") || "unknown";
  // HMAC prevents reversible IP hashing; an injected server secret is the
  // fallback while the optional dedicated rate salt has not been configured.
  const key=await crypto.subtle.importKey("raw",
    new TextEncoder().encode(Deno.env.get("HMC_RATE_SALT")||configured("SUPABASE_SERVICE_ROLE_KEY")),
    {name:"HMAC",hash:"SHA-256"},false,["sign"]);
  const hash=new Uint8Array(await crypto.subtle.sign("HMAC",key,
    new TextEncoder().encode(scope+"|"+ip)));
  const hex=Array.from(hash).map(b=>b.toString(16).padStart(2,"0")).join("");
  return (await rpc("hmc_check_rate_limit",{p_identity_hash:hex,p_max:max,p_window_seconds:600}))===true;
}
