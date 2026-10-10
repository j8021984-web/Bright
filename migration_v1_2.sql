-- 在原本 V1.1 schema 已成功執行後，再執行本檔。
-- 只增加欄位，不刪除或改寫舊預約。
alter table public.bookings add column if not exists line_user_id text;
create index if not exists bookings_line_user_id_idx on public.bookings(line_user_id) where line_user_id is not null;
comment on column public.bookings.line_user_id is 'Verified LINE user sub, scoped to LINE Login provider Bright Studio; never accept directly from browser';
-- 原有 bookings RLS 維持不變，匿名使用者無法讀取會員資料。
