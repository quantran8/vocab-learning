# Syll: Tính năng app và Core function Frontend

Client iOS của Syll: tính năng theo từng màn hình (phần A) và cách client vận hành bên trong (phần B). Concept sản phẩm ở [01_APP_CONCEPT.md](01_APP_CONCEPT.md), backend ở [03_BACKEND.md](03_BACKEND.md). Contract API đầy đủ từng field ở `vocab-backend/docs/FRONTEND_FLOW.md`.

| | |
|---|---|
| Nền tảng | iOS 17+, SwiftUI, Swift 5 mode |
| Project | `VocabFlow.xcodeproj`, scheme `VocabFlow`, display name **Syll** |
| Dependency (SPM) | `lottie-ios` (confetti cuối buổi), `rive-ios` / `RiveRuntime` (mascot Syllie) |
| Backend | Simulator: backend local. Máy thật: `https://moneytogether.dpdns.org/service/vocab/`. Ghi đè bằng biến môi trường `VOCABFLOW_API_URL` của scheme |
| Ngôn ngữ UI | English, Tiếng Việt |
| Giao diện | Chỉ light mode |

---

# Phần A. Tính năng

## 1. Bản đồ màn hình

App không dùng `NavigationStack` ở cấp gốc. `AppRootView` suy ra một route từ trạng thái các store và thay cả màn hình:

```text
Splash
  └─► Auth (chưa có token)
        └─► Chọn ngôn ngữ (lần đầu, chưa chọn)
              └─► Loading hồ sơ (GET /me)
                    ├─► Onboarding (chưa có level/scope)
                    └─► Main shell (TabView)
                          ├─ Home ── Challenge Map
                          ├─ My Words ── Random Practice
                          └─ Profile ── Settings ── Practice Lab
Practice session (toàn màn hình, đè lên shell khi đang có session)
Challenge run / Match Madness (toàn màn hình, đè lên shell khi đang có run)
```

Thứ tự ưu tiên của route: trạng thái auth → ngôn ngữ → hồ sơ learner → onboarding → session practice đang chạy → challenge run đang chạy → Practice Lab → shell. Đóng session thì quay lại đúng tab và trang đã mở nó.

## 2. Tài khoản

### 2.1. Đăng nhập và đăng ký (`Features/Auth/`)

- **Email + mật khẩu:** đăng nhập, đăng ký (màn `SignUpView` push trong `NavigationStack` riêng của Auth). Nếu project Supabase bật xác nhận email, đăng ký xong hiện màn "kiểm tra email".
- **Sign in with Apple** và **Google** (không dùng Google SDK: OAuth code + PKCE trong `ASWebAuthenticationSession`, client ID lấy từ `GoogleClientID` trong Info.plist). Cả hai gửi ID token và nonce gốc cho backend.
- **Quên mật khẩu, 2 bước:** nhập email → nhận mã qua email → nhập mã + mật khẩu mới, đăng nhập luôn.
- **Quy tắc mật khẩu mới** (`PasswordPolicy`): 8–72 ký tự, có ít nhất một chữ cái và một chữ số. `PasswordRuleList` hiện từng quy tắc theo thời gian thực. Backend kiểm tra cùng quy tắc.
- **Đổi mật khẩu** trong Settings (`ChangePasswordSheet`). Sai mật khẩu hiện tại trả `403`, không đăng xuất.
- **Đăng xuất, xóa tài khoản** trong Settings. Xóa tài khoản dùng `.alert` có nút hủy rõ ràng; thành công thì xóa token, kế hoạch học và lịch nhắc trên máy.

Cấu hình provider (Google Cloud, Apple Developer, Supabase, SMTP): `docs/AUTH_SETUP.md`.

### 2.2. Chọn ngôn ngữ (`LanguageSelectionView`)

Sau lần đăng nhập đầu, người dùng chọn ngôn ngữ giao diện (English / Tiếng Việt) trước khi app gọi `GET /me`. Đổi lại được trong Settings, áp dụng ngay không cần khởi động lại.

## 3. Onboarding (`Features/Onboarding/`, `Features/PlacementTest/`)

**Welcome → Level (tùy chọn qua bài test) → Collection → Topics → Routine → Ready**

| Bước | Người dùng làm gì | Gọi API |
|---|---|---|
| Welcome | Màn giới thiệu, có các tile F·L·O·W rơi xuống (trang trí) | |
| Level | Chọn A1–C2, hoặc mở **bài test xếp level** | `PUT /me/levels` |
| Placement test | Tối đa 3 câu mỗi level, chỉ câu chọn nghĩa, có nút "Không biết". Client không chấm, không hiện đúng/sai; backend chấm và lưu level. Không có câu hỏi thì quay về tự chọn | `GET` / `POST /me/placement-test` |
| Collection | Chọn 1 collection | `GET /catalog/collections` |
| Topics | Chọn ≥1 topic, có "chọn tất cả" | |
| Routine | Số từ mới mỗi buổi (1–30), ngày học trong tuần, giờ nhắc học | `PUT /me/scope`, `PUT /me/settings` (`dailyNewWordGoal`, `weeklySessionGoal` = số ngày học) |
| Ready | Tóm tắt kế hoạch, vào Home | |

- Welcome và bài test là màn riêng; các bước Level → Ready dùng chung một khung (`SetupFlowView`): header và nút hành động cố định, chỉ nội dung bước trượt qua lại.
- Bài test cũng mở được sau này từ Profile → sửa level (`EditLevelView`, dạng full-screen cover).
- Thiết bị mới hoặc đăng nhập lại: nếu tài khoản đã có scope, app nhận scope và goal từ server (`LearningPlanStore.adopt`); ngày học và nhắc học chỉ lưu trên máy.

## 4. Home (`Features/Home/HomeView.swift`)

