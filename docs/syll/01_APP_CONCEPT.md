# Syll: App Concept

> **Learn words. Enjoy the process. Remember for longer.**

**Hướng mở rộng đã chốt:** *Vocabulary Learning for Different Needs.*

**Nguyên tắc:** Mở rộng **nội dung từ vựng** theo nhu cầu người học, **không mở rộng phạm vi sản phẩm** thành ứng dụng luyện thi hay dạy tiếng Anh toàn diện.

Tài liệu này là concept sản phẩm. Phần 14 đối chiếu concept với những gì app và backend đang làm. Tính năng cụ thể xem [02_FRONTEND.md](02_FRONTEND.md), backend xem [03_BACKEND.md](03_BACKEND.md).

---

## 1. Tổng quan

**Syll** là ứng dụng học và ghi nhớ từ vựng tiếng Anh qua các **gamified micro-lessons**: ngắn, tương tác mượt, phản hồi tức thì, có hệ thống ôn tập giúp nhớ lâu.

Người dùng **chọn Collection trước, sau đó chọn một hoặc nhiều Topic mình quan tâm và số từ muốn học**. App quyết định **cách giới thiệu, luyện tập và ôn lại** để việc học vừa hiệu quả vừa thú vị.

**Định vị:** *Vocabulary-first app*, **Vocabulary Learning for Different Needs**. Cùng một trải nghiệm học từ vựng cốt lõi, người dùng chọn **Collection** theo nhu cầu (Everyday, Business, IELTS Vocabulary, TOEIC Vocabulary...) rồi chọn **Topic** bên trong (Health, Travel, Meetings, Environment...).

Syll **không phải** ứng dụng dạy ngoại ngữ toàn diện, luyện đề hay luyện thi chuyên sâu. Với người học IELTS/TOEIC, Syll chỉ giải quyết **một phần nhu cầu: học và ghi nhớ từ vựng liên quan**, không hứa hẹn điểm số hay lộ trình nâng band/score.

Syll đứng trong nhóm app học từ vựng, lấy Duolingo và Brilliant làm chuẩn cảm hứng về UX (nguyên tắc, không sao chép). Điều Syll muốn kiểm chứng là **trải nghiệm luyện từ vừa thú vị vừa giúp nhớ lâu**, không phải số lượng exam track.

**Mascot:** Syllie, một nhân vật Rive đi cùng người học: suy nghĩ khi họ đang trả lời, vui khi đúng, "oops" khi sai, ngủ gật trên Home khi không ai chạm vào. Syllie là lớp cảm xúc, không bao giờ thay đổi kết quả học.

## 2. Đối tượng

- **Ban đầu:** Gen Z đã biết tiếng Anh, muốn mở rộng vốn từ phục vụ học tập, công việc hoặc nhu cầu cá nhân; gồm cả người muốn bổ sung từ vựng IELTS/TOEIC nhưng **không tìm một ứng dụng luyện thi đầy đủ**.
- **Mở rộng:** Người mới bắt đầu vẫn học được nhờ nội dung theo trình độ, nghĩa tiếng Việt và mức gợi ý phù hợp; về sau có thể phục vụ các nhóm từ chuyên ngành.
- **Ngữ cảnh sử dụng:** Ăn sáng, nghỉ trưa, giải lao ngắn; phải đủ nhẹ để dùng sau một ngày học/làm việc mệt mỏi.
- **Không phải đối tượng chính:** Người muốn luyện full test, được chấm Writing/Speaking, học chiến thuật làm bài, có lộ trình bảo đảm điểm thi, hoặc thay thế khóa học IELTS/TOEIC.

## 3. Phạm vi nội dung và Information Architecture

### 3.1. Một core experience, nhiều Collection

**Collection** là lớp nội dung cao nhất mà người dùng **chọn trước**. Mỗi Collection là một tập từ được biên soạn cho một nhu cầu học cụ thể, không đơn thuần là một tag hay mức độ khó.

