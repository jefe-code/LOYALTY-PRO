-- LOYALTY PRO — secure MVP functions for the existing starter schema
-- Run this AFTER loyalty_pro_supabase_starter.sql in Supabase SQL Editor.
-- These functions keep public customer access narrow and keep stamp validation staff-only.

create or replace function public.create_or_update_business_workspace(
  p_name text, p_slug text, p_stamps_required integer default 8, p_reward_title text default 'A free reward'
) returns jsonb
language plpgsql security definer set search_path=public
as $$
declare v_uid uuid := auth.uid(); v_business_id uuid;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if length(trim(p_name)) < 2 then raise exception 'Business name is required'; end if;
  if p_slug !~ '^[a-z0-9-]{3,48}$' then raise exception 'Use a 3–48 character lowercase slug'; end if;
  if p_stamps_required < 2 or p_stamps_required > 100 then raise exception 'Stamps must be between 2 and 100'; end if;

  select bm.business_id into v_business_id
  from public.business_members bm where bm.user_id=v_uid and bm.role in ('owner','manager')
  order by bm.created_at limit 1;

  if v_business_id is null then
    insert into public.businesses(name,slug) values(trim(p_name),p_slug) returning id into v_business_id;
    insert into public.business_members(business_id,user_id,role) values(v_business_id,v_uid,'owner');
    insert into public.loyalty_programs(business_id,program_name,stamps_required,reward_title)
    values(v_business_id,trim(p_name)||' Rewards',p_stamps_required,trim(p_reward_title));
    insert into public.rewards(business_id,title,stamps_cost) values(v_business_id,trim(p_reward_title),p_stamps_required);
  else
    update public.businesses set name=trim(p_name),slug=p_slug where id=v_business_id;
    update public.loyalty_programs set stamps_required=p_stamps_required,reward_title=trim(p_reward_title),updated_at=now()
      where business_id=v_business_id;
    if not found then
      insert into public.loyalty_programs(business_id,program_name,stamps_required,reward_title)
      values(v_business_id,trim(p_name)||' Rewards',p_stamps_required,trim(p_reward_title));
    end if;
    update public.rewards set title=trim(p_reward_title),stamps_cost=p_stamps_required,active=true
      where business_id=v_business_id and active=true;
    if not found then insert into public.rewards(business_id,title,stamps_cost) values(v_business_id,trim(p_reward_title),p_stamps_required); end if;
  end if;
  return jsonb_build_object('business_id',v_business_id);
end; $$;

create or replace function public.create_public_loyalty_card(
  p_business_slug text, p_first_name text, p_email text default null, p_phone text default null, p_consent_marketing boolean default false
) returns jsonb
language plpgsql security definer set search_path=public
as $$
declare v_business public.businesses%rowtype; v_customer_id uuid; v_token text; v_program public.loyalty_programs%rowtype;
begin
  if length(trim(coalesce(p_first_name,''))) < 1 then raise exception 'First name is required'; end if;
  if nullif(trim(coalesce(p_email,'')),'') is null and nullif(trim(coalesce(p_phone,'')),'') is null then raise exception 'Email or phone is required'; end if;
  select * into v_business from public.businesses where slug=lower(trim(p_business_slug));
  if v_business.id is null then raise exception 'Business not found'; end if;
  select * into v_program from public.loyalty_programs where business_id=v_business.id and active=true;
  if v_program.id is null then raise exception 'Loyalty programme is not active'; end if;

  if nullif(trim(coalesce(p_email,'')),'') is not null then
    select id into v_customer_id from public.customers where business_id=v_business.id and lower(email)=lower(trim(p_email));
  elsif nullif(trim(coalesce(p_phone,'')),'') is not null then
    select id into v_customer_id from public.customers where business_id=v_business.id and phone=trim(p_phone);
  end if;

  if v_customer_id is null then
    insert into public.customers(business_id,first_name,email,phone,consent_marketing)
    values(v_business.id,trim(p_first_name),nullif(trim(p_email),''),nullif(trim(p_phone),''),coalesce(p_consent_marketing,false))
    returning id into v_customer_id;
  else
    update public.customers set first_name=trim(p_first_name),consent_marketing=coalesce(p_consent_marketing,false)
    where id=v_customer_id;
  end if;

  insert into public.loyalty_cards(business_id,customer_id) values(v_business.id,v_customer_id)
  on conflict(business_id,customer_id) do update set status='active'
  returning public_token into v_token;

  return jsonb_build_object('public_token',v_token);
