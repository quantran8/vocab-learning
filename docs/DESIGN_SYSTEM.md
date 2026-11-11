# VocabFlow Design System

Tài liệu thiết kế của VocabFlow, app iOS học từ vựng tiếng Anh cho người Việt.

---

## 1. Định hướng thiết kế

VocabFlow lấy cảm hứng mạnh từ **Brilliant** và **Duolingo**, nhưng mỗi app ảnh hưởng tới một vùng khác nhau:

| Vùng | Phạm vi | Cảm hứng | Cảm giác cần đạt |
|---|---|---|---|
| **Vùng bài học** | Bên trong bài học | Brilliant + Duolingo | Tập trung như đang giải bài, đã tay như đang chơi |
| **Vùng sản phẩm** | Mọi thứ ngoài bài học | Brilliant | Bình tĩnh, gọn, rõ ràng, người lớn |

Đây là cảm hứng về nguyên tắc, không phải sao chép. Không dùng lại logo, mascot, minh họa, âm thanh, màu thương hiệu hay bố cục nguyên bản của hai app này.

### Mỗi app đóng góp gì

| | Lấy từ Brilliant | Lấy từ Duolingo |
|---|---|---|
| **Vai trò** | Cấu trúc và tư duy | Nhịp điệu và phản hồi |
| **Bố cục** | Canvas sạch, một ý trên một màn hình, nhiều khoảng trắng | Thanh tiến độ trên cùng, nút hành động ghim dưới đáy |
| **Tương tác** | Học bằng cách làm: thao tác trực tiếp lên nội dung | Thẻ từ có độ dày, nhấn lún xuống, đáp lại ngay |
| **Phản hồi** | Giải thích ngắn sau khi trả lời, sai là một phần của việc học | Panel đổi màu theo đúng/sai, kèm âm thanh và rung |
| **Động lực** | Niềm vui khi hiểu ra | Khoảnh khắc ăn mừng cuối bài |

### Không làm

Những thứ sau không thuộc design system. Chỉ thêm khi có quyết định sản phẩm riêng:

- Mascot hoặc nhân vật.
- Mạng/tim, giải đấu, bảng xếp hạng, tiền ảo.
- Màu rực và trang trí ăn mừng ở vùng sản phẩm.
- Phản hồi chỉ để trang trí, không gắn với hành động của người học.

---

## 2. Ranh giới hai vùng

Quy tắc phân vùng: **màn hình đang yêu cầu người học trả lời, hoặc đang kết thúc phần trả lời đó, thì thuộc vùng bài học.** Còn lại thuộc vùng sản phẩm.

| Vùng bài học | Vùng sản phẩm |
|---|---|
| 7 dạng bài tập | Home |
| Xem lại từ trước khi học | My Words |
| Giới thiệu từ mới | Profile, Settings |
| Kết quả cuối phiên | Thêm và sửa từ |
| Bài tập trong Practice Lab | Đăng nhập, onboarding, sửa kế hoạch học |
| | Danh sách Practice Lab |
| | Màn hình chờ và báo lỗi của phiên học |

---

## 3. Nguyên tắc chung

Áp dụng cho cả hai vùng.

1. **Bản sắc đến từ độ đậm của chữ**, không từ font riêng. Dùng San Francisco của hệ thống.
2. **Mỗi màu có một nghĩa.** Xanh dương là tương tác. Xanh lá và cam đỏ chỉ nói đúng/sai. Vàng chỉ dành cho thành tựu.
3. **Không truyền thông tin chỉ bằng màu.** Trạng thái đúng/sai luôn đi kèm icon, chữ hoặc viền.
4. **Vùng chạm tối thiểu 44pt.**
5. **Thiết kế cho cỡ chữ thay đổi.** Bố cục phải chịu được Dynamic Type lớn. Chỉ hình minh họa và icon trong khung cố định mới giữ cỡ cố định.
6. **Thiết kế cho hai ngôn ngữ.** Giao diện có tiếng Anh và tiếng Việt, nên chừa chỗ cho nhãn dài ở cả hai.
7. **Luôn có phương án giảm chuyển động.** Mọi chuyển động phải có phiên bản nhẹ khi người dùng bật Reduce Motion.
8. **Hộp thoại xác nhận luôn hiện cả nút hủy và nút xác nhận.**
9. **Chỉ có giao diện sáng.**

---

## 4. Nền tảng thị giác

### 4.1 Màu

**Màu lõi**