- **Daily Lesson** (trạng thái lấy từ `DailyLessonStatus`, tính từ khối `scope` và `reviewLoad` của learn-home):
  - Hai số: từ cần ôn, và số từ mới thực nhận hôm nay (`effectiveNewPerSession`). Nút "Start" (có từ cần ôn) hoặc "Start Flow".
  - Các dòng nhỏ giải thích khi số từ mới ít hơn goal:
    - còn ít hơn một chặng: "Còn 12 từ mới, khoảng 3 buổi", kèm link "Thêm Topic";
    - scope chỉ còn ít hơn số từ đã chọn: "Hôm nay còn 3 từ mới trong Travel";
    - đang giảm tạm thời: "Hôm nay 2 từ mới (bạn đang giảm tạm thời đến …)";
    - Tự cân bằng đang giảm số từ mới.
  - **Nợ ôn:** khi có hơn 10 từ chờ ôn thì hiện dòng "34 từ chờ ôn" và nút **"Ôn thêm"** (một daily chỉ ôn).
  - **Hết từ mới:**
    - Không còn từ tự thêm: thẻ báo đã học hết từ mới trong các Topic đang chọn. Các nút là "Ôn N từ" (nếu có từ đến hạn) hoặc "Luyện tập" (mở Random Practice), cùng "Chọn Topic" và "Đổi Collection" (mở sheet Focus).
    - Còn từ tự thêm: chỉ ghi "Hết từ mới trong Topic. Còn N từ bạn tự thêm" và vẫn Start bình thường.
- **Màn lựa chọn khi nợ ôn nhiều** (`ReviewLoadChoiceSheet`): mở khi backend trả `promptChoice` (lần đầu từ 20 từ chờ ôn, hiện lại khi số từ gấp đôi).
  - Tối đa một lần mỗi lần mở app, không bao giờ giữa session.
  - Ba lựa chọn ngang hàng: Học như bình thường, Ôn thêm một buổi, Giảm từ mới tạm thời. Giảm tạm thời thì chọn số từ và thời hạn: đến hết Chủ Nhật, hoặc đến khi còn ≤ 10 từ chờ ôn.
  - Đóng sheet bằng bất kỳ cách nào cũng gửi `POST /me/review-load/ack`, nên thiết bị khác không hỏi lại.
- **Syllie trên Home** (`LessonMascot`, artboard `HomeSyllie`): đứng idle, chơi một cảnh ngẫu nhiên (tung chữ cái, đuổi máy bay giấy), rồi ngủ gật có "z z z". Chạm thì Syllie thức dậy và vòng lặp bắt đầu lại. Reduce Motion thì bỏ cảnh chơi.
- **Challenge** (`ChallengeHomeCard`): thẻ gọn tóm tắt Challenge Map từ server (chưa đủ từ, chương sẵn sàng, đang chơi chương/level nào và số sao, đã xong chương, chương thiếu nội dung). Chạm mở Challenge Map. Thẻ không bao giờ ngụ ý Daily bị chặn và không có badge khẩn cấp. Khi đã hết từ mới (`newWordsBlockedReason = scope_exhausted`), Home hiện "Chọn Topic mới để tiếp tục hành trình" và các nút "học thêm" của thẻ mở sheet Focus thay vì plan daily.
- Kéo để làm mới (`learner.refresh()`).

## 5. Practice session (`Features/Practice/`)

Mọi lượt học thật đều là một **session backend**: plan → làm từng step → commit.

### 5.1. Các mode

| Mode | Mở từ | Nội dung |
|---|---|---|
| `daily` | Home | Ôn từ đến hạn (tối đa 10, **mọi từ đã học**, không chỉ scope hiện tại) rồi học từ mới (tối đa số từ thực nhận/buổi) |
| `daily` + `reviewOnly` | Home: "Ôn thêm", "Ôn N từ", màn lựa chọn | Chỉ ôn đến hạn, không từ mới, không chiếm slot Journey |
| `checkpoint_challenge` | (không còn lối vào từ UI) | Tổng ôn các từ đã học trong chặng, chỉ dạng tự nhớ lại |
| `random_practice` | My Words → Random Practice | Tối đa 10 từ đã học; trộn kỹ năng hoặc theo kỹ năng chọn; nguồn từ: tất cả, một Collection, một Topic, hoặc từ tự thêm |
| `weak_words_practice` | My Words | Các nghĩa có kỹ năng đang có vấn đề, luyện đúng kỹ năng đó |

### 5.2. Luồng một session (`PracticeSessionStore.Stage`)

```text
planning ──► empty (không có gì để học/ôn)
   │
   ├─► reviewPreview  "Ôn từ bạn đã học": danh sách từ sắp ôn (kèm nhãn Topic) bay vào, Syllie dõi theo rồi gật đầu
   │
   ├─► running        từng step theo đúng thứ tự backend trả về
   │      ├─ learn     thẻ giới thiệu từ
   │      └─ practice  một task (1 trong 7 template)
   │
   ├─► reviewFinished (chỉ daily) ôn xong, chuyển sang từ mới; Syllie "review_to_learn"
   │
   ├─► committing
   │
   └─► finished       màn kết quả + Syllie ăn mừng + confetti
       failed         planning / commit (retry được) / sessionLost (phải plan lại)
```

- Khi plan daily chỉ có phần ôn, app commit phần ôn, rồi **plan tiếp một session daily** để vào thẳng từ mới, không quay về Home. Việc này **chỉ xảy ra khi `newWords.withheldReason == null`**. Có lý do bất kỳ (hết từ, đang giảm tạm thời, chỉ ôn...) thì plan lại cũng nhận cùng câu trả lời, nên session kết thúc luôn để tránh vòng lặp.
- Plan rỗng vì hết từ mới (`withheldReason = scope_exhausted`) không hiện màn trống chung chung, mà hiện "Bạn đã học hết từ mới ở đây" kèm nút "Chọn Topic" và "Luyện tập".
- Màn chuyển sang từ mới ghi "Giờ đến từ mới của Travel".
- Màn session không mở được sheet của shell. Nó gọi `close(followUp:)`, và `MainShellView` đọc hành động đó (`consumeFollowUp()`) khi hiện lại: mở sheet Focus (chuyển sang tab Profile) hoặc Random Practice.
- Thanh tiến độ chia theo phần (`SessionPartProgress`: review, newWords, practice).
- Thoát giữa chừng thì không gửi gì; backend không ghi nhận gì, từ mới vẫn là "chưa học".

