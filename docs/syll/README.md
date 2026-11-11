# Syll: bộ tài liệu

> **Learn words. Enjoy the process. Remember for longer.**

Syll (tên cũ trong code và backend: *Vocab Flow* / *VocabFlow*) là app iOS học và ghi nhớ từ vựng tiếng Anh với nghĩa tiếng Việt, qua các micro-lesson ngắn có tính game, active recall và spaced repetition. Mascot của app là **Syllie**.

| File | Nội dung | Dành cho |
|---|---|---|
| [01_APP_CONCEPT.md](01_APP_CONCEPT.md) | Định vị, đối tượng, kiến trúc nội dung Collection → Topic → Vocabulary, core loop, nguyên tắc học, MVP, validation, rủi ro | Product, design, mọi người mới vào team |
| [02_FRONTEND.md](02_FRONTEND.md) | Tính năng app theo từng màn hình và các core function của client iOS (kiến trúc, session engine, 7 template, networking, design system, localization) | iOS engineer, designer, QA |
| [03_BACKEND.md](03_BACKEND.md) | Backend NestJS: module, data model, API, plan → commit, chấm điểm, SRS, xác minh kỹ năng, Journey, custom word bằng AI, admin, vận hành | Backend engineer, iOS engineer cần hiểu contract |
| [04_CHALLENGE_IOS_NOTES.md](04_CHALLENGE_IOS_NOTES.md) | Challenge Map / Match Madness phía iOS: code nằm ở đâu, các chỗ đã lệch với backend, cách kiểm tra lại, việc chờ backend | iOS engineer, backend engineer |

## Repo và tài liệu nguồn

| Nơi | Vai trò |
|---|---|
| `vocab-learning/` (repo này) | App iOS SwiftUI, landing page (`landing/`), file Rive (`design/`) |
| `vocab-learning/CLAUDE.md` | Ghi chú kiến trúc chi tiết cho client |
| `vocab-learning/docs/DESIGN_SYSTEM.md` | Design system (màu, typography, motion, component) |
| `vocab-learning/docs/AUTH_SETUP.md` | Cấu hình Google, Apple, Supabase |
| `vocab-backend/` (repo anh em) | Backend |
| `vocab-backend/docs/FRONTEND_FLOW.md` | Contract API chi tiết từng endpoint và từng template (nguồn chuẩn) |
| `vocab-backend/docs/DECISIONS.md` | Các quyết định mà spec còn để mở, giá trị đang dùng |
| `vocab-backend/spec/` | Spec backend v0.4 (bản Engineering Review Draft, chưa được duyệt) |

Khi các file ở đây mâu thuẫn với code hoặc với `FRONTEND_FLOW.md`, code và `FRONTEND_FLOW.md` đúng. Các con số policy (SRS, số lần thử, hạn mức) đều là **giá trị thử nghiệm**, nằm trong `vocab-backend/src/config/policy.ts`.

*Cập nhật: 11/11/2026.*
