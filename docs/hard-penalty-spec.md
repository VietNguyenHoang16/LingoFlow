# Spec: Hard phat nang hon (muc Vua)

## Objective
Tu nhơ tôt rôi quên gân hêt, bâm `Hard` vân hen qua xa (vd 30d -> 15d).
Muc tiêu: `Hard` trên tư đã ôn lâu vân giữ được từ, nhưng hẹn lại gần hơn để ôn kịp.

## Quyêt định đã chốt với user: Mức Vừa
1. `hardMultiplier`: `0.5` -> `0.3` (nhân 30%, không nhân ease).
2. Thêm `hardMaxInterval = 7`: `Hard` trên tư `interval >= 2` luôn `cap 7 ngày`.
3. Ease: `Hard` chịu thêm `-0.06`, tông `-0.2` môi lân `Hard` (giông `Again`).
4. Streak: `Hard` không tăng streak (`giữ nguyên`), `Good/Easy` vân `+1`.
5. Lapse: `Hard` khi `currentInterval >= 14` HOĂC `đang có lapse > 0` thì `+1 lapse`.
`3 lapse -> Leech -> cap 4 ngày` giữ nguyên nên `Hard` liên tục trên tư cũ vân rơi vào Leech.
6. `interval 0/1` giữ nguyên như cũ (`Hard` lân đâu `1d`, lân 2 `2d`).
7. Preview dưới nút Review (`_calculatedIntervals`) tự cập nhật vì dùng chung `calculateNextReview`.

## Ví dụ (ease 2.5, streak 5, lapse 0)
- `30d + Hard` cũ: `15d`, ease `2.36`, streak `6`.
- `30d + Hard` mới: `7d` (`30*0.3=9 -> cap 7`), ease `2.3`, streak giữ `5`, lapse `1`.
- `60d + Hard` mới: `7d` (`60*0.3=18 -> cap 7`), ease `2.3`, streak giữ `5`, lapse `1`.
- `10d + Hard` mới: `3d` (`10*0.3=3`), ease `2.3`, streak giữ `5`, lapse `0`.
- `Hard -> Hard -> Hard` trên tư `30d`: lapse `1 -> 2 -> 3`, rơi vào Leech, interval cuôi `<= 4d`.
- `30d + Good` không đôi: `75d` (`30*2.5`), ease `+0`, streak `6`, lapse reset `0`.

## Boundaries
- Always: viêt test RED trước, chạy `flutter test test/srs_service_test.dart`, `dart analyze` file đôi.
- Never: đôi hành vi `Again/Good/Easy`, đôi UI Review, đôi DB schema.

## Success Criteria
- [x] `test/srs_service_test.dart` có các case trên và pass.
- [ ] `flutter test` toàn suite liên quan không regression.
- [ ] Preview `Hard` trên tư `30d` hiên `7d` thay vì `15d`.