| Collection (ví dụ) | Loại từ vựng đặc trưng | Không đồng nghĩa với |
|---|---|---|
| **Everyday English** | Từ/cụm từ thông dụng trong đời sống | Khóa giao tiếp toàn diện |
| **Business Vocabulary** | Từ/cụm từ trong môi trường công việc | Khóa Business English tổng quát |
| **IELTS Vocabulary** | Từ/cụm từ hữu ích trong ngữ cảnh IELTS | IELTS Preparation, luyện đề, nâng band |
| **TOEIC Vocabulary** | Từ/cụm từ hữu ích trong ngữ cảnh TOEIC | TOEIC Preparation, luyện đề, nâng điểm |
| **Academic Vocabulary** *(có thể mở rộng)* | Từ học thuật và cách dùng trong học tập | Dạy viết học thuật toàn diện |
| **My Vocabulary / Custom** | Từ do người dùng tự thêm | Lộ trình do app áp đặt |

IELTS/TOEIC không nhất thiết chỉ gồm từ *khó hơn*: khác biệt nằm ở **tính hữu ích, ngữ cảnh và tiêu chí biên soạn**. Chọn Collection **chỉ thay đổi nội dung**, không kích hoạt learning mode, cơ chế practice, thuật toán ôn tập hay bộ tính năng luyện thi riêng.

### 3.2. Hệ phân cấp: Collection → Topic → Vocabulary

1. **Collection: học loại từ nào?** Chọn **một Collection** để bắt đầu.
2. **Topic: học về lĩnh vực gì?** Chọn **một hoặc nhiều Topic** thuộc Collection đó. **Không mặc định bắt học toàn bộ Topic**.
3. **Vocabulary: học từ nào?** App lấy tập từ **đã biên soạn cho chính tổ hợp Collection + Topic**, đưa vào các run ngắn.
4. **Core Engine: học như thế nào?** Mọi tổ hợp dùng chung **Learn → Interact → Recall → Review** và spaced repetition.

```text
Choose Collection (chọn 1)
    ↓
Choose Topics in Collection (chọn ≥1)
    ↓
Curated Vocabulary Pool (hợp các topic đã chọn, bỏ trùng)
    ↓
Shared Gamified Learning Engine
    ↓
Mastery & Spaced Repetition
```

**Cùng tên Topic nhưng khác Collection ≠ cùng bộ từ.** Ví dụ minh họa (chưa phải danh sách đã kiểm chứng):

| Tổ hợp | Ví dụ từ/cụm từ |
|---|---|
| Everyday → Health | headache, symptom, appointment |
| IELTS Vocabulary → Health | sedentary, prevalence, well-being |
| TOEIC Vocabulary → Health | sick leave, insurance coverage, reimbursement |
| Business → Finance | budget allocation, revenue, cash flow |

Topic mang tính ngữ nghĩa có thể tái sử dụng giữa các Collection, nhưng **danh sách từ được curated riêng**. Một từ vẫn có thể nằm trong nhiều tổ hợp nếu phù hợp.

### 3.3. Quy tắc nội dung và dữ liệu

- **Collection:** có id, tên, mô tả nhu cầu, trạng thái hiển thị, danh sách Topic khả dụng.
- **Topic:** id/slug nhất quán (`health`, `travel`); có thể xuất hiện trong nhiều Collection. Tên Topic không tự quyết định bộ từ.
- **Membership Collection–Topic–Meaning:** quan hệ biên soạn, là **nguồn xác định từ nào thuộc bộ nào**, không phải bộ lọc tự động theo tag. Có thể lưu thứ tự ưu tiên và ví dụ phù hợp.
- **Vocabulary entry:** dữ liệu dùng chung cho từ/cụm từ: loại từ, nghĩa, phát âm, ví dụ, collocation. Cùng mặt chữ nhiều nghĩa thì tách ở cấp **meaning/sense**, không gộp.
- **Tags/metadata:** IELTS, TOEIC, CEFR, chủ đề... hỗ trợ lọc và biên tập, **không thay thế** quan hệ curated.
- **Mastery:** theo dõi trên **từ + nghĩa đã học**, dùng lại ở mọi Collection/Topic khi cùng nghĩa. Nghĩa khác thì không tự đánh dấu đã thành thạo.
- **Deduplication:** một từ thuộc nhiều Topic đã chọn không hiện lặp trong cùng run; không tạo nhiều lịch ôn cho cùng một nghĩa.
- **Context:** ví dụ có thể chọn theo Collection/Topic; mechanics và quy trình học không đổi.

### 3.4. Ranh giới sản phẩm