| Tên | Hex | Dùng cho |
|---|---|---|
| Canvas, Surface | `#FFFFFF` | Nền màn hình, nền card |
| Ink | `#171717` | Chữ chính |
| Muted Ink | `#5C606B` | Chữ phụ |
| Primary Action | `#303030` | Mặt nút chính |
| Interactive | `#4775F5` | Tiến độ, lựa chọn, tab đang chọn, dấu câu thương hiệu |
| Reward | `#FFD23F` | Khoảnh khắc thành tựu |
| Success | `#2BC86A` | Icon và viền khi đúng |
| Error | `#FF795D` | Icon và viền khi sai |
| Neutral Surface | `#F5F5F5` | Ô tìm kiếm, nút tròn, chip |
| Quiet Surface | `#FAFAFA` | Nền rất nhẹ |
| Stroke, Track | `#E1E4EB` | Viền, rãnh thanh tiến độ |

**Màu trạng thái**

| Trạng thái | Nền | Chữ | Viền | Cạnh dày |
|---|---|---|---|---|
| Đã chọn | `#EAF0FF` | `#234EAE` | `#4775F5` | `#B2C5F5` |
| Đúng | `#E5FAED` | `#12673A` | `#2BC86A` | `#9EE5B8` |
| Sai | `#FFF0EA` | `#943727` | `#FF795D` | `#FFB5A5` |
| Vô hiệu | `#F1F2F4` | `#707783` | | |

**Cạnh dày của bề mặt nổi**

| Bề mặt | Hex |
|---|---|
| Nút chính | `#080808` |
| Thẻ từ, nút phụ | `#CDD2DC` |
| Bề mặt xanh | `#2B55CE` |
| Bề mặt vàng | `#B89528` |

**Màu phụ trợ:** viền focus `#4775F5`, ô đích khi đang kéo từ vào `#D9E4FF`.

### 4.2 Chữ

Font San Francisco. Cỡ chữ theo text style của iOS, cột pt là cỡ mặc định.

| Vai trò | Text style | pt | Độ đậm | Dùng cho |
|---|---|---|---|---|
| Display | Large Title | 34 | Heavy | Tiêu đề lớn, kết quả |
| Prompt | Title 1 | 28 | Heavy | Từ hoặc câu cần xử lý trong bài tập |
| Screen Title | Title 2 | 22 | Bold | Tiêu đề màn hình, section, câu hỏi |
| Sentence | Title 2 | 22 | Bold | Câu trong bài tập |
| Choice | Title 2 | 22 | Regular | Đáp án trong dạng Chọn đáp án và Nối cặp |
| Wordmark | Title 3 | 20 | Heavy | Tên thương hiệu |
| Tile Large | Title 3 | 20 | Semibold | Chữ trên thẻ từ lớn |
| Action | Headline | 17 | Bold | Nhãn nút |
| Emphasis | Body | 17 | Bold | Nhấn mạnh, tiêu đề phản hồi |
| Tile | Body | 17 | Semibold | Chữ trên thẻ từ |
| Body | Body | 17 | Regular | Nội dung |
| Secondary | Subheadline | 15 | Regular | Chữ phụ |
| Eyebrow | Caption | 12 | Bold | Nhãn in hoa, giãn chữ 1.2 |
| Micro | Caption | 12 | Regular | Chú thích |

Tiêu đề dùng giãn chữ âm: -0.6 cho tiêu đề thường, khoảng -1.2 cho Display.

### 4.3 Khoảng cách

Thang: **4 · 8 · 12 · 16 · 24 · 32**.

| Thông số | pt |
|---|---|
| Lề ngang màn hình | 20 |
| Vùng chạm tối thiểu | 44 |
| Chiều cao tối thiểu của thẻ từ | 60 |
| Chiều rộng tối thiểu của ô trống trong câu | 132 |

### 4.4 Bo góc

Dùng bo góc liên tục (continuous corner).

| Thành phần | pt |
|---|---|
| Chip | 10 |
| Thẻ từ, ô nhập | 14 |
| Nút | 16 |
| Card, panel phản hồi | 20 |
| Khối hero | 24 |

Chip chọn chủ đề và thanh tiến độ bo tròn hoàn toàn.

### 4.5 Độ sâu

Hệ thống không dùng shadow để tạo chiều sâu, mà dùng **cạnh dày**: một lớp màu đậm hơn nằm ngay dưới bề mặt, khi nhấn thì bề mặt lún xuống lớp đó.