### 5.3. Thẻ Learn (`LearnCardStep`)

Từ, loại từ, IPA, nghĩa tiếng Việt, định nghĩa tiếng Anh, ví dụ kèm bản dịch, nút phát âm (audio thật nếu có, nếu không thì giọng đọc của thiết bị). Phần giới thiệu dùng các motion recipe trong `Features/Learn/MotionTemplates/` (letter cascade, letter wave, flip, chunk merge, swipe reveal, word assemble). Nếu từ có nghĩa khác, link "Other meanings" mở sheet tham khảo (`OtherMeaningsSheet`, gọi `GET /words/{wordId}`), không thuộc session.

### 5.4. Thứ tự học từ mới (backend quyết định)

Từ mới chia nhóm tối đa 3 nghĩa. Mỗi nhóm: các thẻ Learn liên tiếp, rồi 5 vòng xen kẽ giữa các nghĩa trong nhóm:

1. Select: chọn nghĩa của từ
2. Select: chọn từ cho nghĩa
3. Recall: gõ từ hoặc xếp chữ (**bắt buộc** submit ít nhất một lần)
4. Recording: đọc to
5. Select: chọn nghĩa lần nữa

Từ người dùng tự thêm luôn được học trước từ của topic.

**"Tôi biết từ này"** (thử nghiệm, bật ở Settings › "Bỏ qua từ đã biết"; plan gửi `knownCheck: true`):
- Trước mỗi thẻ Learn có một task gõ từ (`phase: known_check`) với banner "Bạn đã biết từ này?".
- Đúng ngay lần đầu, không gợi ý: bỏ qua thẻ Learn và các task chỉ kiểm riêng từ đó (`skippableTaskIds`). Lần ôn đầu của từ là sau 7 ngày.
- Sai: học như bình thường, lần sai không bị tính là quên.
- Nút "Học từ này": bỏ phần kiểm tra, không gửi kết quả của task đó.
- Task nối cặp có cả từ khác vẫn phải làm.

### 5.5. Bảy template bài tập (`Features/Practice/Tasks/`)

Mọi task dùng chung `TaskScaffold`: câu hỏi → prompt (text hoặc audio) → vùng bài tập → feedback → nút hành động ghim dưới đáy (Check / Try again / Continue). Syllie đứng cạnh nút hành động.

| Template | View | Người dùng làm | Ghi chú |
|---|---|---|---|
| `select` | `ChoiceTaskView` | Chọn 1 trong 2–4 đáp án | Biến thể: gloss, reverse gloss, meaning clash (có highlight trong câu), phonetic choice, stress choice; prompt có thể là audio |
| `cloze_select` | `ClozeTaskView` | Chọn từ điền vào chỗ trống | Câu ghép từ `sentenceParts.before` + ô trống + `after` |
| `typing` | `TypingTaskView` | Gõ từ | Meaning recall (từ nghĩa) hoặc transcription (nghe rồi chép). So khớp: NFC, trim, gộp khoảng trắng, không phân biệt hoa thường; giữ dấu (`cafe` ≠ `café`) |
| `fly_reorder` | `ReorderTaskView` | Chạm các tile chữ để xếp thành từ, chạm để bỏ, kéo để đổi chỗ | Mỗi tile là một grapheme. Mọi thao tác đều được ghi để backend phát lại |
| `match` | `MatchTaskView` | Nối cặp trái–phải | Gửi từng cặp; chỉ có ở Random/Weak |
| `surgery` | `SurgeryTaskView` | Sửa/xóa một hoặc nhiều chữ sai trong từ | Đúng khi từ sau khi sửa khớp đáp án, bất kể sửa cách nào |
| `recording` | `RecordingTaskView` | Đọc to | Chấm trên máy hoặc qua backend (Azure); xem 5.7 |

Template hoặc variant lạ là lỗi nghiêm trọng: cả plan bị coi là hỏng, vì commit cần kết quả của mọi task.

### 5.6. Phản hồi, gợi ý, thử lại

- **Chấm ngay trên máy** bằng khối `evaluation` của task, để phản hồi tức thì. Backend chấm lại toàn bộ từ events khi commit; client không bao giờ gửi "đúng/sai".
- **Feedback không lộ đáp án** cho tới khi task kết thúc (đúng, hết lượt, hoặc xem đáp án).
- **Số lần thử** = 1 + `maxRetries` của task (hiện: select/cloze/match 1 lần thử lại, typing/reorder/surgery/recording 2). Hết lượt thì app tự chuyển câu, task tính là sai.
- **Gợi ý** (`HintControl`) và **Show answer** được ghi thành event `hint` / `reveal`; dùng chúng làm giảm giá trị bằng chứng.
- **Syllie khi làm bài:** một vòng "suy nghĩ" ngẫu nhiên (`thinking` hoặc `deepThought`) khi đang trả lời; đúng thì một biến thể vui ngẫu nhiên, sai thì một biến thể "oops". Phản ứng chỉ bắt đầu sau animation của chính câu trả lời (`MotionTokens.answerFeedbackSettle`), rồi tự về idle.
- Haptic và âm thanh nhẹ cho đúng/sai, theo cài đặt Haptics.

### 5.7. Recording

Mỗi task chọn một cách chấm (`RecordingScoring`), không trộn:

| Cách | Luồng | Commit |
|---|---|---|
| **On-device** (mặc định khi được) | Speech-to-text trên máy, so với `acceptedResponses[0]`. Chỉ đúng/sai, không có điểm | Mỗi lần đọc một event `transcribed` |
| **Backend** (khi task không có reference text hoặc máy không nhận dạng được) | Upload audio (WAV, tối đa 2 MB) lên `recording-assess`, nhận receipt có `accuracyScore`; đạt khi ≥ 80 | Một event `assessed` với receipt cuối cùng |
| **Không ghi âm được** (không có quyền mic, lỗi thiết bị, speech provider lỗi mãi) | Hiện trạng thái blocked | Event `unavailable` kèm lý do; không bị tính là sai |

Nút ghi âm "thở" khi nghỉ; vòng halo và sóng âm chỉ hiện khi mic nghe thấy giọng (đã làm mượt để không nháy).

### 5.8. Kết quả (`PracticeResultsView`)

"Flow complete" hoặc "Review complete" (Tổng ôn), các số liệu tóm tắt từ commit (từ mới, từ bạn đã biết, nghĩa đã ôn, số task; Tổng ôn thêm số từ tự nhớ được và số cần ôn lại).
- Commit có `scopeEvents` thì hiện thẻ "Bạn đã học hết Health" (Syllie `proud`), nút "Chọn Topic tiếp theo" và "Để sau".
- Khi `collectionCompleted` thì hiện thẻ chúc mừng cả Collection.
- Sự kiện được lưu trong commit response, nên retry không chúc mừng hai lần. Syllie bay vào, đáp xuống, nhún và lắc lư vui (artboard `Celebrate`); confetti Lottie bắt đầu ở `confettiCue` (~1,1 s).

## 6. Challenge Map và Match Madness (`Features/Challenge/`)

Thay cho Journey / Tổng ôn. Challenge tách hẳn khỏi Daily: không đụng SRS, không dùng `PracticeSessionStore`. Chi tiết phía iOS, các chỗ phải khớp backend và cách kiểm tra lại: [04_CHALLENGE_IOS_NOTES.md](04_CHALLENGE_IOS_NOTES.md).

### 6.1. Challenge Map (`ChallengeMapView`, trang `ShellPage.challengeMap` của tab Home)

- Các chương xếp từ trên xuống, mỗi chương 3 level Match Madness rồi một cúp, nằm trên một con đường lượn sóng nối liền qua các chương (`ChallengeMapWave`). Cuối map là chương kế tiếp ở dạng xem trước.
- **Banner chương** (`ChapterBanner`): số chương, trạng thái, số sao đã đạt. Chương chưa mở có điều kiện mở khoá ngay trong banner: "Hoàn thành Chương N…", hoặc số từ mới đã đủ / cần kèm thanh tiến độ, giải thích và nút "Tiếp tục bài học hằng ngày".
- **Node level:** nút tròn nổi khối (khoá / chơi / đã qua) và số sao tốt nhất bên dưới. Level hiện tại có vòng sáng và bong bóng "Start" nhún nhảy. Level đã qua chơi lại được.
- Chạm level mở `ChallengeLevelSheet`: mục tiêu (số cặp, thời gian) và luật sao lấy từ map; plan của run có tiếng nói cuối cùng. Kèm điểm cao nhất nếu đã qua, và nút Play.
- Mọi trạng thái do server quyết định; client không tự mở khoá bằng cách đếm từ. `ChallengeMapStore` làm mới sau mỗi run đã chốt và khi shell hiện ra.

### 6.2. Một lượt chơi (`MatchMadnessGameView`, `ChallengeRunStore`)

```text
issuing ─► ready (màn "Start": mục tiêu, luật sao, gợi ý lần đầu) ─► starting ─► playing ─► committing ─► results
                                                                                 └─► commitFailed (thử lại; mở app lần sau tự gửi)
```

- Đồng hồ chỉ chạy sau khi `POST …/start` trả lời, và không bao giờ tạm dừng. Quay lại foreground thì đọc lại đồng hồ; hết giờ thì run kết thúc `time_up`.
- **Màn chơi:** hàng trên cùng gồm nút thoát, thanh tiến độ (số cặp đã nối / mục tiêu) và đồng hồ (đỏ khi còn ≤ 10 s; chế độ không giờ hiện "Untimed"). Dưới đó là tiêu đề "Match the pairs", rồi combo và điểm tạm thời (số lăn khi đổi). Bảng gồm hai cột: từ và nghĩa.
- **Chạm:** chọn một từ và một nghĩa, theo thứ tự nào cũng được. Thẻ lún xuống khi nhấn, giống thẻ Chọn đáp án. Cặp sai thì cả hai thẻ đỏ và rung, combo về 0.
- **Cặp đúng:** hai thẻ chuyển xanh trong 0,3 s rồi mờ dần. Cặp mới hiện dần **đúng vào chỗ cũ**, các thẻ khác đứng yên (`ChallengeBoardSlots`). Engine vẫn xếp lại thứ tự cột sau mỗi lần nối đúng để khớp phát lại của backend, nhưng màn hình không theo thứ tự đó, vì commit chỉ gửi tile ID, không gửi vị trí.
- **Kết quả** (`ChallengeResultsView`): chỉ hiện sau khi commit trả lời, gồm sao, điểm và mở khoá do server tính. Màn ăn mừng ngắn, không chặn nút "Next Level".
- Mascot tạm thời không xuất hiện trên màn chơi.

## 7. My Words (`Features/Words/`)

- **Thống kê thư viện:** số từ đã học, số từ cần luyện (`GET /me/words/stats`).
- **Ô luyện tập:** Random Practice (push sang màn chọn kỹ năng) và Weak Words practice.
- **Random Practice** (`RandomPracticeView`): "All skills" (trộn) hoặc chọn một hay nhiều kỹ năng Reading / Writing / Listening / Speaking.
  - Mục **"Nguồn từ"**: Tất cả, một Collection đã học (chọn rồi thu hẹp được về một Topic), hoặc từ tự thêm. Mỗi lựa chọn kèm số từ đã học.
  - Chưa plan gì cho tới khi bấm Start.
