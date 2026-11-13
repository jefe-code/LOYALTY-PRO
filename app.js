// LOYALTY PRO — frontend starter
// 1) Paste your Supabase Project URL and Publishable/anon key below.
// 2) Never put the service_role key or database password in this file.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = "PASTE_YOUR_SUPABASE_PROJECT_URL_HERE";
const SUPABASE_KEY = "PASTE_YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY_HERE";
const configured = SUPABASE_URL.startsWith("https://") && !SUPABASE_KEY.includes("PASTE_");
const supabase = configured ? createClient(SUPABASE_URL, SUPABASE_KEY) : null;

const $ = (id) => document.getElementById(id);
let mode = "login";
let currentBusiness = null;
let previewMode = false;

function showMessage(id, text, type="error") {
  const el = $(id); el.textContent = text; el.className = `message ${type}`;
}
function hideMessage(id) { $(id).className = "message hidden"; }
function toast(text) { $("toast").textContent = text; $("toast").classList.remove("hidden"); setTimeout(()=> $("toast").classList.add("hidden"), 3000); }
function setMode(next) {
  mode = next;
  document.querySelectorAll(".tab").forEach(t => t.classList.toggle("active", t.dataset.tab === mode));
  $("nameLabel").classList.toggle("hidden", mode !== "signup");
  $("authSubmit").innerHTML = mode === "login" ? 'Log in <span>→</span>' : 'Create account <span>→</span>';
  $("password").autocomplete = mode === "login" ? "current-password" : "new-password";
  hideMessage("authMessage");
}
document.querySelectorAll(".tab").forEach(t => t.addEventListener("click", () => setMode(t.dataset.tab)));
$("connectionLabel").textContent = configured ? "Supabase configured" : "Preview mode";
$("setupNotice").classList.toggle("hidden", configured);
$("authForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (!configured) { showMessage("authMessage", "Add your Supabase URL and Publishable/anon key in app.js first. Preview mode is available below."); return; }
  const email = $("email").value.trim(), password = $("password").value;
  $("authSubmit").disabled = true; $("authSubmit").textContent = "Please wait…";
  try {
    let result;
    if (mode === "signup") {
      result = await supabase.auth.signUp({ email, password, options: { data: { full_name: $("fullName").value.trim() } } });
      if (result.error) throw result.error;
      if (result.data.session) await enterDashboard(result.data.user);
      else showMessage("authMessage", "Account created. Check your email to confirm your address, then log in.", "success");
    } else {
      result = await supabase.auth.signInWithPassword({ email, password });
      if (result.error) throw result.error;
      await enterDashboard(result.data.user);
    }
  } catch(err) { showMessage("authMessage", err.message || "Something went wrong."); }
  finally { $("authSubmit").disabled = false; $("authSubmit").innerHTML = mode === "login" ? 'Log in <span>→</span>' : 'Create account <span>→</span>'; }
});
async function enterDashboard(user) {
  previewMode = false;
  $("authView").classList.add("hidden"); $("dashboardView").classList.remove("hidden"); $("logoutBtn").classList.remove("hidden");
  $("connectionLabel").textContent = user.email || "Connected";
  await loadBusinesses();
}
async function loadBusinesses() {
  if (!configured) return;
  const { data, error } = await supabase.from("businesses").select("id,name,slug,created_at").order("created_at", {ascending:false});
  if (error) { toast(error.message); return; }
  if (data?.length) renderBusiness(data[0]);
}
function renderBusiness(b) {
  currentBusiness = b;
  $("businessPanel").innerHTML = `<div class="business-chip"><div class="business-logo">${escapeHtml(b.name.slice(0,1).toUpperCase())}</div><div><h3>${escapeHtml(b.name)}</h3><p>/${escapeHtml(b.slug)} · Business workspace</p></div></div>`;
}
function escapeHtml(s) { return String(s).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])); }
function openBusinessModal() { $("modal").classList.remove("hidden"); $("businessName").focus(); }
$("newBusinessBtn").addEventListener("click", openBusinessModal);
$("emptyCreateBtn").addEventListener("click", openBusinessModal);
$("closeModal").addEventListener("click", () => $("modal").classList.add("hidden"));
$("businessName").addEventListener("input", () => {
  $("businessSlug").value = $("businessName").value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"");
});
$("businessForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (previewMode) { showMessage("businessMessage","Preview only: connect Supabase to save a real business.","error"); return; }
  if (!configured) return;
  const name = $("businessName").value.trim(), slug = $("businessSlug").value.trim();
  const { data, error } = await supabase.rpc("create_business_for_current_user", { p_name:name, p_slug:slug });
  if (error) { showMessage("businessMessage",error.message); return; }
  $("modal").classList.add("hidden"); $("businessForm").reset();
  await loadBusinesses(); toast("Business workspace created.");
});
$("logoutBtn").addEventListener("click", async () => {
  if (configured && !previewMode) await supabase.auth.signOut();
  previewMode = false; currentBusiness = null;
  $("dashboardView").classList.add("hidden"); $("authView").classList.remove("hidden"); $("logoutBtn").classList.add("hidden");
  $("connectionLabel").textContent = configured ? "Supabase configured" : "Preview mode";
});
$("previewBtn").addEventListener("click", () => {
  previewMode = true; $("authView").classList.add("hidden"); $("dashboardView").classList.remove("hidden"); $("logoutBtn").classList.remove("hidden");
  $("connectionLabel").textContent = "Interactive preview";
  renderBusiness({name:"Demo Coffee House",slug:"demo-coffee-house"});
  toast("Preview mode — data is not saved.");
});
["programAction","customerAction","qrAction"].forEach((id,i)=>$(id).addEventListener("click",()=>toast(["Loyalty program setup is the next module.","Customer management is the next module.","Public QR card links are the next module."][i])));
if (configured) {
  const { data } = await supabase.auth.getSession();
  if (data.session) await enterDashboard(data.session.user);
  supabase.auth.onAuthStateChange((_event, session) => {
    if (!session && !$("authView").classList.contains("hidden")) return;
    if (!session) { $("dashboardView").classList.add("hidden"); $("authView").classList.remove("hidden"); $("logoutBtn").classList.add("hidden"); }
  });
}
