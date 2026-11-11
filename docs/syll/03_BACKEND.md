# Syll: Backend

Backend của Syll nằm ở repo anh em `vocab-backend` (tên cũ *Vocab Flow Backend*). Tài liệu này mô tả kiến trúc, dữ liệu, luồng nghiệp vụ và vận hành. Contract từng endpoint và từng template dành cho client: `vocab-backend/docs/FRONTEND_FLOW.md`. Quyết định còn mở và giá trị đang dùng: `vocab-backend/docs/DECISIONS.md`.

**Trạng thái:** triển khai Spec v0.4 (`vocab-backend/spec/`), là bản Engineering Review Draft **chưa được duyệt**. Mọi con số SRS, ngưỡng và hạn mức là giá trị thử nghiệm, tập trung ở `src/config/policy.ts` (`policy-trial-v0.4`).

---

## 1. Stack

| Thành phần | Lựa chọn |
|---|---|
| Runtime | Node 22.18+, pnpm |
| Framework | NestJS 12 trên Fastify 5 |
| ORM | Drizzle ORM 0.45.4 (ghim bản stable, không dùng 1.0 beta) |
| Database | Supabase Postgres (session TimeZone bắt buộc UTC, app từ chối khởi động nếu khác) |
| Auth | Supabase Auth, backend làm proxy; JWT kiểm tra bằng `SupabaseJwtGuard` (global guard) |
| Validation | zod |
| AI tạo nội dung | Anthropic (`AnthropicLexicalProvider`, model mặc định `claude-opus-5-5`, đổi bằng `LEXICAL_AI_MODEL`) |
| Text-to-speech | ElevenLabs (`ElevenLabsTtsProvider`), lưu file vào Supabase Storage (`SupabaseAudioStorage`) |
| Chấm phát âm | Azure Speech REST (`AzureRestSpeechProvider`) |
| Test | vitest, chạy trên Postgres 17 nhúng (`embedded-postgres`), không cần Docker |
| API docs | Swagger tại `/docs` |

Mỗi provider là một dòng `useClass` trong `src/app.module.ts`, nên thay nhà cung cấp không đụng tới service. Thiếu key của provider nào (`AZURE_SPEECH_KEY`, `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`) thì tính năng đó tắt và trả `503 ..._PROVIDER_UNAVAILABLE`.

## 2. Module (`src/modules/`)

| Module | Trách nhiệm |
|---|---|
| `auth` | Proxy Supabase Auth: signup, login, Google, Apple, quên mật khẩu bằng mã, refresh |
| `identity` | `GET/DELETE /me`, đổi mật khẩu, level, settings, scope; tự tạo user ở request đầu tiên có token hợp lệ |
| `catalog` | Danh sách collection/topic đã publish, localize theo `uiLocale` |
| `placement` | Bài test xếp level: sinh đề từ nội dung curated, chấm ở server |
| `session-planner` | `POST /sessions/plan`: chọn Meaning, sinh task, đóng băng plan vào session |
| `practice-resolver` | Dựng payload task (prompt, options, tiles, evaluation) theo locale; chọn đáp án nhiễu |
| `practice-evaluator` | Thuần logic: phát lại events, chuẩn hóa câu trả lời, chấm từng task |
| `session-commit` | `POST /sessions/{id}/commit`, `commit-status`: kiểm tra, chấm lại, ghi kết quả trong một transaction, idempotent |
| `speech` | `POST /sessions/{id}/recording-assess`: gửi audio cho Azure, phát receipt |
| `memory-srs` | Thuần logic: reducer tín hiệu nhớ và lịch ôn |
| `skill-verification` | Thuần logic: suy ra evidence, trạng thái và issue của 4 kỹ năng |
| `checkpoint` | Mở và liệt kê checkpoint challenge (Tổng ôn) |
| `journey` | `GET /me/journey`: các chặng và node |
| `progress` | learn-home, thư viện từ, thống kê, chi tiết từ kèm kỹ năng |
| `custom-words` | Tra từ, AI tạo nháp, thêm vào lộ trình riêng, bản sửa riêng; worker dịch và bù audio |
| `admin` | CRUD nội dung, publish/recall, duyệt nội dung AI, phân quyền |
| `maintenance` | Cron mỗi giờ: hết hạn session, dọn dữ liệu |
| `health` | `GET /health` |

