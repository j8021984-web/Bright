# 美業預約管家 V1.1 — GitHub Pages + Supabase

## 包含功能
- 顧客公開預約：美甲、美睫、紋繡、可選時段、申請待審核。
- 店家登入：審核/拒絕、日/週/月行事曆、手動預約、取消、服務、員工、顧客列表。
- Supabase 雲端資料庫：不同手機共享預約，已核准時段不重疊。
- LINE 官方帳號：可將顧客網址加入圖文選單。**尚無 LINE Login、LINE 推播、自動通知**。

## 1. 建立 Supabase
1. 到 https://supabase.com 建立專案，記住 Project URL 和 **publishable / anon** 公開金鑰。
2. 在 SQL Editor 貼上 `schema.sql` 並執行。此腳本針對全新專案；不要在有既有同名表的專案直接執行。
3. Authentication → Users → Add user，建立你的店家 Email / 密碼（請選擇已確認 Email 的建立方式）。
4. 複製該使用者 UUID，在 SQL Editor **另外**執行：
   `insert into public.admin_users(user_id) values ('這裡填入你的UUID');`
5. 在 Authentication → Settings 中，若不希望其他人註冊，關閉公開註冊。管理員必須手動授權，僅註冊不會得到資料存取權。

## 2. 設定網站
編輯 `config.js`：
```
window.BEAUTY_CONFIG = {
  supabaseUrl: 'https://xxxx.supabase.co',
  supabaseAnonKey: '你的 publishable 或 anon key',
  studioName: '你的工作室名稱',
  lineOfficialUrl: 'https://lin.ee/你的官方帳號短網址'
};
```
**不要**放 service_role / secret key、資料庫密碼、LINE Channel Secret。GitHub Pages 上的所有檔案都是公開的。

## 3. GitHub Pages 部署
將 `index.html`, `styles.css`, `app.js`, `config.js` 上傳到 GitHub 儲存庫根目錄（不要只上傳 ZIP），`Settings → Pages → Deploy from a branch → main → /(root)`。等待部署。
- 顧客網址：`https://帳號.github.io/儲存庫名稱/`
- 店家登入：顧客網址加 `?admin=1`，或點右上角「店家登入」。
- LINE 官方帳號管理後台 → 圖文選單 → 建立「立即預約」按鈕 → 動作選「連結」→ 貼上顧客網址。

## 4. 安全性與注意事項
- `bookings` 不提供匿名 SELECT，顧客只能呼叫 `request_booking` RPC；已核准的忙碌時段透過 `get_busy_slots` 取得，不含顧客資料。
- 管理端以 Supabase Auth + RLS 控制，只有 `admin_users` 授權帳號可管理。
- 資料庫排他約束禁止已核准預約互相重疊；若兩筆待審核同時段，僅能核准其中一筆。
- **尚未加入 CAPTCHA / 速率限制**。公開申請端可能遭到機器人濫用。正式公開營運前建議透過 Edge Function 增加驗證、限制頻率及通知流程。
- V1.1 預設時區 **Asia/Taipei**、營業時間 **09:00–20:00**、30 分鐘起始間隔、最早提前 1 小時、最多提前 90 天；這些規則寫在 `schema.sql` 的 `request_booking`，前端 `app.js` 的 `loadTimes` 亦須同步修改。
- 前端顯示時間預設用台灣時區，但店家手動輸入日期/時間也固定用 +08:00。適用台灣工作室。
- V1.1 員工列表是基本管理；預約採整間工作室共用時段，尚未有個別員工行事曆、休假排班、定金付款、通知、顧客自行取消。
- 服務刪除若已有預約參照會被資料庫拒絕；可將服務改為下架。
- 顧客提交後會拿到申請編號，但目前無顧客自行查詢進度或通知，店家須自行透過 LINE/電話告知核准結果。
- 如要正式處理個資，請補充隱私權政策、保存期限、刪除流程、個資告知與備份策略。

## 5. 測試
1. 先用顧客頁送出一筆預約申請。
2. 用店家帳號登入，確認「待審核」看到申請。
3. 點「核准」，確認行事曆出現預約。
4. 回顧客頁選相同日期/服務，確認重疊時段消失。
5. 再用不同裝置開啟同一網址，確認資料同步。

## 技術說明
靜態前端直接使用 supabase-js UMD CDN；雲端同步依賴 Supabase，非離線應用。此專案適合試營運/功能驗證，正式大量使用前建議完成安全審查與端對端測試。
