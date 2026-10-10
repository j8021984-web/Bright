-- 在 Supabase SQL Editor 執行。單工作室版本，所有時間以 timestamptz 儲存。
create extension if not exists btree_gist;
create table if not exists public.admin_users (user_id uuid primary key references auth.users(id) on delete cascade);
create table if not exists public.services (id uuid primary key default gen_random_uuid(), category text not null check(category in ('美甲','美睫','紋繡')), name text not null, duration_minutes int not null check(duration_minutes between 15 and 480), price numeric(10,2) not null default 0 check(price>=0), active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.staff (id uuid primary key default gen_random_uuid(), name text not null, active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.bookings (id uuid primary key default gen_random_uuid(), service_id uuid not null references public.services(id), customer_name text not null check(char_length(customer_name) between 1 and 60), customer_phone text not null check(char_length(customer_phone) between 5 and 30), note text not null default '' check(char_length(note)<=500), start_at timestamptz not null, end_at timestamptz not null, status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')), created_at timestamptz not null default now(), check(end_at>start_at));
-- 防止任何兩筆已核准預約重疊（資料庫層，避免多人同時審核造成競態）
do $$ begin if not exists(select 1 from pg_constraint where conname='bookings_no_approved_overlap') then alter table public.bookings add constraint bookings_no_approved_overlap exclude using gist (tstzrange(start_at,end_at,'[)') with &&) where (status='approved'); end if; end $$;
create index if not exists bookings_start_idx on public.bookings(start_at);
create or replace function public.is_studio_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.admin_users where user_id=(select auth.uid()))$$;
revoke all on function public.is_studio_admin() from public;
grant execute on function public.is_studio_admin() to authenticated;
alter table public.admin_users enable row level security;
alter table public.services enable row level security;
alter table public.staff enable row level security;
alter table public.bookings enable row level security;
revoke all on public.admin_users from anon, authenticated;
grant select on public.services to anon, authenticated;
grant select, insert, update, delete on public.services, public.staff, public.bookings to authenticated;
create policy "active services visible" on public.services for select to anon using (active);
create policy "admins read services" on public.services for select to authenticated using ((select public.is_studio_admin()));
create policy "admins insert services" on public.services for insert to authenticated with check ((select public.is_studio_admin()));
create policy "admins update services" on public.services for update to authenticated using ((select public.is_studio_admin())) with check ((select public.is_studio_admin()));
create policy "admins delete services" on public.services for delete to authenticated using ((select public.is_studio_admin()));
create policy "admins manage staff" on public.staff for all to authenticated using ((select public.is_studio_admin())) with check ((select public.is_studio_admin()));
create policy "admins manage bookings" on public.bookings for all to authenticated using ((select public.is_studio_admin())) with check ((select public.is_studio_admin()));
-- 公開 RPC 只回傳已佔用時間，不回傳客人資料。
create or replace function public.get_busy_slots(p_day date)
returns table(start_at timestamptz,end_at timestamptz) language sql security definer set search_path='' as $$
 select b.start_at,b.end_at from public.bookings b where b.status='approved' and b.start_at < ((p_day+1)::timestamp at time zone 'Asia/Taipei') and b.end_at > (p_day::timestamp at time zone 'Asia/Taipei');
$$;
-- 公開申請只允許新增待審核，服務時長由資料庫決定，防止客戶端偽造。
create or replace function public.request_booking(p_service_id uuid,p_name text,p_phone text,p_note text,p_start timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_duration int; v_end timestamptz; v_id uuid;
begin
 select duration_minutes into v_duration from public.services where id=p_service_id and active=true;
 if v_duration is null then raise exception '服務項目無效'; end if;
 if length(trim(coalesce(p_name,''))) not between 1 and 60 or length(trim(coalesce(p_phone,''))) not between 5 and 30 or length(coalesce(p_note,''))>500 then raise exception '顧客資料格式錯誤'; end if;
 if p_start < now()+interval '1 hour' or p_start>now()+interval '90 days' then raise exception '請選擇一小時後至90天內的時段'; end if;
 if extract(minute from p_start at time zone 'Asia/Taipei') not in (0,30) or extract(hour from p_start at time zone 'Asia/Taipei') not between 9 and 19 then raise exception '不在可預約時段'; end if;
 v_end:=p_start+make_interval(mins=>v_duration);
 if (v_end at time zone 'Asia/Taipei')::date <> (p_start at time zone 'Asia/Taipei')::date or (v_end at time zone 'Asia/Taipei')::time > time '20:00' then raise exception '服務超出營業時間'; end if;
 if exists(select 1 from public.bookings where status='approved' and start_at<v_end and end_at>p_start) then raise exception '此時段已被預約'; end if;
 insert into public.bookings(service_id,customer_name,customer_phone,note,start_at,end_at,status) values(p_service_id,trim(p_name),trim(p_phone),coalesce(p_note,''),p_start,v_end,'pending') returning id into v_id;
 return v_id;
end $$;
revoke all on function public.get_busy_slots(date),public.request_booking(uuid,text,text,text,timestamptz) from public;
grant execute on function public.get_busy_slots(date),public.request_booking(uuid,text,text,text,timestamptz) to anon,authenticated;
insert into public.services(category,name,duration_minutes,price) select v.category,v.name,v.duration,v.price from (values ('美甲','單色凝膠',90,1200),('美甲','造型凝膠',120,1800),('美睫','自然款嫁接',90,1500),('美睫','濃密款嫁接',120,1900),('紋繡','霧眉諮詢',60,500)) as v(category,name,duration,price) where not exists(select 1 from public.services);
insert into public.staff(name) select '工作室主理人' where not exists(select 1 from public.staff);
-- 管理員建立步驟：先在 Authentication > Users 建立店家帳號，將 UUID 替換如下並另外執行：
-- insert into public.admin_users(user_id) values ('你的-auth-users-UUID');