**Syll làm:** cho người dùng chọn Collection và Topic, giới thiệu từ/nghĩa/cách dùng, luyện nhận diện và truy xuất, ôn theo khả năng ghi nhớ, theo dõi tiến trình từ vựng, cho tự thêm từ mình gặp.

**Syll không làm:** full IELTS/TOEIC mock test, chấm Writing/Speaking, dạy chiến thuật làm bài, huấn luyện đủ bốn kỹ năng như một khóa học, dự đoán hoặc cam kết band/score.

**Quy tắc thêm Collection:** chỉ thêm khi có **bộ từ đặc thù, đủ chất lượng và có Topic hữu ích**; không xây tính năng học riêng cho Collection đó. Không dùng nhãn *IELTS Preparation* hay *TOEIC 900 Roadmap*.

## 4. Giá trị cốt lõi

1. **Engaging practice:** luyện nhớ từ phải thú vị, không như làm bài tập.
2. **Long-term retention:** đo khả năng thực sự nhớ và dùng từ sau nhiều ngày, không chỉ số từ đã xem.
3. **User control:** chọn Collection, chọn Topic, số từ mỗi lượt và nhịp học; đổi được về sau.
4. **Low-friction learning:** bài 2–5 phút, không hướng dẫn dài, không bắt đoán từ chưa học.
5. **Scalable content:** tái sử dụng interaction engine, typography, motion, âm thanh và dữ liệu trên mọi nhóm nội dung; **không làm asset riêng cho từng từ hay mode riêng cho từng kỳ thi**.

## 5. Core learning loop

**Choose → Learn → Interact → Recall → Return**

- **Choose:** Collection → một hoặc nhiều Topic → số từ mỗi lượt. Chọn IELTS/TOEIC không bật hệ học khác.
- **Learn:** giới thiệu ngắn từ, nghĩa, cách dùng, ví dụ; cung cấp dữ kiện trước khi đòi tương tác.
- **Interact:** luyện qua thao tác trực quan, có mục tiêu, motion mượt, feedback tức thì.
- **Recall:** gợi ý giảm dần; người học tự nhớ lại từ, không chỉ nhận diện đáp án.
- **Return:** active recall và spaced repetition đưa từ trở lại theo kết quả; có thể đổi ngữ cảnh để kiểm tra khả năng vận dụng.

**Cấu trúc micro-lesson:** một lượt **3–5 từ mới, khoảng 2–5 phút**: tiếp nhận nhanh → luyện có hướng dẫn → thử thách nhớ lại → phản hồi và kết thúc. Thời lượng là giả thuyết cần thử nghiệm.

## 6. Gamified Practice

**Product bet:** người dùng mở app vì *muốn chơi thêm một lượt*, và sau mỗi lượt họ thực sự nhớ thêm từ. Đây là trải nghiệm trung tâm, **không phải danh sách câu hỏi có thêm XP**.

### 6.1. Core practice loop

**Enter → Act → Instant Feedback → Build Momentum → Recall → Micro-victory → Next Run**

1. **Enter (0–2 s):** vào thử thách ngay, không đọc hướng dẫn; thao tác được dạy qua lần dùng đầu.
2. **Act (vài giây/lượt):** chạm, kéo, sắp xếp, sửa hoặc tái tạo từ/nghĩa. Mỗi lượt có mục tiêu rõ.
3. **Instant Feedback:** đúng/sai và lý do *ngay trên đối tượng vừa thao tác*; không chuyển sang trang giải thích.
4. **Build Momentum:** chuỗi lượt ngắn, nhịp tăng dần; xen từ mới với từ cũ đến hạn ôn.
5. **Recall:** bỏ word bank, giảm gợi ý ở lượt sau; tự khôi phục từ từ trí nhớ ít nhất một lần.
6. **Micro-victory:** kết thúc trong 2–5 phút với cảm giác trọn vẹn; chơi tiếp hoặc dừng thoải mái.

### 6.2. Practice mechanic

Concept ban đầu đề xuất bốn hướng để prototype:

