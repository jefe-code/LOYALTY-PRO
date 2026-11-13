-- LOYALTY PRO card design settings (run once in Supabase SQL Editor)
alter table public.businesses add column if not exists card_design jsonb not null default '{"style":"midnight","primary":"#174b40","accent":"#d9ef9b","monogram":"M","stamp":"star","corners":"soft"}'::jsonb;

create or replace function public.get_public_business_card_design(p_business_slug text)
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select coalesce(b.card_design, '{}'::jsonb)
  from public.businesses b
  where b.slug = lower(trim(p_business_slug))
  limit 1;
$$;

revoke all on function public.get_public_business_card_design(text) from public;
grant execute on function public.get_public_business_card_design(text) to anon, authenticated;
