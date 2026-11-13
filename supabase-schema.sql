-- LOYALTY PRO — Supabase MVP schema (v1)
-- Run once in Supabase > SQL Editor > New query > Run.
-- Never expose the service_role key in browser code.

create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  business_type text not null default 'Other',
  logo_url text,
  primary_color text not null default '#7655D9',
  created_at timestamptz not null default now()
);

create table if not exists public.business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','manager','staff')),
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  first_name text not null,
  email text,
  phone text,
  consent_marketing boolean not null default false,
  created_at timestamptz not null default now(),
  check (email is not null or phone is not null)
);
create unique index if not exists customers_business_email_unique on public.customers(business_id, lower(email)) where email is not null;
create unique index if not exists customers_business_phone_unique on public.customers(business_id, phone) where phone is not null;

create table if not exists public.loyalty_programs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null unique references public.businesses(id) on delete cascade,
  program_name text not null default 'Loyalty Club',
  stamps_required integer not null default 10 check (stamps_required between 2 and 100),
  reward_title text not null default 'Free reward',
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.loyalty_cards (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  public_token text not null unique default encode(gen_random_bytes(24), 'hex'),
  status text not null default 'active' check (status in ('active','blocked')),
  created_at timestamptz not null default now(),
  unique (business_id, customer_id)
);

create table if not exists public.stamp_transactions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  card_id uuid not null references public.loyalty_cards(id) on delete cascade,
  staff_user_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('stamp','redeem','reversal')),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.rewards (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  title text not null,
  stamps_cost integer not null check (stamps_cost > 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  card_id uuid not null references public.loyalty_cards(id) on delete cascade,
  reward_id uuid not null references public.rewards(id) on delete restrict,
  code text not null unique default upper(encode(gen_random_bytes(5), 'hex')),
  status text not null default 'available' check (status in ('available','redeemed','expired','cancelled')),
  created_at timestamptz not null default now(),
  redeemed_at timestamptz,
  redeemed_by uuid references auth.users(id) on delete set null
);

create index if not exists idx_members_user on public.business_members(user_id);
create index if not exists idx_customers_business on public.customers(business_id);
create index if not exists idx_cards_business on public.loyalty_cards(business_id);
create index if not exists idx_cards_token on public.loyalty_cards(public_token);
create index if not exists idx_stamps_card_time on public.stamp_transactions(card_id, created_at desc);
create index if not exists idx_vouchers_business_status on public.vouchers(business_id, status);

create or replace function public.is_business_member(target_business uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.business_members bm
    where bm.business_id = target_business and bm.user_id = auth.uid());
$$;

-- Secure onboarding: the logged-in user creates a business and becomes its owner.
create or replace function public.create_business_for_current_user(p_name text, p_slug text)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_business_id uuid;
begin
  if auth.uid() is null then raise exception 'You must be logged in'; end if;
  if length(trim(p_name)) < 2 then raise exception 'Business name is too short'; end if;
  if p_slug !~ '^[a-z0-9-]{3,50}$' then raise exception 'Slug must be 3-50 lowercase letters, numbers or hyphens'; end if;
  insert into public.businesses(name, slug) values (trim(p_name), p_slug) returning id into new_business_id;
  insert into public.business_members(business_id,user_id,role) values (new_business_id,auth.uid(),'owner');
  insert into public.loyalty_programs(business_id) values (new_business_id);
  return new_business_id;
end; $$;

alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.customers enable row level security;
alter table public.loyalty_programs enable row level security;
alter table public.loyalty_cards enable row level security;
alter table public.stamp_transactions enable row level security;
alter table public.rewards enable row level security;
alter table public.vouchers enable row level security;

drop policy if exists "members read own businesses" on public.businesses;
create policy "members read own businesses" on public.businesses for select to authenticated using (public.is_business_member(id));
drop policy if exists "members read own memberships" on public.business_members;
create policy "members read own memberships" on public.business_members for select to authenticated using (public.is_business_member(business_id));

drop policy if exists "members manage own customers" on public.customers;
create policy "members manage own customers" on public.customers for all to authenticated using (public.is_business_member(business_id)) with check (public.is_business_member(business_id));
drop policy if exists "members manage own programs" on public.loyalty_programs;
create policy "members manage own programs" on public.loyalty_programs for all to authenticated using (public.is_business_member(business_id)) with check (public.is_business_member(business_id));
drop policy if exists "members manage own cards" on public.loyalty_cards;
create policy "members manage own cards" on public.loyalty_cards for all to authenticated using (public.is_business_member(business_id)) with check (public.is_business_member(business_id));
drop policy if exists "members read own stamp history" on public.stamp_transactions;
create policy "members read own stamp history" on public.stamp_transactions for select to authenticated using (public.is_business_member(business_id));
drop policy if exists "members create own stamps" on public.stamp_transactions;
create policy "members create own stamps" on public.stamp_transactions for insert to authenticated with check (public.is_business_member(business_id) and (staff_user_id is null or staff_user_id = auth.uid()));
drop policy if exists "members manage own rewards" on public.rewards;
create policy "members manage own rewards" on public.rewards for all to authenticated using (public.is_business_member(business_id)) with check (public.is_business_member(business_id));
drop policy if exists "members read own vouchers" on public.vouchers;
create policy "members read own vouchers" on public.vouchers for select to authenticated using (public.is_business_member(business_id));

grant execute on function public.create_business_for_current_user(text,text) to authenticated;

-- Security note:
-- This starter intentionally does NOT expose public customer/card reads or allow
-- public stamp creation. Next backend step is Edge Functions/RPCs for customer
-- enrolment, public card display, stamp validation and one-time voucher redemption.
-- Keep customer contact details private and collect marketing consent explicitly.