| Mechanic | Trải nghiệm | Learning goal | Rủi ro |
|---|---|---|---|
| **Word Stack / Build** | Mảnh từ/nghĩa snap vào nhau thành cấu trúc có nghĩa | Liên kết word–meaning, collocation | Chỉ là kéo thả ghép đáp án |
| **Word Reveal** | Gợi ý mở dần theo hành động | Retrieval với hỗ trợ thích nghi | Thành đoán mò nếu chưa học |
| **Word Orbit / Connect** | Từ, sắc thái, collocation thành nút; người dùng nối mạng lưới | Phân biệt, tổ chức kiến thức | Kết nối mơ hồ |
| **Memory Rush** | Thử thách nhớ nhanh, có combo; có chế độ không tính giờ | Recall lặp lại, trôi chảy | Đua tốc độ khiến đoán thay vì nhớ |

Bản đang chạy dùng **bảy template bài tập** dùng chung cho mọi Collection (chi tiết ở [02_FRONTEND.md §5](02_FRONTEND.md)):

| Template | Thao tác | Kỹ năng chính |
|---|---|---|
| Select | Chọn nghĩa / chọn từ, có biến thể nghe | Reading, Listening |
| Cloze Select | Chọn từ điền vào chỗ trống trong câu | Reading |
| Typing | Gõ từ từ nghĩa, hoặc chép chính tả | Writing, Listening |
| Fly Reorder | Xếp các chữ cái bay thành từ | Writing |
| Match | Nối cặp từ – nghĩa | (luyện, bằng chứng yếu) |
| Surgery | Sửa lỗi chính tả trong từ | Writing |
| Recording | Đọc to và được chấm phát âm | Speaking |

**Nguyên tắc chọn mechanic:** bỏ XP, animation và phần thưởng đi mà thao tác vẫn hấp dẫn và có tác dụng học. Đây là hướng thử nghiệm, **không tuyên bố đã phát minh gameplay khác biệt**.

### 6.3. Animation, motion và feedback

- **Direct manipulation:** đối tượng phản ứng ngay khi chạm/kéo.
- **Micro-animation:** scale, snap, morph, chuyển trạng thái ngắn. Không dùng animation dài chặn luồng học.
- **Positive feedback:** đúng → xác nhận tức thì, âm thanh/haptic nhẹ, Syllie vui.
- **Error recovery:** sai → giải thích ngắn tại chỗ, cho thử lại; không trừng phạt nặng vì lỗi học.
- **Flow transitions:** lượt này nối tự nhiên sang lượt sau; tăng thử thách, không tăng độ phức tạp UI.
- **Accessibility:** tắt được âm thanh/chuyển động (app có Reduce Motion riêng ngoài cài đặt hệ thống), không chỉ dựa vào màu, luôn có thao tác chạm thay cho kéo phức tạp.

### 6.4. Gamification nên và không nên

- **Nên:** combo dựa trên recall thật, tiến trình nhìn thấy được (Journey), micro-victory, thử thách hoàn thành nhanh, lựa chọn chơi thêm, độ khó tự điều chỉnh.
- **Không nên:** XP thay cho kết quả học; timer bắt buộc gây căng thẳng; daily chore hay notification ép ôn; game độc lập không cần biết từ; lặp cùng một multiple-choice trong vỏ khác.
- **Nguyên tắc:** người mới vẫn thao tác được. Từ chưa biết phải được *giới thiệu nghĩa và cách dùng* trước khi bị hỏi lại.

### 6.5. Kiểm chứng practice là gameplay hay bài tập

Đo riêng **mức muốn chơi tiếp** ngay sau một lượt, số lượt người dùng tự mở thêm (không thưởng), mức vui và mức mệt. Song song đo **unaided recall** ngay sau học và sau 7 ngày, so với flashcard cùng thời lượng/lịch ôn. Vui hơn nhưng nhớ kém hơn, hoặc nhớ tốt mà không ai muốn chơi tiếp, đều là chưa đạt.

**Tiêu chuẩn thiết kế:** *Practice should feel like play, but be measured like learning.*

## 7. Learning effectiveness: nguyên tắc bắt buộc