Dùng chung: `src/common/` (auth guard, HTTP filter, hằng số domain, mã lỗi, tên event), `src/config/` (env, policy), `src/db/` (schema, migrate), `src/seed/`.

Logic thuần (evaluator, reducer, SRS, skill, interleaver) **không phụ thuộc Nest hay Drizzle** để test trực tiếp.

## 3. Mô hình dữ liệu

### 3.1. Nội dung

```text
collections ─┬─ collection_localizations
             └─ topics ─┬─ topic_localizations
                        └─ topic_meanings ──► meanings   (membership curated, có thứ tự)

words (language + lower(btrim(lemma)) + homograph_key là unique)
  └─ word_types (loại từ)
       ├─ pronunciations (IPA, audio_asset_key = URL HTTPS phát được)
       └─ meanings (popularity 0–100, owner_user_id cho nghĩa riêng)
            ├─ meaning_localizations, meaning_examples ─ example_localizations
            ├─ meaning_publications (snapshot bất biến) ─ active_meaning_publications
            └─ practice_items (curated) ─ practice_item_localizations, practice_item_targets
lexical_drafts      bản nháp do AI tạo (nguồn duy nhất khi ghi vào kho chung)
```

- **Meaning là đơn vị học.** Mọi tiến trình, lịch ôn và kỹ năng đều theo Meaning, nên một từ thuộc nhiều Topic/Collection vẫn chỉ có một lịch ôn.
- **Publication bất biến:** khi publish, nội dung của Meaning được chụp thành `meaning_publications` (trigger chặn sửa). Sửa sau publish chỉ có hiệu lực ở lần publish kế tiếp.
- **`popularity`** quyết định nghĩa nào của một từ người học gặp trước (mỗi session tối đa một nghĩa mới cho mỗi từ). Không nằm trong snapshot, sửa là có hiệu lực ngay.

### 3.2. Người học

| Bảng | Nội dung |
|---|---|
| `app_user`, `deleted_identities` | User (id Supabase), danh sách identity đã xóa (chặn tạo lại bằng token cũ, giữ 7 ngày) |
| `user_settings` | `explanationLocale`, `uiLocale`, `timeZone`, `dailyNewWordGoal` (1–30), `weeklySessionGoal` (1–7) |
| `user_learning_scope`, `user_active_topics` | Collection đang học và các topic đã chọn |
| `user_meaning_progress` | Lịch SRS từng Meaning: `learnedAt`, `nextReviewAt`, interval, streak, lapse |
| `memory_observations` | Tín hiệu nhớ của từng lần gặp |
| `skill_evidence` | Bằng chứng kỹ năng, mỗi dòng có danh sách `reasons` |
| `learning_sessions` | Plan (bất biến), `raw_events`, `result`, trạng thái `issued/committed/expired` |
| `speech_assessment_receipts` | Kết quả chấm phát âm, dùng một lần, hạn 72 h; audio không được lưu |
| `checkpoint_challenges`, `checkpoint_challenge_meanings` | Tổng ôn và các Meaning của nó |
| `user_meaning_overrides` | Bản sửa riêng của người học trên nội dung custom word |
| `custom_word_usage` | Đếm lượt gọi AI mỗi ngày |

### 3.3. Quy ước dễ làm hỏng

- Mọi `id` là **UUID v7 sinh trong app** (`$defaultFn(newId)`), cột DB không có default. Insert bằng SQL tay phải tự truyền `id`.
- CHECK, partial index, trigger, foreign key **không có trong `src/db/schema.ts`**; chúng nằm ở migration SQL viết tay trong `drizzle/`. `test/schema.test.ts` so catalog DB với `spec/*.sql`.
- RLS bật trên mọi bảng, không có policy: role anon/authenticated không đọc được qua PostgREST. App kết nối bằng role `postgres`.
- `learning_sessions.plan` và `meaning_publications` bất biến (trigger); retention chỉ được đặt `plan` về NULL.
- `db.execute(sql...)` trả timestamptz dạng text, phải đổi bằng `toDate`. JS `Date` chỉ giữ millisecond.
- Drizzle bỏ `undefined` trong `and(...)` và coi `where(undefined)` là không lọc: **không bao giờ** truyền id tùy chọn vào `update`/`delete`.
- `insert().values([])` throw: chặn mảng rỗng.

