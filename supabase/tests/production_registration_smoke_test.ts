const endpoint="https://obloojlkjnagpdokofgw.supabase.co/functions/v1/register-ios";
async function send(data:unknown){
 return fetch(endpoint,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(data),signal:AbortSignal.timeout(15000)});
}
Deno.test("Live production registration rejects a fabricated challenge",async()=>{
 const response=await send({challenge_id:"1d2f6b9a-1111-4444-8aaa-112233445566",key_id:"A".repeat(48),attestation_object:"A".repeat(200)});
 if(response.status!==403) throw Error("Unexpected HTTP "+response.status);
});
Deno.test("Live production registration rejects malformed input",async()=>{
 const response=await send({challenge_id:"invalid",key_id:"A".repeat(48),attestation_object:"fake"});
 if(response.status!==400) throw Error("Unexpected HTTP "+response.status);
});