- Mục tiêu: hiệu quả ghi nhớ **ít nhất ngang flashcard ở cùng thời lượng và lịch ôn**, phải kiểm chứng bằng thử nghiệm.
- Không bắt người mới đoán khi chưa có dữ kiện; hỗ trợ theo trình độ.
- Phân biệt **nhận ra từ**, **tự nhớ lại từ** và **dùng đúng trong ngữ cảnh**. Backend tách rõ: chọn đúng đáp án (recognition) không được tính như tự nhớ (recall); câu trả lời có gợi ý, thử lại, hoặc đáp án vừa xuất hiện ngay trước đó (primed) đều bị hạ giá trị bằng chứng.
- Kết nối cá nhân giúp học dễ hơn **khi thực sự phù hợp**, nhưng không phải điều kiện để học từ xa lạ.
- Spaced repetition đưa cả từ ít gặp ngoài đời quay lại đúng lúc; gặp lại thụ động không được coi là bằng chứng nhớ lâu.
- Tiến bộ từ vựng **không** được diễn giải thành dự đoán điểm IELTS/TOEIC.

## 8. Onboarding: Collection trước, Topic sau

### 8.1. Flow concept

**Welcome → Choose Collection → Choose Topics → First Learning Run → Micro-victory → Home**

| Bước | Người dùng làm gì | Yêu cầu UX |
|---|---|---|
| **Welcome** | Hiểu nhanh app giúp học và nhớ từ | Một màn ngắn; không tour, không giải thích SRS |
| **Choose Collection** | Chọn **1 Collection** | Mô tả ngắn loại từ của từng Collection |
| **Choose Topics** | Chọn **≥1 Topic** trong Collection vừa chọn | Multi-select; không bắt chọn hết; nói rõ đổi được sau |
| **First Learning Run** | Học 3–5 từ | Cùng core mechanics; hướng dẫn thao tác ngay trong run |
| **Micro-victory** | Xem từ vừa học, kết quả tự nhớ lại | Không nhầm số từ đã xem với số từ nhớ được |
| **Home** | Học tiếp, ôn tập, khám phá | Hiện Collection và Topic đang học |

Chọn Collection và Topic là **hai quyết định nội dung bắt buộc, theo thứ tự**. Không hỏi band IELTS, điểm TOEIC, ngày thi, target score; không bắt làm bài xếp lớp. Số từ mỗi lượt có mặc định (5) và chỉnh được.

### 8.2. Quy tắc tương tác

- **Một active Collection tại một thời điểm.** Đổi Collection không xóa tiến trình đã lưu.
- **Nhiều Topic trong active Collection;** không auto-select tất cả. Một Topic là đủ.
- **Back/Edit:** đổi Collection thì danh sách Topic đổi theo; Topic đã chọn trước đó không bị áp sai sang Collection khác.
- **Content pool:** hợp các từ thuộc Topic đã chọn; ưu tiên từ chưa học; không lặp trong cùng run.
- **Thiếu nội dung:** ít từ hơn số yêu cầu thì dùng số thực có và giải thích ngắn; Topic trống thì ẩn hoặc đánh dấu *Coming soon*.
- **Đăng ký và thông báo:** quyền notification chỉ xin khi đã có giá trị rõ (khi bật nhắc học), không phải điều kiện vào app.
- **First-time learning:** giới thiệu nghĩa/cách dùng trước khi bắt tự nhớ; first run không phải tutorial quiz.

### 8.3. Kết quả mong muốn

Người học hiểu ba điều: **(1) mình chọn loại từ vựng muốn học, (2) mình chỉ học Topic mình quan tâm, (3) mình học và ôn qua một trải nghiệm thú vị.**

## 9. Home, Explore và quản lý nội dung

- **Home / Today:** bài học hôm nay (số từ cần ôn, số từ mới mỗi lượt) và thẻ **Challenge**.
- **Challenge Map:** con đường gồm các chương, mỗi chương 3 level **Match Madness** (nối từ – nghĩa đua giờ, có combo và tối đa 3 sao). Chương mới mở khi chương trước đã qua và đã học đủ từ mới trong Daily. Challenge là phần chơi thêm: không đổi lịch ôn, không chặn Daily, sao là thành tích chứ không phải bài kiểm tra.
- **Edit Topics:** thêm/bớt Topic bất kỳ lúc nào. Bỏ Topic chỉ đổi **nguồn từ mới**, không xóa từ đã học hay lịch ôn.
- **Switch Collection:** chọn Collection khác rồi chọn Topic của nó; không reset mechanic, mastery hay lịch ôn.
- **Review:** tiến trình theo nghĩa là dùng chung; từ của Collection khác vẫn có thể đến hạn ôn.
- **My Words:** thư viện từ đã học, trạng thái từng kỹ năng của từng nghĩa, luyện tự chọn theo kỹ năng, luyện từ yếu, tự thêm từ.
- **Content labels:** dùng tên đúng phạm vi, như *IELTS Vocabulary: Health*, không tạo kỳ vọng luyện thi.