### 3.4. Quy tắc truy vấn

- **Không round trip thừa, không N+1.** Không query trong vòng lặp (kể cả `Promise.all(items.map(...))`). Đọc một lần bằng `inArray`, index bằng `Map`. Ghi bằng một `insert().values([...])` nhiều dòng hoặc một `INSERT ... ON CONFLICT` / `jsonb_to_recordset`.
- Chỉ select cột cần; không đọc `plan`, `raw_events`, `result`, `snapshot` khi không dùng.
- Màn tổng hợp là một câu SQL. Số query của một request không tăng theo dữ liệu: ESLint chặn các dạng thường gặp, `test/api.test.ts` so số query ở 1 và 20 Meaning.
- Hằng số domain ở `src/common/constants/` (key `UPPER_SNAKE_CASE`, giá trị `lower_snake_case`), không hardcode trong `src`.

## 4. API

Base `/v1`, JSON camelCase, thời gian ISO 8601 UTC. Mọi route cần `Authorization: Bearer <accessToken>` trừ `/v1/auth/*` và `/health`. Client **không bao giờ gửi `userId`**.

| Nhóm | Endpoint |
|---|---|
| Auth | `POST /auth/signup`, `/auth/login`, `/auth/google`, `/auth/apple`, `/auth/recover`, `/auth/recover/verify`, `/auth/refresh` |
| Hồ sơ | `GET /me`, `DELETE /me`, `PUT /me/password`, `PUT /me/levels`, `PUT /me/settings`, `PUT /me/scope` |
| Placement | `GET /me/placement-test`, `POST /me/placement-test` |
| Catalog | `GET /catalog/collections` |
| Home & tiến trình | `GET /me/learn-home`, `GET /me/checkpoint-challenges`, `GET /me/journey`, `GET /me/words`, `GET /me/words/stats`, `GET /words/{wordId}` |
| Session | `POST /sessions/plan`, `POST /sessions/{id}/recording-assess`, `POST /sessions/{id}/commit`, `GET /sessions/{id}/commit-status` |
| Custom word | `POST /custom-words/lookup`, `POST /custom-words`, `GET /custom-words`, `PUT` / `DELETE /custom-words/{meaningId}/override`, `DELETE /custom-words/{meaningId}` |
| Admin (`/admin`, không có `/v1`) | Xem §10 |

### Lỗi

Mọi lỗi có dạng `{code, message, retryable, requestId}`; log mang `requestId`.

| HTTP | code |
|---|---|
| 400 | `VALIDATION_FAILED` |
| 401 | `UNAUTHORIZED` |
| 403 | `FORBIDDEN`, `SESSION_NOT_OWNED`, `WRONG_PASSWORD` |
| 404 | `NOT_FOUND` |
| 409 | `EMAIL_ALREADY_REGISTERED`, `SESSION_PAYLOAD_CONFLICT`, `SESSION_STALE`, `WORD_ALREADY_EXISTS`, `CONTENT_LOCKED` |
| 410 | `SESSION_EXPIRED` |
| 413 | `PAYLOAD_TOO_LARGE` |
| 422 | `INVALID_SUBMISSION`, `TASK_DATA_INVALID`, `CUSTOM_WORD_INVALID`, `CUSTOM_WORD_UNAVAILABLE` |
| 429 | `CUSTOM_WORD_LIMIT_REACHED` |
| 503 | `AUTH_PROVIDER_UNAVAILABLE`, `SPEECH_PROVIDER_UNAVAILABLE`, `LEXICAL_PROVIDER_UNAVAILABLE` (retryable) |
| 500 | `INTERNAL_ERROR` (retryable) |

## 5. Auth và tài khoản