- **Danh sách từ đã học**, mới nhất trước, phân trang tự động khi cuộn gần cuối, tìm theo từ tiếng Anh hoặc nghĩa (không phân biệt dấu). Mỗi dòng ghi "x / y nghĩa đã học".
- **Chi tiết từ** (`WordDetailSheet`): mọi nghĩa nhóm theo loại từ, đã học hay chưa, định nghĩa, ví dụ, phát âm, và **trạng thái từng kỹ năng** của từng nghĩa:

| Nhãn | Ý nghĩa |
|---|---|
| Not verified | Chưa có lần tự làm đúng |
| Demonstrated | Đã tự làm đúng, chưa đủ để xác minh |
| Verified | Tự làm đúng ở ≥2 buổi cách nhau ≥24 h |
| Recently needed help | Đúng nhờ gợi ý hoặc ở lần thử thứ hai |
| Verified, but recently needed help | Vẫn verified, nhưng lần gần nhất cần trợ giúp |
| Needs practice again | Sai hoặc xem đáp án; đã mất verified |

## 8. Tự thêm từ (`Features/CustomWords/`)

Mở từ My Words. Hai sheet: **Add word** và **danh sách từ tự thêm**.

1. Gõ từ (1–64 ký tự, chỉ chữ cái, dấu cách, `-`, `'`, bắt đầu bằng chữ cái; kiểm tra ngay trên máy).
2. Backend tra kho chung. Có thể mất vài chục giây khi phải gọi AI (timeout client ≥ 65 s, có trạng thái đang tải).
3. Kết quả:
   - **existing:** các nghĩa đã có; mỗi nghĩa `available` (thêm được), `translation_draft` (AI vừa dịch sang ngôn ngữ của người dùng), `unavailable` (hiện mờ). Đã có trong lộ trình hoặc đã học thì hiện nhãn thay cho nút thêm. Nút "Không có nghĩa tôi cần" tra lại kèm mô tả ngữ cảnh; nghĩa tạo ra chỉ thuộc riêng người đó.
   - **draft / new_meaning_draft:** tối đa 3 nghĩa do AI tạo; xem trước, chọn, sửa.
   - **invalid:** không phải từ hợp lệ.
   - Gõ dạng biến thể ("ran") có thể trả về lemma "run": app hiện lemma.
4. Thêm vào lộ trình. Từ tự thêm được học trước từ của topic, qua đúng session daily.

Danh sách từ tự thêm: xem chi tiết, sửa nội dung riêng (nghĩa, định nghĩa, 1–3 ví dụ, chọn đoạn highlight), khôi phục bản gốc, xóa (có hỏi xác nhận). Trạng thái "Đang dịch" sau khi đổi ngôn ngữ giải thích, "Không còn khả dụng" khi admin gỡ. **Bản sửa chỉ áp dụng cho chính người dùng đó**, không bao giờ đổi nội dung chung.

## 9. Profile và Settings

**Profile** (`Features/Profile/`): "My learning space" gồm level, collection và topic đang học (gọn lại "+N more"), số từ mới mỗi buổi, ngày học, nhắc học. Ba sheet chỉnh sửa: Level (kèm bài test), Focus (collection + topic), Routine (số từ/buổi, ngày học, giờ nhắc). Đóng sheet không lưu thì bỏ bản nháp.

- **Sheet Focus:**
  - Mỗi Topic hiện tiến độ "45/120". Topic đã học hết có nhãn "Đã học xong", xếp cuối, vẫn chọn được. Trạng thái này tính động, nên Topic được thêm nội dung sẽ có lại từ mới.
  - Khi bản nháp bỏ một Topic đã học, footer giải thích rằng các từ đó vẫn được ôn và sẽ thưa dần.
- **Routine:** công tắc "Tự cân bằng ôn và từ mới" (mặc định tắt). Khi đang giảm từ mới tạm thời thì hiện dòng "Đang giảm còn N từ mới" kèm nút **Hủy**. Đổi goal thì backend tự hủy phần giảm.
- **Ôn tập:** liệt kê các Collection đã học ít nhất 1 từ, với công tắc "Ôn từ của Collection này". Active collection luôn được ôn, công tắc bị khóa. Tạm dừng thì từ chỉ thuộc Collection đó không vào daily, nợ ôn, Weak hay Random "Tất cả"; lịch ôn vẫn giữ nguyên.

**Settings** (`Features/Settings/`):

| Mục | Tác dụng |
|---|---|
| Haptics | Bật/tắt rung (`SettingsAwareFeedback`) |
| Reduce motion | Giảm chuyển động trong app, cộng với cài đặt hệ thống |
| Skip words I know | Thử nghiệm "Tôi biết từ này" trước mỗi từ mới (mặc định tắt, lưu trên máy) |
| Language | Ngôn ngữ giao diện, áp dụng ngay |
| Appearance | Chỉ light |
| Practice Lab | Thử các template bài tập, không ảnh hưởng tiến trình |
| Syllie animations | Xem trước các animation Rive của Syllie |
| About Syll | Thông tin app |
| Change password, Log out, Delete account | Xem mục 2 |

## 10. Nhắc học

`NotificationReminderScheduler` đặt một notification lặp lại cho mỗi ngày học, vào giờ người dùng chọn. Quyền notification chỉ được xin khi bật nhắc học. Mỗi lần lưu kế hoạch thì lịch nhắc được đặt lại; xóa tài khoản thì hủy hết.

## 11. Practice Lab (sandbox)

