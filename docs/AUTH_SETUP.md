# Cấu hình đăng nhập Google, Apple và quên mật khẩu

Code của app và backend đã xong. Để các tính năng chạy được, cần cấu hình thêm ở Google Cloud, Apple Developer và Supabase theo các bước dưới đây.

| Tính năng | App gọi | Backend gọi Supabase |
|---|---|---|
| Google | `POST /v1/auth/google {idToken, nonce}` | `token?grant_type=id_token`, provider `google` |
| Apple | `POST /v1/auth/apple {idToken, nonce}` | `token?grant_type=id_token`, provider `apple` |
| Quên mật khẩu (bước 1) | `POST /v1/auth/recover {email}` | `POST /recover` (gửi email có mã) |
| Quên mật khẩu (bước 2) | `POST /v1/auth/recover/verify {email, code, password}` | `POST /verify` (type `recovery`), rồi `PUT /user` |
| Đổi mật khẩu | `PUT /v1/me/password {currentPassword, newPassword}` | kiểm tra mật khẩu cũ, rồi `PUT /user` |

Bundle ID của app: `com.visiongroup.VocabFlow`.

---

## 1. Google

App không dùng Google Sign-In SDK. Nó mở trang đăng nhập Google bằng `ASWebAuthenticationSession` (OAuth code + PKCE), rồi đổi code lấy ID token (xem `Features/Auth/SocialSignIn.swift`). Vì vậy không cần thêm package SPM và không cần khai báo URL scheme trong Info.plist.

### 1.1 Google Cloud Console