- `/auth/*` proxy Supabase Auth bằng `SUPABASE_ANON_KEY`. Email được trim và lowercase.
- Mật khẩu 8–72 ký tự; mật khẩu mới (signup, recover/verify, đổi mật khẩu) cần ít nhất một chữ cái và một chữ số.
- Google/Apple: client gửi ID token và nonce gốc; Supabase phải bật provider tương ứng.
- Quên mật khẩu: `recover` luôn trả `200`; email chứa mã (template "Reset Password" phải có `{{ .Token }}`); `recover/verify` đúng mã thì đặt mật khẩu mới và trả session.
- Refresh token dùng một lần, mỗi lần trả cặp mới.
- **Xóa tài khoản** (`DELETE /me`) là tất cả hoặc không: xóa dữ liệu học, từ tự thêm, nghĩa riêng, bản sửa riêng, user Supabase. Nội dung đã thuộc kho chung (từ, phát âm, audio, nghĩa đã duyệt) được giữ và bỏ liên kết. Token cũ sau đó nhận `401` và không tạo lại user.

## 6. Session: plan → làm bài → commit

Nguyên tắc: **client chấm ngay để phản hồi, backend chấm lại toàn bộ từ events khi commit.** Kết quả học chỉ tồn tại khi commit thành công.

### 6.1. Plan (`session-planner`)

`POST /sessions/plan` với `mode`, `capabilities {audioPlayback, microphone}`, tùy chọn `challengeId` (checkpoint) hoặc `skills` (random). Mỗi lần gọi tạo một session mới, TTL 72 h; plan được đóng băng (gồm cả `maxRetries` của từng task).

| Mode | Chọn gì |
|---|---|
| `daily` | Tối đa 10 Meaning đến hạn (cũ nhất trước), rồi tối đa `dailyNewWordGoal` Meaning mới. Từ tự thêm trước, sau đó theo scope: nghĩa phổ biến hơn trước, rồi độ hợp CEFR (từ ≥ level trước), rồi thứ tự curated. Mỗi due Meaning có 30% khả năng thêm một task chỉ để luyện kỹ năng. **Khi có Tổng ôn đang chờ, daily chỉ còn phần ôn** |
| `checkpoint_challenge` | Các Meaning đã học trong các session của chặng, chỉ dạng tự nhớ lại (typing / fly reorder) |
| `random_practice` | Tối đa 10 Meaning đã học. Có `skills` thì mỗi từ một task, các kỹ năng chia lượt đều; không có `match` |
| `weak_words_practice` | Trước hết các Meaning có skill issue trong 30 ngày, mỗi kỹ năng có issue một task trực tiếp (recall đứng đầu để không bị primed); sau đó các Meaning hay sai trong 30 ngày (tối thiểu 3 session). Tối đa 10 task |

- **Thứ tự học mới:** nhóm tối đa 3 Meaning (`introBatchSize`); các learn card của nhóm, rồi 5 vòng xen kẽ: select gloss → select reverse gloss → recall (typing hoặc fly reorder, 50/50) → recording → select gloss.
- **`capabilities`:** `audioPlayback=false` thì không có prompt audio. `microphone=false` vẫn phát hành recording; client gửi `unavailable`. Skill không luyện được trên thiết bị bị bỏ khỏi practice theo kỹ năng.
- **Plan rỗng:** `{sessionId: null, steps: []}`, không tạo session row.
- Audio thiếu URL thì ứng viên audio bị loại, dùng text. URL của task nghe "mù" không được chứa từ đích.

### 6.2. Template: generated và curated

| Template | Variant | Nguồn |
|---|---|---|
| `select` | `gloss`, `reverse_gloss` | Generated |
| `select` | `meaning_clash`, `phonetic_choice`, `stress_choice` | Curated |
| `typing` | `meaning_recall`, `transcription` | Generated (có thể curated) |
| `fly_reorder` | `spelling_recall` | Generated (có thể curated) |
| `match` | `meaning_pairs` (`word_pairs` nếu curated) | Generated; chỉ ở random/weak |
| `recording` | `scripted_pronunciation` | Generated |
| `cloze_select` | `single_blank`, `context_meaning` | Curated |
| `surgery` | `fix_spelling` | Curated |

Schema chưa có dữ liệu âm tiết hay từ dễ nhầm, nên các template curated chỉ xuất hiện khi editor đã soạn `practice_items`. Đáp án nhiễu lấy từ pool 200 Meaning đã chia sẻ (không dùng nội dung AI chưa duyệt).

### 6.3. Chấm (`practice-evaluator`)