**UX principle:** *Choose your Collection → Pick your Topics → Enjoy the same great practice → Remember the words.*

## 10. Bốn kỹ năng trên mỗi nghĩa

Syll không dạy bốn kỹ năng như một khóa học, nhưng theo dõi **người học dùng được một nghĩa theo những cách nào**:

| Kỹ năng | Bằng chứng đến từ |
|---|---|
| Reading | Chọn nghĩa của từ (text), chọn từ cho nghĩa, điền chỗ trống |
| Writing | Gõ từ, xếp chữ, sửa chính tả |
| Listening | Nghe rồi chọn nghĩa, nghe rồi chép (chỉ khi từ có audio) |
| Speaking | Đọc to và được chấm |

Một kỹ năng **verified** khi người học tự làm đúng ở ít nhất 2 buổi khác nhau cách nhau ít nhất 24 giờ. Sai hoặc phải xem đáp án thì mất verified và kỹ năng được đánh dấu "cần luyện lại"; đúng nhờ gợi ý thì giữ verified nhưng ghi "gần đây cần trợ giúp". Đây là thông tin cho người học tự chọn luyện, không phải điểm số.

## 11. MVP

- Khoảng **100 từ/cụm từ biên soạn kỹ** làm baseline. **Chỉ hiện Collection/Topic đã đủ nội dung.**
- **Ít nhất 2 Collection** có tính chất từ vựng khác nhau, mỗi Collection **2–3 Topic thật sự chọn được**. Ưu tiên Everyday và Business; IELTS/TOEIC thêm khi có nội dung curated đủ chất lượng.
- **Onboarding:** chọn 1 Collection → chọn ≥1 Topic → nhịp học → Home; đổi Topic và Collection về sau.
- **Data:** membership Collection–Topic–Meaning, vocabulary entry dùng chung, bỏ trùng, giữ mastery khi đổi Collection.
- **Micro-lesson 3–5 từ**, đầu tư vào motion, feedback và usability.
- **Active recall + spaced repetition**, thống kê từ đã giới thiệu, đã tự nhớ được và đến hạn ôn; **không dự đoán band/score**.
- Chưa cần: AI chatbot, thế giới game, cốt truyện, asset riêng cho từng từ, curriculum thích nghi theo mục tiêu thi, luyện đề.

**Thứ tự ưu tiên:** validate core gameplay và hiệu quả ghi nhớ **cùng lúc** với việc người dùng chọn đúng Collection/Topic; không mở nhiều Collection rỗng hoặc nông.

## 12. Validation

So sánh với flashcard tiêu chuẩn trên bộ từ tương đương, cùng thời lượng và lịch ôn.

| Khía cạnh | Câu hỏi |
|---|---|
| **Immediate recall** | Tự nhớ được bao nhiêu từ ngay sau học? |
| **7-day retention** | Sau 7 ngày còn tự nhớ được bao nhiêu? |
| **Learning efficiency** | Số từ nhớ được mỗi phút có ít nhất ngang flashcard? |
| **Enjoyment & voluntary continuation** | Có thú vị không; có tự chơi thêm run không? |
| **Collection clarity** | Có hiểu vì sao chọn Collection trước, phân biệt được IELTS/TOEIC/Everyday/Business? |
| **Topic relevance** | Chọn đúng Topic quan tâm, không nghĩ phải học hết? |
| **Onboarding funnel** | Tỷ lệ chọn Collection → chọn Topic → bắt đầu run → hoàn thành run? |
| **Cross-collection continuity** | Từ/nghĩa trùng có giữ đúng tiến trình khi đổi Collection? |
| **Content scalability** | Cùng mechanics áp dụng được cho Collection/Topic khác mà không cần gameplay mới? |

Số liệu backend có sẵn để đo: kết quả từng task (`raw_events`, `result`), tín hiệu nhớ (`memory_observations`), lịch ôn (`user_meaning_progress`), kết quả Tổng ôn (`unaidedRecalledCount`). **Không đo bằng** band IELTS hay điểm TOEIC.