end; $$;

create or replace function public.get_public_loyalty_card(p_public_token text)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare v_card public.loyalty_cards%rowtype; v_business public.businesses%rowtype; v_customer public.customers%rowtype;
v_program public.loyalty_programs%rowtype; v_count integer;
begin
  select * into v_card from public.loyalty_cards where public_token=p_public_token and status='active';
  if v_card.id is null then raise exception 'Card not found'; end if;
  select * into v_business from public.businesses where id=v_card.business_id;
  select * into v_customer from public.customers where id=v_card.customer_id;
  select * into v_program from public.loyalty_programs where business_id=v_card.business_id;
  select count(*) into v_count from public.stamp_transactions where card_id=v_card.id and action='stamp';
  return jsonb_build_object('business_name',v_business.name,'customer_first_name',v_customer.first_name,
    'stamps_required',v_program.stamps_required,'stamps_count',v_count,'reward_title',v_program.reward_title);
end; $$;

create or replace function public.add_loyalty_stamp(p_public_token text, p_note text default null)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare v_card public.loyalty_cards%rowtype; v_uid uuid:=auth.uid(); v_count integer; v_required integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into v_card from public.loyalty_cards where public_token=p_public_token and status='active';
  if v_card.id is null then raise exception 'Active card not found'; end if;
  if not public.is_business_member(v_card.business_id) then raise exception 'Not authorized for this business'; end if;
  select stamps_required into v_required from public.loyalty_programs where business_id=v_card.business_id;
  insert into public.stamp_transactions(business_id,card_id,staff_user_id,action,note)
  values(v_card.business_id,v_card.id,v_uid,'stamp',left(p_note,200));
  select count(*) into v_count from public.stamp_transactions where card_id=v_card.id and action='stamp';
  return jsonb_build_object('stamps_count',v_count,'stamps_required',v_required,'reward_ready',v_count>=v_required);
end; $$;

create or replace function public.redeem_loyalty_voucher(p_voucher_code text)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare v_voucher public.vouchers%rowtype; v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into v_voucher from public.vouchers where code=upper(trim(p_voucher_code)) for update;
  if v_voucher.id is null then raise exception 'Voucher not found'; end if;
  if not public.is_business_member(v_voucher.business_id) then raise exception 'Not authorized for this business'; end if;
  if v_voucher.status <> 'available' then raise exception 'Voucher has already been used or is inactive'; end if;
  update public.vouchers set status='redeemed',redeemed_at=now(),redeemed_by=v_uid where id=v_voucher.id;
  return jsonb_build_object('status','redeemed');
end; $$;

revoke all on function public.create_or_update_business_workspace(text,text,integer,text) from public;
revoke all on function public.add_loyalty_stamp(text,text) from public;
revoke all on function public.redeem_loyalty_voucher(text) from public;
grant execute on function public.create_or_update_business_workspace(text,text,integer,text) to authenticated;
grant execute on function public.add_loyalty_stamp(text,text) to authenticated;
grant execute on function public.redeem_loyalty_voucher(text) to authenticated;

revoke all on function public.create_public_loyalty_card(text,text,text,text,boolean) from public;
revoke all on function public.get_public_loyalty_card(text) from public;
grant execute on function public.create_public_loyalty_card(text,text,text,text,boolean) to anon,authenticated;
grant execute on function public.get_public_loyalty_card(text) to anon,authenticated;

-- Production note: the public_token is a bearer secret. Keep it private.
-- Before public launch, add rate limiting/anti-bot controls (e.g. Edge Function),
-- email/phone verification, customer recovery, and transactional voucher issuance.