- Phát lại events theo `seq` (tăng ngặt). Fly reorder dựng lại dãy tile từ tap/remove/move; `submit.tileIds` phải khớp dãy đó.
- Chuẩn hóa text: NFC, trim, gộp khoảng trắng, lowercase; giữ dấu. Surgery: áp các edit theo chỉ số grapheme rồi so như typing.
- Recording: receipt Azure (đạt khi `accuracyScore ≥ 80`) hoặc transcript on-device của lần đọc cuối, so khớp sau khi bỏ dấu, dấu câu, lowercase; transcript rỗng là `invalid`.
- Kết quả task: `correct`, `corrected_after_retry`, `revealed`, `incorrect`.
- Số lần thử: 1 + `maxRetries` (select / cloze / match: 1; typing / fly reorder / surgery / recording: 2). Match tính theo từng item bên trái.

### 6.4. Commit (`session-commit`)

Tất cả hoặc không. Commit gồm:

- Kiểm tra quyền sở hữu, hạn (72 h), trạng thái.
- Kiểm tra đầy đủ: mọi task có đúng một kết quả, mọi learn step có trong `learnStepsCompleted`, task first recall có ít nhất một submit, `deliveryMode` đúng loại prompt, giới hạn 200 event/task và 500 task/commit. Sai một chỗ là `422 INVALID_SUBMISSION` cho cả commit.
- Chấm lại mọi task.
- Ghi `memory_observations`, cập nhật `user_meaning_progress` (SRS), ghi `skill_evidence`.
- Đếm session học mới cho Journey; mở checkpoint challenge khi đủ `weeklySessionGoal` session.
- Lưu `raw_events`, `result`, đánh dấu committed.

- **Idempotent:** commit lại cùng body (so sau khi chuẩn hóa JSON) trả đúng response cũ; body khác → `409 SESSION_PAYLOAD_CONFLICT`. `commit-status` cho biết `issued | committed | expired` kèm response đã lưu.
- Một Meaning mới đã được học ở session khác → `409 SESSION_STALE`.
- Response: `summary {newWordGoalSlots, reviewedMeanings, practiceTasks}`; Tổng ôn thêm `checkpoint {reviewedCount, unaidedRecalledCount, needsReviewCount}`.

## 7. Trí nhớ và lịch ôn (`memory-srs`)

### 7.1. Tín hiệu nhớ

| Tín hiệu | Khi nào |
|---|---|
| `unaided_recall` | Task recall đúng ngay lần đầu, không gợi ý, không reveal, không bị primed |
| `assisted_recall` | Recall đúng lần đầu nhưng có gợi ý, hoặc đúng ở lần thử thứ 2 không gợi ý, hoặc unaided nhưng **primed** (đáp án nằm ngay ở step trước) |
| `failed_recall` | Mọi trường hợp recall khác |
| `recognition_success` | Task nhận diện (select...) đúng lần đầu, không trợ giúp |
| `failed_recognition` | Nhận diện có gợi ý, thử lại hoặc reveal |

`match` và `surgery` không tạo tín hiệu nhớ (template yếu).

### 7.2. Lịch ôn

Chỉ `daily` thực sự đẩy lịch ôn đi xa.

| Tình huống | Kết quả |
|---|---|
| Lần học đầu | Interval đầu: unaided 48 h, assisted 24 h, failed 12 h. Session một Meaning luôn primed nên interval đầu thường là 24 h |
| Daily, unaided recall | Interval × min(2,2; 1,6 + 0,15 × streak), kẹp trong [48 h, 90 ngày]; streak +1 |
| Daily, assisted recall | Interval giảm một nửa (sàn 12 h); lần ôn tới = now + min(interval, 24 h); streak về 0 |
| Daily, failed recall/recognition | Interval 12 h; streak về 0; lapse +1 |
| Daily, recognition success khi đã đến hạn | Lùi 24 h, chỉ một lần cho tới lần unaided kế tiếp |
| Checkpoint / Random / Weak | Không bao giờ kéo dài lịch, không tiêu "đến hạn". Assisted kéo lần ôn tới về tối đa 24 h. Failed còn giảm nửa interval (sàn 12 h) và reset streak, không tăng lapse |

## 8. Bốn kỹ năng (`skill-verification`)

