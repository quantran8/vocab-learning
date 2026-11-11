# Challenge Map / Match Madness: ghi chú phía iOS

*Cập nhật: 11/11/2026.*

Client iOS bám theo **code backend** (`vocab-backend/src/modules/challenge/`) và mục 12 của `vocab-backend/docs/FRONTEND_FLOW.md`. Hai file spec `SYLL_MATCH_MADNESS_FRONTEND_SPEC.md` / `SYLL_MATCH_MADNESS_BACKEND_SPEC.md` chỉ dùng tham khảo: chỗ nào khác code backend thì theo code backend.

## Code phía iOS

| File | Vai trò |
|---|---|
| `VocabFlow/Domain/Challenge/ChallengeMapModels.swift` | Model của `GET /v1/me/challenge-map`, tóm tắt cho thẻ Home |
| `VocabFlow/Domain/Challenge/ChallengeRunModels.swift` | Plan, body commit, response commit, status, mã lỗi |
| `VocabFlow/Domain/Challenge/MatchMadnessEngine.swift` | Lõi game (pure), phải giống hệt `Board` / `replay` của backend |
| `VocabFlow/Domain/Challenge/ChallengeBoardOrdering.swift` | Thứ tự cột theo SHA256, dùng chung với backend |
| `VocabFlow/Domain/Challenge/ChallengeBoardSlots.swift` | Vị trí thẻ trên màn hình (chỉ hiển thị, không ảnh hưởng commit) |
| `VocabFlow/Features/Challenge/ChallengeRunStore.swift` | issue → start → chơi → commit, retry và khôi phục |
| `VocabFlow/Features/Challenge/ChallengeMapStore.swift` | Tải và làm mới map |
| `VocabFlow/Features/Challenge/ChallengeMapView.swift`, `ChallengeLevelSheet.swift`, `ChallengeHomeCard.swift` | Map, sheet của level, thẻ Home |
| `VocabFlow/Features/Challenge/MatchMadnessGameView.swift`, `ChallengeComponents.swift`, `ChallengeResultsView.swift` | Màn Start, màn chơi, thẻ nối cặp, kết quả |
| `VocabFlowTests/MatchMadnessBackendParityTests.swift` | Fixture sinh từ chính code backend |

## Các chỗ đã lệch và đã sửa (10/11/2026)

Bản iOS đầu tiên viết theo spec frontend, nên lệch với backend thật ở các chỗ sau. Tất cả đã sửa phía iOS.

| Chỗ | iOS bản đầu | Backend |
|---|---|---|
| Level trong map | Có goal, thời gian, `starCriteria`, `title` | Lúc đó chỉ có `levelNo`, `state`, `bestStars`, `bestScore` (11/11 thêm goal và `starCriteria`, xem dưới) |
| Chapter trong map | `chapterId`, `earnedStars` | `id`, `starsEarned`, `maxStars`; state thêm `content_unavailable` |
| `nextChapter.state` | Không có `locked` | Có `locked` |
| Lấp thẻ lên bàn | Lấy cặp kế tiếp trong hàng đợi | Cặp đầu tiên mà nghĩa (cùng `word`) chưa ở trên bàn và chưa được nối đúng trong `minMatchesBetweenRepeats` lần gần nhất |
| `elapsedMs` của event | Cho phép bằng nhau | Tăng ngặt |
| Response commit | `unlock`, `nextAction` nằm trong `result` | Nằm ở cấp ngoài; `unlock.kind` là `level`, `chapter_ready`, `needs_vocabulary` hoặc `none`; `nextAction` là `play_next_level`, `open_map`, `learn_more` hoặc `retry` |
| Status | Trả `result`; có status `quit` | Trả `response` và `run`; status `abandoned` |
| Plan | Thiếu `minMatchesBetweenRepeats`; `starCriteria` dạng danh sách chữ | Có `minMatchesBetweenRepeats`; `starCriteria` dạng `{two, three}` (`maxElapsedMs`, `maxMistakes`) |
| Mã lỗi | Thiếu 3 mã | Có thêm `CHALLENGE_LEVEL_LOCKED`, `CHALLENGE_RUN_NOT_FOUND`, `CHALLENGE_RUN_NOT_STARTED`; `CHALLENGE_RUN_ACTIVE` kèm `details.runId` |