| Bề mặt | Độ dày |
|---|---|
| Nút chính ở vùng bài học | 4pt |
| Nút phụ, nút hủy ở vùng bài học | 2pt |
| Nút ở vùng sản phẩm | Không có |
| Thẻ từ | 3pt |
| Card | Không có, chỉ viền 1.5pt |

Shadow mềm chỉ xuất hiện trên vật thể đang được nhấc lên, như thẻ từ đang kéo.

### 4.6 Icon

Dùng SF Symbols, nét đậm vừa, luôn đi kèm nhãn hoặc mô tả cho VoiceOver.

---

## 5. Thành phần giao diện

### Nút

| Loại | Giao diện |
|---|---|
| Chính | Mặt `#303030`, chữ trắng, cạnh dày 4pt, full width |
| Phụ | Mặt trắng, viền 1.5pt, chữ Ink, cạnh dày 2pt |
| Hủy/xóa | Nền cam nhạt, chữ đỏ đậm, cạnh dày 2pt |
| Vô hiệu | Nền và chữ xám, không có cạnh dày; có thể kèm một dòng giải thích điều kiện phía trên |

Độ dày của nút là tín hiệu riêng của lúc đang học:

- **Vùng bài học:** nút có cạnh dày, khi nhấn mặt nút lún xuống gần chạm đáy cạnh dày.
- **Vùng sản phẩm:** nút phẳng, cùng màu nhưng không có cạnh dày, khi nhấn thu nhỏ còn 97%.
- **Ngoại lệ:** nút vào bài học hằng ngày ở Home giữ cạnh dày, như một lời mời vào vùng bài học.

### Thẻ từ

Thành phần trung tâm của bài học. Cao tối thiểu 60pt, chữ căn giữa, cạnh dày 3pt. Thẻ đáp án ở Chọn đáp án và Nối cặp dùng cỡ chữ Choice để đáp án đủ nổi bật và dễ nhớ; các thẻ khác dùng cỡ Tile.

Bảng nối cặp (template Match và Match Madness) dùng chung kích thước: cao tối thiểu 84pt (`Spacing.matchTileMinHeight`) cho dễ chạm khi chơi nhanh. Mọi thẻ trên bảng cao bằng thẻ cao nhất để hai cột thẳng hàng. Ở Match Madness, cặp đúng chuyển trạng thái Đúng một nhịp ngắn rồi mờ đi; cặp mới hiện dần vào đúng chỗ cũ, bố cục không nhảy.

| Trạng thái | Giao diện |
|---|---|
| Bình thường | Nền trắng, viền xám 1.5pt |
| Đang nhấn | Lún xuống, viền xanh 2pt |
| Đã chọn | Nền xanh nhạt, chữ xanh đậm, viền xanh 2pt |
| Đang kéo | Nền xanh nhạt, phóng to 104%, shadow mềm |
| Đúng | Nền xanh lá nhạt, chữ xanh lá đậm, viền xanh lá 2pt |
| Sai | Nền cam nhạt, chữ đỏ đậm, viền cam 2pt |
| Vô hiệu | Chữ xám, mờ 60% |

### Thành phần bài học

- **Thanh đầu bài:** nút thoát và thanh tiến độ. Dạng liền cho bài tập, dạng chia đoạn kèm số đếm "1 / 5" cho giới thiệu từ.
- **Câu hỏi:** căn trái, một dòng hướng dẫn phụ nếu cần.
- **Ô trống trong câu:** một đường gạch chân, rộng theo đáp án dài nhất để câu không nhảy dòng khi điền từ.
- **Panel phản hồi:** ghim dưới đáy, bo hai góc trên, chứa cả phản hồi và nút hành động. Cả panel đổi màu theo đúng, sai hoặc thông tin.
- **Gợi ý:** hiện theo từng nấc, kèm lựa chọn xem đáp án.
- **Ô nhập đáp án:** có nhãn, viền xanh 2pt khi focus.
- **Nút phát âm:** tròn, nền xanh nhạt, cỡ 64pt hoặc 88pt.

### Thành phần sản phẩm