Từ Settings. Danh sách 7 template, mỗi template có các task mẫu trong `Resources/practice_lab.json` (đúng định dạng plan của backend). Chạy bằng chính các task view của session thật, qua một `PracticeSessionStore` riêng ở chế độ sandbox: chấm trên máy, không plan, không assess, không commit. Dùng để thiết kế và QA template.

Thêm hai thẻ **Match Madness** (có giờ 90 s và không giờ): `ChallengeRunStore.startSandbox` chạy một plan tĩnh trên cùng engine, không gọi API, không sao, không mở khoá.

---

# Phần B. Core function

## 12. Cấu trúc mã nguồn

```text
VocabFlow/
├─ App/              VocabFlowApp (dựng mọi store, inject bằng .environment), AppRootView (route)
├─ Networking/       APIClient, APIConfiguration, APIError, TokenStore, VocabAPI
├─ Domain/
│  ├─ Practice/      PracticeTask, TaskAttempt, TaskEvent, RecordingScoring
│  ├─ Challenge/     model map/run, MatchMadnessEngine, ChallengeBoardOrdering, ChallengeBoardSlots
│  ├─ Journey/       Journey, JourneySegment, JourneyNode (chờ gỡ, không còn màn nào dẫn tới)
│  ├─ CustomWords/   CustomWord và các kiểu lookup
│  ├─ Models/        LearningPreferences, VocabularyItem, ...
│  ├─ Content/       DemoContentRepository, ContentValidator, TopicCatalog, DemoSeed
│  └─ Learning/      SessionReducer (engine demo cũ)
├─ Features/         mỗi thư mục một khu vực (Auth, Onboarding, Home, Challenge, Practice, Words, CustomWords, ...)
├─ DesignSystem/     Tokens, Motion, Components (gồm các view Syllie)
└─ Resources/        Localizable.xcstrings, InfoPlist.xcstrings, practice_lab.json, demo_words.json,
                     Animations/syllie.riv, Sounds/
```

Project dùng file-system synchronized groups (`objectVersion = 77`): file mới trong `VocabFlow/` hoặc `VocabFlowTests/` tự được thêm, không sửa `project.pbxproj`.

## 13. Kiến trúc state

- Store là class `@Observable @MainActor`, dựng **một lần** trong `VocabFlowApp` và inject bằng `.environment(...)`. View đọc qua `@Environment(StoreType.self)`.
- Không có `NavigationStack` ở gốc: đổi màn hình là đổi state của store. `AppRootView` tính một `RouteID` rồi đổi view bằng `.id(route)` + transition. Session có `sessionToken` mới mỗi lần, nên màn hình không bao giờ mang state cũ sang.
- Bên trong shell, mỗi tab có `NavigationStack` riêng cho trang con (Challenge Map, Random Practice, Settings).

| Store | Trách nhiệm |
|---|---|
| `AuthStore` | Pha auth, đăng nhập/đăng ký/social, quên/đổi mật khẩu, đăng xuất, xóa tài khoản |
| `AppSettingsStore` | Haptics, reduce motion, ngôn ngữ giao diện |
| `LearnerStore` | `GET /me`, learn-home, checkpoint challenges, Journey; quyết định có cần onboarding |
| `OnboardingStore` | Các bước onboarding và bản nháp kế hoạch |
| `PlacementTestStore` | Bài test xếp level |
| `LearningPlanStore` | Kế hoạch học lưu trên máy, lên lịch nhắc |
| `PracticeSessionStore` | Session thật: plan → steps → commit (và chế độ sandbox) |
| `ChallengeMapStore` | Tải và làm mới Challenge Map |
| `ChallengeRunStore` | Một run Match Madness: issue → start → chơi → commit, retry, khôi phục run bị kill; sandbox cho Practice Lab |
| `TemplateSandboxStore` | Điều hướng Practice Lab, giữ `PracticeSessionStore` sandbox riêng |
| `CustomWordStore` | Tra, thêm, sửa, xóa từ tự thêm |
| `ProgressStore`, `SessionStore` | Engine demo cũ |

Preview phải inject đủ bộ store bằng test double: `NoOpFeedback`, `SilentSpeech`, `InMemoryPreferencesStore`, `NoReminders`, `OfflineVocabAPI`, `SilentAudioClips`, `NoVoiceRecorder`, `defaults: nil` (xem `#Preview` trong `AppRootView.swift`).

## 14. Networking

- **`APIClient`** (actor): gắn bearer token, khi gặp `401` thì refresh **một lần** rồi retry request gốc một lần; refresh cũng `401` thì đăng xuất. Retry có backoff cho lỗi `retryable`.
- **`TokenStore`**: access và refresh token trong Keychain (`KeychainTokenStore`). Refresh token dùng một lần, mỗi lần refresh thay cả cặp.
- **`VocabAPI`**: protocol liệt kê mọi call; `LiveVocabAPI` gọi backend, `OfflineVocabAPI` trả dữ liệu mẫu cho preview.
- **`APIError`**: map `{code, message, retryable, requestId}` của backend, có `userMessage` đã localize.

| Nhóm | Call |
|---|---|
| Auth | signUp, logIn (email / Google / Apple), requestPasswordReset, resetPassword, changePassword, signOut, deleteAccount |
| Hồ sơ | profile, updateLevels, placementTest, submitPlacementTest, updateSettings, updateScope, catalog |
| Home | learnHome, checkpointChallenges, journey (hai call sau chờ gỡ) |
| Challenge | challengeMap, issueChallengeRun, startChallengeRun, commitChallengeRun, challengeRunStatus, quitChallengeRun |
| Thư viện | words, wordStats, wordDetail |
| Custom word | lookupCustomWord, addCustomWord, customWords, removeCustomWord, overrideCustomWord, clearCustomWordOverride |
| Session | planSession, assessRecording, commitSession, commitStatus |

## 15. Session engine

### 15.1. Decode plan (`PracticeTask`)