1. Vào [console.cloud.google.com](https://console.cloud.google.com) và chọn (hoặc tạo) project.
2. **APIs & Services → OAuth consent screen** (giao diện mới gọi là **Google Auth Platform → Branding / Audience**):
   - User type: **External**.
   - Điền tên app (Syll), email hỗ trợ, logo nếu có, và domain của trang privacy policy.
   - Scopes: `openid`, `email`, `profile` (không cần scope nhạy cảm nên không phải qua review).
   - Khi còn ở trạng thái **Testing**, chỉ các tài khoản trong danh sách **Test users** đăng nhập được. Trước khi phát hành, bấm **Publish app**.
3. **Credentials → Create credentials → OAuth client ID**:
   - Application type: **iOS**.
   - Bundle ID: `com.visiongroup.VocabFlow`.
   - Tạo xong, copy **Client ID** (dạng `1234-abc.apps.googleusercontent.com`).

### 1.2 App

Mở `VocabFlow-Info.plist`, điền Client ID vào key `GoogleClientID`:

```xml
<key>GoogleClientID</key>
<string>1234-abc.apps.googleusercontent.com</string>
```

Nếu để trống, bấm nút Google sẽ hiện lỗi "Chưa thiết lập đăng nhập bằng Google."

### 1.3 Supabase

**Authentication → Sign In / Providers → Google**:
- Bật **Enable Sign in with Google**.
- **Client IDs**: điền iOS Client ID ở trên. Nếu sau này có thêm client (web, Android), liệt kê tất cả, ngăn cách bằng dấu phẩy.
- **Client Secret**: chỉ cần cho luồng OAuth trên web. Luồng ID token của app không dùng, nhưng nếu form bắt buộc, tạo thêm một OAuth client loại **Web application** và điền secret của nó.
- **Skip nonce checks**: để **tắt**. App có gửi nonce.

---

## 2. Apple

App dùng `SignInWithAppleButton` của AuthenticationServices. File `VocabFlow.entitlements` (có `com.apple.developer.applesignin`) đã được gắn vào target qua `CODE_SIGN_ENTITLEMENTS`.

### 2.1 Apple Developer

1. Vào [developer.apple.com](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles → Identifiers**.
2. Mở App ID `com.visiongroup.VocabFlow`, tick **Sign In with Apple** (chọn "Enable as a primary App ID"), rồi Save.
   - Với signing **Automatic**, Xcode thường tự bật khi thấy entitlement. Nếu Xcode báo lỗi provisioning profile, bật bằng tay như trên rồi cho Xcode tải lại profile.
3. Không cần tạo Services ID hay key `.p8` cho luồng native. Chỉ cần nếu sau này có đăng nhập Apple trên web.

### 2.2 Supabase

**Authentication → Sign In / Providers → Apple**:
- Bật **Enable Sign in with Apple**.
- **Client IDs**: `com.visiongroup.VocabFlow`.
- **Secret Key (for OAuth)**: để trống được, chỉ dùng cho luồng web.

### 2.3 Lưu ý

- Apple chỉ trả email ở **lần đăng nhập đầu tiên**. Người dùng có thể chọn **Hide My Email**, khi đó email có dạng `...@privaterelay.appleid.com`.
- Muốn gửi được email (ví dụ email đặt lại mật khẩu) tới địa chỉ relay này, vào **Certificates, Identifiers & Profiles → Services → Sign in with Apple for Email Communication** và đăng ký domain/địa chỉ gửi email (địa chỉ SMTP ở mục 3.3). Nếu không, Apple sẽ chặn email.
- Theo App Store Review Guideline 4.8, app có đăng nhập Google thì phải có Sign in with Apple. Nút Apple phải nổi bật ít nhất bằng các nút khác, nên app đặt nó lên trên nút Google với cùng kích thước.

---

## 3. Quên mật khẩu và đổi mật khẩu

Luồng chạy hoàn toàn trong app, không có link hay trang web:

1. Người dùng nhập email → backend gọi Supabase `/recover` → Supabase gửi email chứa **mã**.
2. Người dùng nhập mã + mật khẩu mới → backend gọi `/verify` (type `recovery`), đặt mật khẩu mới và trả session. Người dùng được đăng nhập luôn.

### 3.1 Email template (bắt buộc)

**Authentication → Emails → Templates → Reset Password**. Template phải có `{{ .Token }}`, vì template mặc định chỉ có link (`{{ .ConfirmationURL }}`) mà app không dùng.

Subject:

```
Mã đặt lại mật khẩu Syll / Your Syll reset code
```

Body:

```html
<h2>Đặt lại mật khẩu</h2>
<p>Mã của bạn là:</p>
<p style="font-size:28px;font-weight:700;letter-spacing:4px">{{ .Token }}</p>
<p>Nhập mã này trong app Syll để đặt mật khẩu mới. Mã hết hạn sau 1 giờ.</p>
<p>Nếu bạn không yêu cầu, hãy bỏ qua email này.</p>
<hr>
<p>Your code is <b>{{ .Token }}</b>. Enter it in the Syll app to set a new password.</p>
```

### 3.2 Độ dài và thời hạn của mã

**Authentication → Sign In / Providers → Email**:
- **Email OTP Length**: 6. Ô nhập trong app ghi "Mã 6 chữ số", còn backend chấp nhận 6–10 chữ số.
- **Email OTP Expiration**: mặc định 3600 giây. Nếu đổi giá trị này, sửa câu "hết hạn sau 1 giờ" trong template.

### 3.3 SMTP (bắt buộc trước khi phát hành)

SMTP mặc định của Supabase chỉ gửi tới email của thành viên trong project và bị giới hạn vài email mỗi giờ. Cấu hình SMTP riêng ở **Authentication → Emails → SMTP Settings** (Resend, SendGrid, Amazon SES, ...). Sau đó chỉnh **Rate Limits → emails per hour** cho phù hợp.

Supabase giới hạn 1 email `recover` mỗi 60 giây cho mỗi địa chỉ. Bấm "Gửi lại mã" sớm hơn sẽ bị lỗi 429. Backend trả lỗi này dưới dạng `503 AUTH_PROVIDER_UNAVAILABLE`, và app hiện "Đã xảy ra lỗi".

### 3.4 Quy tắc mật khẩu

Mật khẩu **tạo mới** (đăng ký, đặt lại, đổi mật khẩu) phải dài 8–72 ký tự, có ít nhất một chữ cái và một chữ số. App hiện danh sách quy tắc ngay dưới ô mật khẩu và tick từng dòng khi người dùng gõ. Backend cũng kiểm tra các quy tắc này. Đăng nhập chỉ kiểm tra độ dài, nên mật khẩu cũ vẫn dùng được.

Nên chỉnh Supabase cho khớp: **Authentication → Sign In / Providers → Email**:
- **Minimum password length**: 8.
- **Password Requirements**: "Letters and digits".

Nếu sau này đổi quy tắc, sửa cả ba chỗ: `PasswordPolicy` (app), `newPassword` trong `auth.schemas.ts` (backend) và cấu hình Supabase.

### 3.5 Đổi mật khẩu trong app

**Cài đặt → Tài khoản → Đổi mật khẩu**. Backend kiểm tra lại mật khẩu hiện tại trước khi đổi.
- Cần `SUPABASE_SERVICE_ROLE_KEY` trên server để lấy email của user. Biến này đã được dùng cho chức năng xoá tài khoản.
- Tài khoản chỉ đăng nhập bằng Google/Apple chưa có mật khẩu. Họ tạo mật khẩu bằng "Quên mật khẩu?".
- Nếu bật **Secure password change** (Authentication → Providers → Email), Supabase chỉ cho đổi mật khẩu với phiên đăng nhập gần đây. Backend luôn dùng phiên vừa tạo khi kiểm tra mật khẩu cũ, nên vẫn chạy được.

---

## 4. Backend

- Deploy bản backend mới, có các route `auth/apple`, `auth/recover`, `auth/recover/verify` và `me/password`. Không cần thêm biến môi trường.
- Mã lỗi mới: `400 RESET_CODE_INVALID` (mã sai hoặc hết hạn), `403 WRONG_PASSWORD` (sai mật khẩu hiện tại; dùng 403 vì 401 sẽ làm app tự đăng xuất).
- Tài khoản trùng email: nếu một email đã đăng ký bằng mật khẩu rồi sau đó đăng nhập bằng Google/Apple (email đã xác minh), Supabase tự gộp vào cùng một user. Xem **Authentication → Users → (user) → Identities**.

---

## 5. Checklist kiểm tra

- [ ] Đăng nhập Google trên simulator: chọn tài khoản → về app, vào thẳng Home hoặc onboarding.
- [ ] Huỷ giữa chừng (bấm Cancel trên sheet Google, hoặc vuốt tắt sheet Apple): không hiện lỗi.
- [ ] Đăng nhập Apple trên **máy thật** (simulator cần đăng nhập Apple ID trong Settings, và đôi khi không ổn định).
- [ ] Đăng nhập Apple với Hide My Email → user mới xuất hiện trong Supabase với email relay.
- [ ] Quên mật khẩu: nhận email có mã 6 số → nhập mã + mật khẩu mới → vào app luôn. Đăng xuất, đăng nhập lại bằng mật khẩu mới.
- [ ] Nhập sai mã → "Mã không đúng hoặc đã hết hạn...".
- [ ] Đổi mật khẩu: sai mật khẩu hiện tại → "Mật khẩu hiện tại không đúng." và vẫn đăng nhập. Đúng mật khẩu → "Đã đổi mật khẩu."