- Mỗi task tạo evidence cho tối đa một kỹ năng (`skillOf`): Reading (select text, reverse gloss, cloze, meaning clash), Writing (typing meaning recall, fly reorder, surgery), Listening (select audio, transcription, phonetic/stress choice), Speaking (recording). Listening/Speaking chỉ có khi Meaning có phát âm.
- Mỗi dòng `skill_evidence` có `reasons`, liệt kê mọi lý do nó không "trực tiếp": `new_practice`, `hinted`, `revealed`, `retried`, `primed`, `weak_template`, `quality_unqualified`, `audio_not_played`, `invalid_recording`. Chỉ dòng `valid` với `reasons` rỗng là một lần **pass**. Evidence trong phase học mới không bao giờ tính.
- **Trạng thái:** `not_verified` → `demonstrated` (có ít nhất một pass) → `verified` (các pass sau lần fail gần nhất trải trên ≥ 2 session và cách nhau ≥ 24 h).
- **Issue:** `failed` (sai hoặc reveal, kể cả có gợi ý hay primed) thu hồi verified; `assisted` (đúng nhờ gợi ý, hoặc retried) giữ verified. Issue tắt sau một pass sạch của kỹ năng đó, cách ít nhất 12 h. `needsPractice` theo issue và lan lên Meaning, Word và `needPracticeWords`.
- Một Word **fully verified** khi mọi kỹ năng của mọi nghĩa đã học đều verified.

## 9. Custom word và AI (`custom-words`)

**Luật không thương lượng:** những gì người học viết **chỉ ở trong kho riêng của họ** và không bao giờ đổi nội dung chung.

### Luồng

1. `POST /custom-words/lookup {text, context?}` tìm trong toàn bộ kho trước (unique theo ngôn ngữ + lemma đã chuẩn hóa + homograph key; dạng biến thể như "ran" trả về lemma "run").
   - Có → `existing` với các nghĩa: `available`, `translation_draft` (AI dịch sang `explanationLocale` để xem trước), `unavailable`.
   - Chưa có → AI tạo `lexical_drafts` (tối đa 3 sense: loại từ, IPA en-US, CEFR, popularity, nghĩa, định nghĩa, 1–3 ví dụ có vị trí highlight) → `draft`.
   - Có `context` → `new_meaning_draft`: nghĩa mới **thuộc riêng** người học (`meanings.owner_user_id`).
   - Không phải từ → `invalid`.
2. `POST /custom-words {meaningId}` hoặc `{draftId, senseIndex, edits?}`. Nội dung ghi vào kho **luôn đọc từ `lexical_drafts`**, không bao giờ từ request. AI draft được publish nguyên bản, không qua editor; ElevenLabs tạo audio khi xác nhận (lỗi thì vẫn thêm, worker bù sau).
3. Từ vào lộ trình riêng: một topic cá nhân dưới collection `personal` để ở `draft`, nên catalog và `setScope` bỏ qua nó. `daily` phục vụ các từ này trước.

### Ranh giới nội dung

- Bản sửa của người học chỉ nằm ở `user_meaning_overrides` (gộp theo field, gắn với locale). Không bao giờ được gửi cho AI làm nguồn dịch, không hiện cho reviewer, không được duyệt.
- Nội dung AI chưa duyệt không vào catalog và không làm đáp án nhiễu. Mọi query liệt kê nghĩa của một từ phải lọc `owner_user_id IS NULL OR = user`.
- Nghĩa riêng chỉ chia sẻ khi admin duyệt **text AI đã lưu** (`POST /admin/ai-meanings/:id/approve`).
- `origin` (`ai_generated` / `curated`) cho biết nội dung từ đâu; `editorial_state` không còn chứng minh có người duyệt.

### Hạn mức (thử nghiệm)

30 lượt gọi AI mỗi ngày (UTC; tra trúng kho hoặc nháp đã lưu không tính), 500 từ trong lộ trình, 8 nghĩa mỗi từ, text ≤ 64 ký tự, context ≤ 200 ký tự. Vượt → `429 CUSTOM_WORD_LIMIT_REACHED`.

### Worker