`SessionPlan` gồm `sessionId`, `mode`, `expiresAt` (72 h) và `steps` có thứ tự: `learn(id, card)` hoặc `practice(phase, task)`. **Template hoặc variant lạ làm hỏng cả plan, có chủ ý.** Plan rỗng (`sessionId: null`) → stage `empty`.

Plan daily có thêm `newWords {requested, issued, withheldReason}` và `reviewWords`. `steps` được giải mã hai lần: một lần thành `[PlanStep]`, một lần để lấy trường phụ (`sourceTopic` theo task id; `knownCheckTaskId` và `skippableTaskIds` theo learn step). Nhờ vậy enum `PlanStep` giữ nguyên. Mọi trường mới đều tùy chọn khi giải mã, và enum lý do lạ giải mã thành `.unknown` (`LenientEnum`), nên backend cũ hay mới đều không làm hỏng plan.

`capabilities` gửi lên khi plan là cam kết thật của thiết bị: `audioPlayback` theo `PracticeAudio.canPlay`, `microphone` theo `VoiceRecorder.canRecord`.

### 15.2. `TaskAttempt`: state thuần của từng task

Mỗi task có một `TaskAttempt` (struct, không phụ thuộc UI) giữ status (`answering`, `wrong`, `solved`, `exhausted`, `revealed`, `recorded`), số lần thử, số gợi ý, tile đang đặt, và danh sách `TaskEvent` đã ghi. Nó thực thi trước những luật mà nếu vi phạm thì backend từ chối **cả commit** với `422`:

- `seq` tăng ngặt trong mỗi task.
- Không có event nào sau một submit đúng.
- Không submit vượt 1 + `maxRetries`.
- Fly Reorder: `submit.tileIds` đúng bằng dãy hiện tại sau khi phát lại tap/remove/move.
- Match: không gửi lại cặp đã đúng; task chỉ kết thúc khi mọi cặp đúng hoặc có `reveal`.
- Task recall đầu tiên trong vòng học mới phải có ít nhất một submit.
- Task known check cũng phải submit trước khi được xem đáp án.
- Tối đa 200 event mỗi task (`endIfOutOfEvents`).
- `deliveryMode` cho prompt audio: `audio` chỉ khi đã phát được thật, ngược lại `fallback`/`none`.

`PracticeSessionStore` chỉ là lớp mỏng: hàm intent (`submitOption`, `submitText`, `tapTile`, `useHint`, `reveal`, `tryAgain`, ...) gọi vào attempt, rồi gắn side effect (haptic, âm thanh, mood của Syllie).

### 15.3. Commit

- Body (`learnStepsCompleted` + `taskResults`) được **encode một lần** và giữ lại, nên mọi lần retry gửi đúng từng byte; backend coi commit lặp cùng body là idempotent.
- Body không chứa các task known check người học đã bỏ qua, các task được bỏ nhờ qua known check, và các learn step của từ đã biết.
- Lỗi `retryable` (mạng, 5xx) → `failed(.commit)`, nút retry gửi lại cùng body.
- `409 SESSION_PAYLOAD_CONFLICT` → gọi `commit-status`; nếu đã commit thì dùng kết quả đã lưu.
- `SESSION_STALE`, `SESSION_EXPIRED`, `SESSION_NOT_OWNED`, `TASK_DATA_INVALID` → `failed(.sessionLost)`, chỉ còn cách plan lại.
- Commit xong: `LearnerStore` làm mới learn-home, Journey, challenges.

### 15.4. Audio và giọng nói

`PracticeAudio` phát prompt audio và clip phát âm; `SpeechProviding` đọc từ bằng giọng thiết bị khi không có audio; `VoiceRecorder` ghi âm và báo mức âm lượng; `OnDeviceSpeechTranscriber` (`SpeechTranscribing`) nhận dạng giọng trên máy cho recording. Prompt audio "mù" (nghe chọn nghĩa, chép chính tả) không bao giờ hiện text để khỏi lộ đáp án.

## 16. Design system và motion

Chi tiết: `docs/DESIGN_SYSTEM.md`.

- **Token** trong `DesignSystem/Tokens/` (Colors, Spacing, Radii, Typography, MotionTokens). Dùng token, không dùng giá trị literal.
- Hai vùng: **vùng bài học** (nút dày, nhấn lún, panel đổi màu đúng/sai) và **vùng sản phẩm** (phẳng, gọn, bình tĩnh).
- **Mọi animation đi qua `MotionCoordinator`** (`@Environment(\.motion)`), tôn trọng cả Reduce Motion của hệ thống lẫn của app: `motion.perform(...)`, `motion.travel(...)`, `motion.stepTransition`. Không gọi `withAnimation` trực tiếp.
- **Haptic** qua `FeedbackProviding` (bọc bởi `SettingsAwareFeedback`).

### Syllie (Rive, `Resources/Animations/syllie.riv`)

| Artboard / state machine | Dùng ở | View |
|---|---|---|
| `Syllie` / `Syllie` (+ layer `Snore`) | Trong task, review preview, review finished | `SyllieView`, `SyllieReactionView` |
| `Syllie` / `LoadingFly`, nested trong `Loading` | Màn chờ | `SyllieLoadingView` |
| `Celebrate` | Màn kết quả | `SyllieCelebrationView` |
| `HomeSyllie` | Home | `HomeSyllieView` / `HomeSyllieScene` |

Mood (`SyllieMood`): `idle`, `happy` và các biến thể (`happyPop`, `happyWiggle`, `happyPuff`, `happyFloat`, `proud`), `oops` và các biến thể (`oopsSquish`, `oopsWobble`, `oopsFreeze`, `oopsSlip`), `thinking`, `deepThought` → `deepThoughtHold`, `sleepy`, `reviewWatch`, `reviewReady`, `reviewToLearn`. `thinking` và `deepThoughtHold` là vòng lặp, còn lại chạy một lần rồi `SyllieReactionView` đưa về idle sau `SyllieMood.reactionDuration`.