Cách iOS xử lý một số trường hợp:

- `CHALLENGE_RUN_ACTIVE`: nếu run cũ còn `issued` thì app tự `quit` nó rồi tạo run mới (chưa chơi gì nên không mất gì). Nếu run cũ đã `started` thì hỏi người chơi trước khi bỏ.
- `CHALLENGE_RUN_NOT_STARTED` khi commit: gọi lại start (idempotent) một lần, rồi gửi lại đúng body cũ.
- Bấm thoát khi đã hết giờ: gửi `time_up`, không gửi `quit`.
- POST tạo run, start và quit gửi body `{}`.

## Bảng trên màn hình khác thứ tự của engine

Sau mỗi lần nối đúng, `MatchMadnessEngine` xếp lại cả hai cột theo `ChallengeBoardOrdering`, đúng như `Board` của backend; `MatchMadnessBackendParityTests` kiểm tra điều này. Màn hình **không** vẽ theo thứ tự đó, vì cả bảng xáo lại sau mỗi cặp làm người chơi mất chỗ nhìn:

- `ChallengeBoardSlots.reconcile` giữ mỗi thẻ ở một ô cố định. Thẻ mới vào ô vừa trống (ưu tiên từ trên xuống). Hết cặp để lấp thì ô để trống, các thẻ bên dưới không dịch lên.
- Cặp vừa đúng giữ trạng thái Đúng trong `MotionTokens.matchCorrectHold` (0,3 s, không chạm được), rồi mờ đi (`matchFadeOut`). Cặp mới hiện dần (`matchFadeIn`). Trong lúc đó vẫn nối được cặp khác.
- An toàn với backend vì event commit chỉ chứa `wordTileId` / `meaningTileId`, không có vị trí. **Không** sửa engine để đổi bố cục: lệch replay là `422`.

## Kiểm tra lại khi backend đổi

1. So `src/modules/challenge/` (đặc biệt `domain/match-madness.ts`, `services/challenge-run.service.ts`, `domain/challenge-map.ts`) với các file model và `MatchMadnessEngine` phía iOS.
2. Tạo lại fixture của `MatchMadnessBackendParityTests` bằng cách chạy `Board` / `replay` của backend với `vocab-backend/node_modules/.bin/tsx`. Fixture hiện tại là một plan level 3 (16 lượt, 12 nghĩa, 4 nghĩa lặp) có một lần nối sai; backend chấm đạt 3 sao.
3. Chạy `MatchMadnessEngineTests`, `MatchMadnessBackendParityTests`, `ChallengeRunStoreTests`.

## Việc chờ backend đã xong (11/11/2026)

1. **Luật điểm trong plan.** Plan gửi `score: {match, streakStep, maxStreakSteps, mistake, perSecondLeft}`. Màn chơi hiện điểm tạm thời theo luật này, gồm cả thưởng qua màn `perSecondLeft × số giây còn lại`, chỉ kẹp 0 ở tổng. Điểm chính thức vẫn là `result.score` sau commit. Plan cũ thiếu `score` thì ẩn điểm tạm thời.
2. **Mục tiêu từng level trên map.** Level trong map có `goalMatches`, `visiblePairs`, `timeLimitMs`, `starCriteria` (tùy chọn). Sheet của level hiện mục tiêu và luật sao; plan của run vẫn có tiếng nói cuối cùng.

## Dọn dẹp sau

- `LearnerStore` vẫn tải dữ liệu Journey / checkpoint cũ. Các file trong `Features/Journey/` vẫn còn nhưng không màn hình nào dẫn tới. Xoá khi backend bỏ các route đó.