- **Tiêu đề có dấu câu xanh:** tiêu đề lớn kết thúc bằng dấu xanh, như "Your routine." Đây là điểm nhận diện của thương hiệu.
- **Thanh bước:** nút quay lại và các đoạn tiến độ cho luồng ngắn.
- **Chip chủ đề:** dạng viên thuốc có icon. Trạng thái chọn thể hiện bằng màu và viền, không dùng dấu tick.
- **Nút chọn ngày:** ô vuông bo góc.
- **Ô tìm kiếm:** nền xám nhạt, viền xanh khi focus.
- **Card:** nền trắng, viền 1.5pt, không shadow.
- **Nút tròn trong sheet:** đóng và quay lại, nền xám nhạt, vùng chạm vẫn đủ 44pt.
- **Eyebrow:** nhãn nhỏ in hoa để phân nhóm.
- **Tab bar:** dùng tab bar của hệ thống với ba mục Home, My Words, Profile.

### Quy tắc nội dung trong bài học

- Phản hồi không nêu đáp án cho tới khi bài tập kết thúc.
- Đáp án và lời giải thích luôn nằm trong panel phản hồi ở đáy màn hình, không nằm trong vùng bài tập.
- Câu hỏi nghe không hiện chữ, vì chữ sẽ làm lộ đáp án.
- Âm thanh không tự phát. Người học chủ động bấm và nghe lại bao nhiêu lần tùy ý.
- Chuyển động giới thiệu từ chỉ để trình bày, không bắt người học phải chờ.
- Mỗi lúc chỉ có một hành động chính: Check, rồi Try again hoặc Continue.
- Chip không bao giờ hiển thị điểm số thật.

---

## 6. Chuyển động, âm thanh, rung

### Chuyển động

| Khoảnh khắc | Thời lượng | Cảm giác |
|---|---|---|
| Nhấn | 120ms | Nhanh, dứt khoát |
| Nhấc thẻ, đổi trạng thái | khoảng 240ms | Nhẹ, không nảy nhiều |
| Thẻ vào vị trí | khoảng 320ms | Có độ nảy nhẹ |
| Từ bay vào ô trống | khoảng 220ms | Rất nhanh, gần như không nảy |
| Thẻ quay về chỗ cũ | khoảng 340ms | Mềm |
| Panel phản hồi xuất hiện | khoảng 360ms | Nảy rõ, từ dưới lên |
| Chuyển màn hình, chuyển bước | 360ms | Bài mới vào từ phải, bài cũ ra bên trái |
| Thanh tiến độ | 400ms | Trơn, chậm dần |
| Phần tử xuất hiện | khoảng 500ms | Nảy nhiều nhất, dùng hạn chế |
| Lắc khi trả lời sai | 400ms | Một nhịp ngang. Chỉ có ở Chọn đáp án (lắc thẻ chọn sai) và Nối cặp (lắc hai thẻ của cặp sai). Các dạng bài khác không lắc |
| Ăn mừng cuối phiên | Pháo giấy lặp, mỗi vòng khoảng 5 giây | Pháo giấy lặp liên tục và hiện trọn khung hình, huy hiệu vàng bật lên, các ô số liệu lần lượt hiện ra |

Tỷ lệ: nhấn 97%, nhấc 104%.

Khi bật Reduce Motion: chuyển màn hình thành mờ dần trong 150ms, bỏ phóng to thu nhỏ, chuyển động bay, hiệu ứng lắc và pháo giấy.

### Rung

Ba loại, người dùng tắt được trong Settings: lựa chọn (nhẹ), đúng, sai.

### Âm thanh

Ba hiệu ứng, chỉ dùng trong bài học: bấm, đúng, sai.

---

## 7. Định hướng theo từng vùng

### 7.1 Vùng bài học: Brilliant + Duolingo

**Công thức: Brilliant quyết định màn hình hiển thị gì. Duolingo quyết định màn hình đáp lại thế nào.**

Cấu trúc chung của mọi dạng bài:

| Từ trên xuống | Nội dung | Ảnh hưởng |
|---|---|---|
| Thanh đầu bài | Nút thoát và tiến độ | Duolingo |
| Câu hỏi | Một câu hỏi rõ ràng | Brilliant |
| Prompt | Một prompt duy nhất, chữ hoặc âm thanh | Brilliant |
| Bài tập | Thao tác trực tiếp lên nội dung, bằng thẻ từ có độ dày | Brilliant + Duolingo |
| Panel phản hồi | Giải thích ngắn, kèm màu, âm thanh và rung | Brilliant + Duolingo |

**Từ Brilliant**

- Nền trắng, không trang trí quanh bài tập. Nội dung là nhân vật chính.
- Một màn hình chỉ có một câu hỏi và một thao tác chính.
- Ưu tiên thao tác lên chính nội dung, như kéo từ vào câu hay sửa chữ trong từ, hơn là chọn đáp án tách rời.
- Sai không bị phạt về mặt cảm xúc: giọng văn trung tính, luôn có đường đi tiếp.
- Dòng giải thích trong panel giúp người học hiểu, không chỉ thông báo đúng/sai.