Quy tắc khi sửa file Rive: cảnh mới làm trong **artboard mới** (đánh dấu Component để được export), không sửa artboard `Syllie`; mỗi timeline mood mới key đủ tư thế nghỉ ở frame đầu và cuối; giữ nguyên tên artboard, state machine, view model. File trên Rive cloud tên "inky", export ra `inky.riv` rồi lưu thành `Resources/Animations/syllie.riv`.

## 17. Lưu trữ cục bộ

| Dữ liệu | Nơi lưu |
|---|---|
| Access/refresh token | Keychain (`KeychainTokenStore`) |
| Cài đặt app (haptics, motion, ngôn ngữ) | `UserDefaults` qua `AppSettingsStore` |
| Kế hoạch học (scope bản sao, số từ, ngày học, nhắc học), cờ đã onboarding | `UserDefaults` qua `LearningPlanStore` (`PreferencesStoring`) |
| Lịch sử engine demo | `UserDefaults` qua `ProgressStore` |
| Run Match Madness chưa chốt (`PendingRun`), cờ đã xem hướng dẫn | `UserDefaults` qua `ChallengeRunStore` |

Mọi store nhận `UserDefaults` có thể inject hoặc `nil` (in-memory) cho test và preview. Tiến trình học thật chỉ nằm ở backend.

## 18. Localization

- Chuỗi giao diện dùng `LocalizedStringKey`, nằm trong `Resources/Localizable.xcstrings`. Chuỗi quyền truy cập (mic, nhận dạng giọng, notification) ở `Resources/InfoPlist.xcstrings`.
- **Mọi chữ hiển thị không đến từ dữ liệu đều phải localize**: nhãn, nút, tiêu đề, lỗi, accessibility label/hint/value, thông báo VoiceOver, nội dung notification.
- Tham số view nhận `LocalizedStringKey`. Nơi cần `String` (store, error) dùng `String(localized: "…", bundle: .appLanguage)`; thiếu `bundle` sẽ bỏ qua ngôn ngữ đã chọn trong app.
- `Text(verbatim:)` chỉ cho dữ liệu, số, tên thương hiệu.
- **Bắt buộc có bản `vi`** (state `translated`) cho mọi key mới trong cùng thay đổi. Chuỗi nhiều tham số dùng specifier có vị trí (`%1$@`, `%2$lld`).
- Ngôn ngữ áp dụng ngay: `AppRootView` đặt `\.locale` và dựng lại màn hình; formatter ngoài `Text` dùng `AppLanguage.active.locale`.
- Nội dung học (nghĩa, ví dụ, câu hỏi) đến từ backend theo `explanationLocale`, không qua string catalog.

## 19. Accessibility

- Reduce Motion (hệ thống + app) tắt hoặc rút ngắn animation, kể cả cảnh chơi của Syllie.
- Mọi thao tác kéo đều có thao tác chạm thay thế (Fly Reorder: chạm để đặt/bỏ tile).
- Không chỉ dựa vào màu: banner đúng/sai có icon và câu feedback.
- Màn ẩn navigation bar vẫn đặt `navigationTitle` để nút back có tên cho VoiceOver; gợi ý trên Journey cũng được đọc.
- Hộp thoại xác nhận dùng `.alert` có cả nút hủy và nút xác nhận.

## 20. Engine demo cũ

Còn trong code, **không truy cập được từ UI** (Home và My Words dùng session backend):

- **Scored session Learn → Build → Recall → Results:** `Domain/Learning/SessionReducer.swift` là reducer thuần `(SessionState, SessionAction, DemoContent) → SessionTransition`, chứa mọi luật chấm điểm và là đối tượng của test. `SessionStore` bọc reducer, `SessionFlowView` giữ một khung cố định cho mọi step.
- **Nội dung:** `Resources/demo_words.json` (từ, build challenge, recall prompt, motion intro). `DemoContentRepository` decode → validate → xáo đáp án theo `seed`. Nội dung không hợp lệ là `fatalError` lúc khởi động, nên mọi sửa JSON phải giữ validator pass.

## 21. Build và test

```sh
# Build
xcodebuild -project VocabFlow.xcodeproj -scheme VocabFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Toàn bộ test (XCTest)
xcodebuild -project VocabFlow.xcodeproj -scheme VocabFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Một class
xcodebuild ... test -only-testing:VocabFlowTests/SessionReducerTests
```

Test tập trung vào logic thuần và store: `TaskAttemptTests` (luật event), `PlanDecodingTests`, `PracticeSessionStoreTests`, `TranscriptMatcherTests`, `APIClientTests` (refresh/retry), `AccountDeletionTests`, `OnboardingStoreTests`, `PlacementTestStoreTests`, `JourneyTests`, `MatchMadnessEngineTests`, `MatchMadnessBackendParityTests` (fixture sinh từ code backend), `ChallengeRunStoreTests`, `ChallengeBoardSlotsTests`, `CustomWordTests`, `LearnerWordsTests`, `AppLanguageTests`, `SessionReducerTests`, và `ContentValidationTests` / `LabLibraryTests` (nạp đúng file JSON trong bundle).

## 22. Thêm một template mới

Template là một phần của contract backend. Cần sửa đồng thời:

1. Backend: generator/curated item, evaluator, luật event.
2. `TaskTemplate` và decode trong `PracticeTask`.
3. Luật trong `TaskAttempt`.
4. View mới trong `Features/Practice/Tasks/`, đăng ký trong `PracticeTaskView`.
5. Task mẫu trong `Resources/practice_lab.json` (`LabLibrary.validate()` yêu cầu mọi template có mặt).
6. Chuỗi mới trong `Localizable.xcstrings` kèm bản `vi`.
