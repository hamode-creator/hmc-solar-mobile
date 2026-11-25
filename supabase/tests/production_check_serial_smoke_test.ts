const url="https://obloojlkjnagpdokofgw.supabase.co/functions/v1/check-serial";
async function post(data:unknown){
  return fetch(url,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(data),signal:AbortSignal.timeout(15000)});
}
Deno.test("Production check-serial rejects forged iOS requests",async()=>{
  const res=await post({platform:"ios",serial_number:"TEST123456",challenge_id:"bad",key_id:"x",assertion_object:"x"});
  if(res.status!==400)throw Error("Unexpected HTTP "+res.status);
});
Deno.test("Production check-serial rejects non-attested Android requests",async()=>{
  const res=await post({platform:"android",serial_number:"TEST123456",challenge_id:"bad",integrity_token:"x"});
  if(res.status!==400)throw Error("Unexpected HTTP "+res.status);
});
Deno.test("Production check-serial rejects arbitrary other platforms",async()=>{
  const res=await post({platform:"web",serial_number:"TEST123456"});
  if(res.status!==403)throw Error("Unexpected HTTP "+res.status);
});
Deno.test("Production check-serial rejects unknown iOS challenges before inventory",async()=>{
  const res=await post({platform:"ios",serial_number:"TEST123456",challenge_id:"f3a1b980-cf36-4e81-a9c5-001122334455",key_id:"A".repeat(48),assertion_object:"A".repeat(200)});
  if(res.status!==403)throw Error("Unexpected HTTP "+res.status);
});