**Từ Duolingo**

- Thẻ từ và nút có độ dày, lún xuống khi nhấn.
- Phản hồi ngay sau thao tác: chuyển động, rung và âm thanh đến cùng lúc.
- Panel đáy đổi màu theo kết quả.
- Tiến độ luôn nhìn thấy và chạy mượt.
- Có khoảnh khắc ăn mừng cuối phiên. Đây là nơi duy nhất dùng màu vàng nổi bật.

**Áp dụng cho từng dạng bài**

| Dạng bài | Phần Brilliant | Phần Duolingo |
|---|---|---|
| Chọn đáp án | Câu hỏi đơn, ít lựa chọn | Thẻ lún khi nhấn, đổi màu đúng/sai |
| Điền từ vào câu | Từ nằm ngay trong câu, hiểu nghĩa qua ngữ cảnh | Từ bay vào ô trống |
| Gõ từ | Tự nhớ lại, gợi ý có từng nấc | Panel và âm thanh khi kiểm tra |
| Xếp câu | Xếp câu trực tiếp trên dòng kẻ | Thẻ bay, kéo thả có xem trước vị trí |
| Nối cặp | Tự tìm quan hệ giữa hai cột | Cặp đúng khóa lại, cặp sai lắc |
| Sửa từ | Sửa trực tiếp phần viết sai trong từ | Chữ bay vào vị trí |
| Đọc to | Đọc, nhận đánh giá, đọc lại nếu muốn | Nút thở nhẹ, sóng âm theo giọng nói |

**Cuối phiên**

Màn hình kết quả là nơi tinh thần Duolingo mạnh nhất: pháo giấy, huy hiệu vàng có cạnh dày, rung báo thành công. Nội dung chỉ dùng số liệu thật của phiên học. Không thêm điểm hay huy hiệu không có ý nghĩa.

### 7.2 Vùng sản phẩm: Brilliant

Màn hình ngoài bài học phải cho người học biết ngay: hôm nay học gì, tiến độ tới đâu, và bước tiếp theo là gì.

**Bố cục**

- Một hành động chính cho mỗi màn hình. Ở Home, đó là bài học hằng ngày; thử thách ôn tập dùng nút phụ.
- Nhiều khoảng trắng. Ưu tiên phân nhóm bằng khoảng cách, chỉ dùng card khi thật sự cần.
- Phân cấp bằng cỡ và độ đậm của chữ thay vì màu.
- Card phẳng, viền mảnh, không shadow, không gradient.

**Màu**

- Nền trắng và chữ Ink chiếm phần lớn màn hình.
- Xanh Interactive là màu nhấn duy nhất, dùng tiết chế.
- Vàng chỉ xuất hiện ở logo và thành tựu thật.
- Xanh lá và cam đỏ chỉ mang nghĩa trạng thái.

**Tương tác**

- Nút phẳng hơn vùng bài học, vì độ dày là tín hiệu riêng của lúc đang học.
- Chuyển động ngắn, không nảy.
- Không có âm thanh hiệu ứng. Rung chỉ dùng cho lựa chọn.

**Giọng văn**

Rõ, ngắn, tôn trọng người đọc. Không reo hò, không dùng dấu chấm than, không gây áp lực.

---

## 8. Checklist khi thiết kế màn hình mới

**Mọi màn hình**

- [ ] Màn hình thuộc vùng nào?
- [ ] Màu, chữ, khoảng cách, bo góc đều lấy từ hệ thống?
- [ ] Có phương án cho Reduce Motion?
- [ ] Vùng chạm từ 44pt trở lên?
- [ ] Bố cục ổn với cỡ chữ lớn và cả nhãn tiếng Anh lẫn tiếng Việt?

**Vùng bài học**

- [ ] Một câu hỏi, một prompt, một thao tác chính?
- [ ] Có đủ phản hồi đúng/sai: màu, icon, chữ, âm thanh, rung?
- [ ] Không lộ đáp án trước khi bài tập kết thúc?
- [ ] Sai xong luôn có đường đi tiếp?

**Vùng sản phẩm**

- [ ] Chỉ có một hành động chính?
- [ ] Xanh Interactive là màu nhấn duy nhất?
- [ ] Không có âm thanh hiệu ứng, chuyển động nảy hay trang trí ăn mừng?