## 13. Rủi ro chưa giải quyết

**Rủi ro số 1 vẫn là core interaction chưa được validate.** Nếu practice chỉ là quiz truyền thống đổi hình thức, thêm Collection/Topic cũng không tạo khác biệt bền vững.

- **Collection chỉ là tên gọi khác:** từ ở IELTS, TOEIC, Everyday gần giống nhau thì người dùng không thấy lý do chọn Collection.
- **Topic quá rộng hoặc quá nhiều:** cần curation, nhóm rõ, multi-select nhanh, không ép chọn hết.
- **Content quá mỏng:** 100 từ chia cho quá nhiều nhánh tạo màn trống hoặc run lặp. Giới hạn số nhánh phát hành.
- **Sai lệch data/mastery:** trùng từ giữa Topic/Collection gây lặp, reset tiến độ, hoặc gộp nhầm nghĩa. Cần membership, mastery theo nghĩa, dedup.
- **Loãng định vị:** người dùng tưởng IELTS/TOEIC collection là app luyện thi. Dùng wording đúng phạm vi.
- **Mở rộng nội dung trước khi validate gameplay.**
- **Nội dung do AI tạo** (từ người dùng tự thêm): có thể sai. Nội dung này chưa qua biên tập, không vào catalog hay làm đáp án nhiễu, và chờ admin duyệt; người dùng chưa báo sai được (xem [03_BACKEND.md §9](03_BACKEND.md)).

## 14. Concept và hiện trạng triển khai

| Concept | Hiện trạng (11/2026) |
|---|---|
| Collection → Topic → Vocabulary | Đã có. Người dùng có một scope: 1 Collection + 1–100 Topic. Seed demo có 4 collection |
| Mastery theo nghĩa, dùng chung giữa Collection | Đã có: tiến trình lưu theo Meaning, không theo Topic |
| Onboarding không hỏi trình độ | **Khác:** onboarding có bước chọn level CEFR (A1–C2) và một bài test xếp level *tùy chọn*. Level chỉ dùng để sắp thứ tự từ mới, không loại từ nào |
| Không bắt đăng ký trước run đầu | **Khác:** cần đăng nhập (email, Apple, Google) trước, vì session, chấm điểm và tiến trình đều ở backend. Chưa có guest mode |
| First Learning Run trong onboarding | **Khác:** onboarding kết thúc ở bước Ready rồi về Home; lượt học đầu bắt đầu từ Home |
| Số từ/run chỉnh trước khi học | Onboarding có bước Routine: số từ mới mỗi buổi (1–30), ngày học trong tuần, nhắc học |
| Micro-victory | Màn kết quả với Syllie ăn mừng và confetti |
| Spaced repetition | Đã có, theo nghĩa; Daily ôn trước rồi mới học mới |
| My Vocabulary / Custom (mở rộng sau) | **Đã có sớm:** người dùng tự thêm từ, AI tạo nội dung nếu kho chưa có |
| Challenge Map / Match Madness | **Thêm ngoài concept**, thay cho Journey / Tổng ôn: chương 3 level nối cặp đua giờ, sao và điểm do server chấm; tách khỏi Daily và SRS |
| Bốn mechanic để prototype | Thay bằng 7 template của backend. Bản demo Learn → Build → Recall cũ vẫn còn trong code nhưng không truy cập được từ UI |
| Ngôn ngữ giao diện | Tiếng Anh và tiếng Việt, chọn sau lần đăng nhập đầu và đổi trong Settings |

## 15. Product thesis

**Syll giúp người dùng học và ghi nhớ từ vựng phù hợp với nhu cầu của họ: chọn một Collection (Everyday, Business, IELTS Vocabulary, TOEIC Vocabulary...), chọn một hoặc nhiều Topic quan tâm, rồi học bằng cùng một trải nghiệm gamified micro-lessons, active recall và spaced repetition. App tập trung làm cho việc học từ mới thú vị hơn và nhớ lâu hơn, không trở thành ứng dụng luyện thi hay dạy tiếng Anh toàn diện.**

**Short positioning:** *Vocabulary Learning for Different Needs.*

**Product promise:** *Learn words. Enjoy the process. Remember for longer.*
