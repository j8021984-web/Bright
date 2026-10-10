Bright 美業工作室 V1.2 — LINE LIFF 身分綁定

已完成：
- LIFF SDK 初始化與顯示 LINE 暱稱（不取代姓名／電話欄位）
- 在 LIFF 登入狀態，預約由 Supabase Edge Function 代送
- Edge Function 呼叫 LINE 官方 verify API 驗證 ID token，取得 LINE user ID
- 資料庫 bookings 新增 line_user_id，保留原有預約與管理流程
- 原本一般瀏覽器預約仍維持 V1.1 公開申請流程（不綁 LINE）

注意：
- 目前尚未完成 LINE 官方帳號自動推播；原 Pencilnow Webhook 不需更動。
- LINE Login Channel 若為 Developing，非測試者可能無法登入，正式營運前需 Publish。
- 原本 request_booking RPC 仍公開，故 V1.2 不強制所有預約使用 LINE。
- 身分綁定是 LINE Login Provider 的 ID，不等於 Pencilnow Messaging API Provider 的 ID。
- 尚未實際連線測試你的 Supabase Edge Function，需照以下步驟部署測試。

部署順序：
1. 先備份 GitHub V1.1 和 Supabase 資料庫。
2. Supabase SQL Editor 執行 migration_v1_2.sql，應成功且不會刪除既有預約。
3. 部署 supabase/functions/line-booking/index.ts 到 Supabase Edge Functions，名稱 line-booking。
   重要：部署時關閉 Verify JWT（等效 CLI --no-verify-jwt），因顧客是 LINE 身分而不是 Supabase Auth JWT。
   Edge Function 環境需有 SUPABASE_URL、SUPABASE_SERVICE_ROLE_KEY（由 Supabase 提供），
   另設 LINE_LOGIN_CHANNEL_ID=2011960746。
   千萬不要將 SUPABASE_SERVICE_ROLE_KEY 放入 GitHub、config.js 或任何前端檔案。
4. 將 index.html、app.js、config.js 上傳覆蓋 GitHub Bright repo 同名檔案。
   styles.css 保持原本 V1.1，不需變動。
5. 使用 LINE 開啟 https://liff.line.me/2011960746-gRAK3HjO 測試。
   頁面應顯示「已透過 LINE 登入：...」且仍要求填寫姓名、電話。
6. 送出測試預約後，確認 Supabase bookings 新增 pending 且 line_user_id 非空。
   再以店家帳號核准，確認行事曆顯示，並測試同時段排除。

回復舊版：GitHub 回復原本 V1.1 index.html/app.js/config.js 即可；新增資料庫欄位可留著。

安全與上線前注意：
- 之前截圖曾顯示 Messaging API Channel Secret，應聯繫 Pencilnow 協調輪替，不要直接改到造成舊系統中斷。
- 正式上線前應加上 Edge Function rate limiting、防濫用、同意個資處理說明及保留期限。
- 請勿把 LINE ID token、access token 或 service_role key 傳給他人。
