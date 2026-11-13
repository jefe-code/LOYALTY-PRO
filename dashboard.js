const SUPABASE_URL="https://skizdeuozmuzmehyvvtk.supabase.co";const SUPABASE_ANON_KEY="sb_publishable_-CUnJuUGEqup5MaDiGvTYg__5ITsfLI";const db=window.supabase?.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);let currentUser=null;let currentBusiness=null;
async function initDashboard(){if(!db){alert("Supabase client is unavailable.");return}const {data:{session}}=await db.auth.getSession();if(!session){location.href="index.html";return}currentUser=session.user;document.getElementById("userEmail").textContent=currentUser.email||"Business owner";document.getElementById("ownerName").textContent=".";const {data:members}=await db.from("business_members").select("business_id,role").eq("user_id",currentUser.id).limit(1);if(members?.length){const {data:business}=await db.from("businesses").select("*").eq("id",members[0].business_id).single();currentBusiness=business;document.getElementById("newBusinessName").value=business.name;document.getElementById("newBusinessSlug").value=business.slug;const {data:program}=await db.from("loyalty_programs").select("*").eq("business_id",business.id).single();if(program){document.getElementById("stampsRequired").value=program.stamps_required;document.getElementById("rewardTitle").value=program.reward_title}await loadMetrics(business.id);window.applyStudioDesign?.(business.card_design)}}
async function loadMetrics(id){const [customers,stamps,rewards,vouchers]=await Promise.all([db.from("customers").select("id",{count:"exact",head:true}).eq("business_id",id),db.from("stamp_transactions").select("id",{count:"exact",head:true}).eq("business_id",id).eq("action","stamp"),db.from("rewards").select("id",{count:"exact",head:true}).eq("business_id",id).eq("active",true),db.from("vouchers").select("id",{count:"exact",head:true}).eq("business_id",id).eq("status","redeemed")]);document.getElementById("customerCount").textContent=customers.count??"—";document.getElementById("stampCount").textContent=stamps.count??"—";document.getElementById("rewardCount").textContent=rewards.count??"—";document.getElementById("voucherCount").textContent=vouchers.count??"—";const {data:recent}=await db.from("stamp_transactions").select("action,created_at").eq("business_id",id).order("created_at",{ascending:false}).limit(4);if(recent?.length)document.getElementById("activityList").innerHTML=recent.map(x=>`<div class="activity-item"><b>${x.action==="stamp"?"Stamp added":x.action}</b><small>${new Date(x.created_at).toLocaleString()}</small></div>`).join("")}
document.getElementById("businessForm").addEventListener("submit",async e=>{e.preventDefault();const msg=document.getElementById("businessMessage");msg.textContent="Saving…";if(!currentUser){msg.textContent="Please sign in again.";return}const payload={p_name:document.getElementById("newBusinessName").value.trim(),p_slug:document.getElementById("newBusinessSlug").value.trim().toLowerCase(),p_stamps_required:Number(document.getElementById("stampsRequired").value),p_reward_title:document.getElementById("rewardTitle").value.trim()};const {data,error}=await db.rpc("create_or_update_business_workspace",payload);if(error){msg.textContent=error.message;return}msg.textContent="Workspace saved successfully.";currentBusiness={id:data.business_id};await loadMetrics(data.business_id)});
document.getElementById("createBusiness").addEventListener("click",()=>document.getElementById("newBusinessName").focus());document.getElementById("editProgram").addEventListener("click",()=>document.getElementById("stampsRequired").focus());document.getElementById("logout").addEventListener("click",async()=>{await db.auth.signOut();location.href="index.html"});initDashboard();


// Card Design Studio: live preview + tenant-scoped persistence.
(function(){
 const ids=['designStyle','designPrimary','designAccent','designMonogram','designStamp','designCorners'];
 const $=id=>document.getElementById(id);const card=$('studioCard');if(!card)return;
 const symbol={star:'✦',circle:'●',diamond:'◆',heart:'♥',leaf:'❧'};
 function current(){return {style:$('designStyle').value,primary:$('designPrimary').value,accent:$('designAccent').value,monogram:$('designMonogram').value.trim().slice(0,2)||'M',stamp:$('designStamp').value,corners:$('designCorners').value}}
 function paint(d=current()){
  $('designStyle').value=d.style||'midnight';$('designPrimary').value=d.primary||'#174b40';$('designAccent').value=d.accent||'#d9ef9b';$('designMonogram').value=d.monogram||'M';$('designStamp').value=d.stamp||'star';$('designCorners').value=d.corners||'soft';
  card.style.setProperty('--card-primary',d.primary||'#174b40');card.style.setProperty('--card-accent',d.accent||'#d9ef9b');card.dataset.style=d.style||'midnight';card.dataset.corners=d.corners||'soft';$('studioMonogram').textContent=d.monogram||'M';
  $('studioStamps').innerHTML=Array.from({length:8},(_,i)=>`<i>${i<3?(symbol[d.stamp]||'✦'):'○'}</i>`).join('');
 }
 ids.forEach(id=>$(id)?.addEventListener('input',()=>paint()));
 $('newBusinessName')?.addEventListener('input',e=>$('studioBusinessName').textContent=e.target.value||'Your business');
 $('resetCardDesign')?.addEventListener('click',()=>paint({style:'midnight',primary:'#174b40',accent:'#d9ef9b',monogram:'M',stamp:'star',corners:'soft'}));
 $('saveCardDesign')?.addEventListener('click',async()=>{
  const msg=$('designMessage');const d=current();msg.textContent='Saving design…';
  if(!db||!currentBusiness?.id){msg.textContent='Create or load your business workspace first.';return}
  const {error}=await db.from('businesses').update({card_design:d}).eq('id',currentBusiness.id);
  if(error){msg.textContent='Could not save: '+error.message;return}
  msg.textContent='Design saved. Your public card will use this style.';
 });
 const loadDesign=()=>{if(currentBusiness?.card_design)paint(currentBusiness.card_design);else paint()};
 const oldInit=initDashboard;window.applyStudioDesign=paint;window.initDashboard=async function(){await oldInit();loadDesign()};
 setTimeout(loadDesign,400);
})();