| Job | Nhịp | Việc |
|---|---|---|
| `translate` | 10 giây | Dịch một Meaning còn thiếu `explanationLocale` của ai đó (sau khi họ đổi ngôn ngữ), publish cho mọi người. Session không bao giờ gọi AI vì text đã nằm trong snapshot |
| `repairAudio` | 1 phút | Bù một audio TTS bị lỗi lúc thêm |

Mỗi job không chồng tick nếu provider chậm.

## 10. Admin (`/admin`)

Cần `app_metadata.role` là `editor` hoặc `admin`. `admin` chỉ có ở tài khoản `pnpm db:seed` tạo từ `SEED_ADMIN_*`; API chỉ cấp/thu `editor` và không đổi được tài khoản `admin`. `/admin/users` cần role `admin`. Role mới có hiệu lực khi token của user đó refresh.

| Nhóm | Route chính |
|---|---|
| Từ và nghĩa | `GET/POST /admin/words`, `PATCH/DELETE /admin/words/:id`, word types, pronunciations, meanings, examples, `PUT/DELETE .../locales/:locale` |
| Vòng đời | `POST /admin/meanings/:id/publish`, `/recall`, `GET /admin/meanings/:id/publications` |
| Practice item curated | `POST /admin/practice-items`, `PATCH/DELETE` (chỉ khi draft), `/publish`, `/retire` |
| Catalog | `/admin/collections`, `/admin/topics`, `/admin/topics/:id/meanings` (thêm, xóa, sắp thứ tự) |
| Nội dung AI | `GET /admin/ai-meanings`, `POST /admin/ai-meanings/:id/approve` |
| Người dùng | `GET /admin/users`, `PUT /admin/users/:id/role` |
| Meta | `GET /admin/meta` |

Quy tắc: chỉ xóa được nội dung chưa từng publish (đã publish thì `recall` / `retire`; còn tham chiếu → `409 CONTENT_LOCKED`). `lemma` và `homographKey` bị khóa khi đã có nghĩa publish hoặc có người sở hữu. Publish practice item chạy cùng kiểm tra planner dùng lúc phát hành. Nghĩa riêng chỉ có thể duyệt hoặc recall, không sửa. `collection personal` và topic cá nhân vô hình với các route này.

## 11. Journey và Tổng ôn (`journey`, `checkpoint`)

- Một **chặng** = `weeklySessionGoal` session `daily` có học từ mới (mặc định và tối đa 7) + 1 Tổng ôn. Chỉ session daily có từ mới chiếm một slot; ôn tập, random, weak và commit lặp thì không.
- Đủ số session → mở một `checkpoint_challenge` gồm các Meaning đã học trong chặng. Có thể nhiều challenge trong một ngày.
- **Khóa từ mới khi challenge đang chờ** (`gateNewWords`): daily chỉ còn ôn đến hạn. Làm xong challenge thì từ mới mở lại. Tổng ôn không có ngưỡng đạt.
- Đổi `weeklySessionGoal` có hiệu lực ngay cho chặng hiện tại: tăng thì dài ra, giảm xuống ≤ số đã học thì challenge mở luôn.
- `GET /me/journey`: chặng tương lai (`preview`), chặng hiện tại (`active`), lịch sử (`completed`), phân trang lịch sử bằng `before`. Node có id ổn định (`segment:2:learning:1`), `state` `locked | current | completed`, toàn hệ thống chỉ một node `current`. Backend quyết định mọi trạng thái.

## 12. Placement test (`placement`)

`GET /me/placement-test` trả tối đa 3 câu `select/gloss` mỗi level A1–C2, dễ trước khó sau, lấy từ nội dung curated của kho chung. Option id là `wordId` (UUID), nên chấm không cần lưu đáp án; không lưu đề hay lịch sử. `POST` chấm: một level đạt khi đúng ≥ 60%; kết quả là level cao nhất mà nó và mọi level dưới đều đạt (không đạt gì → A1), lưu luôn vào hồ sơ. Không tạo tiến trình học. Level chỉ sắp thứ tự từ mới, không loại từ nào.

## 13. Speech (`speech`)

`POST /sessions/{id}/recording-assess` (multipart: `taskId`, `audio` ≤ 2 MB, khuyến nghị WAV PCM 16 kHz mono) gửi cho Azure Pronunciation Assessment, trả `{assessmentReceiptId, validity, passed, accuracyScore}`. Receipt thuộc đúng task, hạn 72 h, dùng một lần. `invalid` (im lặng, nhiễu) không phải fail. Audio không được lưu. Lỗi provider → `503 SPEECH_PROVIDER_UNAVAILABLE`, client có thể gửi `unavailable`.

## 14. Vận hành

### 14.1. Chạy local

```sh
pnpm install
cp .env.example .env      # điền giá trị Supabase
pnpm db:migrate           # cần DIRECT_URL
pnpm db:seed              # tài khoản admin + demo tùy chọn: 4 collection, 20 từ, 33 curated item (chỉ text)
pnpm start:dev
```

Seed phải chạy qua build Nest (`tsx`/esbuild không phát decorator metadata).

| Lệnh | Việc |
|---|---|
| `pnpm test` | Unit + REST integration trên Postgres nhúng; test mang mã case của spec (C01–C62) |
| `pnpm test:unit`, `pnpm test:int` | Từng phần |
| `pnpm lint`, `pnpm build` | |
| `pnpm db:migrate`, `pnpm db:seed` | |

### 14.2. Biến môi trường chính

| Biến | Ghi chú |
|---|---|
| `DATABASE_URL` | Supabase transaction pooler (6543) |
| `DIRECT_URL` | Kết nối trực tiếp (5432), chỉ cho migration |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Auth, seed admin, upload audio |
| `SUPABASE_AUDIO_BUCKET` | Bucket public cho audio TTS (tạo trước) |
| `AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION` | Chấm phát âm |
| `ANTHROPIC_API_KEY`, `LEXICAL_AI_MODEL` | Custom word |
| `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, `ELEVENLABS_MODEL_ID` | TTS |
| `ENABLE_CRON` | `false` trên replica phụ |
| `DB_POOL_SIZE`, `JWT_AUDIENCE` | Tùy chọn |
| `SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD`, `SEED_ADMIN_USERNAME` | Tài khoản admin duy nhất |

### 14.3. Cron (`maintenance`)

Mỗi giờ, trong process: đánh dấu session `issued` quá hạn là `expired`; sau 30 ngày kể từ hết hạn hoặc commit thì xóa `plan` và `raw_events` (giữ `result` và session row); dọn `deleted_identities` sau 7 ngày. Giả định một instance; replica khác chạy `ENABLE_CRON=false`.

### 14.4. Deploy

Chạy trên cùng VM OCI với money-space, qua domain của money-space tại `https://<money-space domain>/service/vocab/`:

```text
push master ──► build image arm64 ──► OCIR (vocab-backend) ──► ssh vào VM
                                                                  │
  Caddy (của money-space) ── network edge ──► vocab-backend ◄─────┘
     └─ routes/vocab.caddy (deploy ghi vào, handle_path bỏ /service/vocab)
```

- Migration chạy **trước** restart ở mỗi deploy (bỏ qua bằng *skip_migrations* khi chạy tay).
- Port app chỉ mở trên `127.0.0.1` (mặc định 3001).
- Rollback: đặt `BACKEND_IMAGE` trong `$APP_DIR/.env` về tag `:<sha>` cũ rồi `docker compose up -d`. Migration không được đảo ngược.
- Log: GitHub Actions → *Fetch backend logs*. Registry được dọn hằng tuần (`prune-registry.yml`).
- Thiết lập một lần, secrets và variables: `vocab-backend/DEPLOYMENT.md`.

## 15. Chưa làm

- Tách DB role tối thiểu quyền (app đang kết nối bằng `postgres`; trigger vẫn bảo vệ snapshot).
- Rate limit theo request (chỉ giới hạn kích thước event/audio và hạn mức AI riêng).
- Người học báo nghĩa AI sai.
- Audio cho từ catalog có sẵn (ElevenLabs mới chỉ phủ từ tạo qua custom word).
- Metrics giám sát và audit log (log mới có `requestId`).
- Giới hạn lạm dụng event `unavailable` của recording.

Danh sách đầy đủ các điểm cần quyết định (shape event, priming, SRS sau lỗi, xếp hạng từ yếu, retention...) ở `vocab-backend/docs/DECISIONS.md`.
