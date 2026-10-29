# Demo điện thoại đặt lịch – web bác sĩ xác nhận

## Kết quả kiểm tra lưu trữ

| Dữ liệu | Chế độ local cũ | Chế độ shared mới |
| --- | --- | --- |
| Lịch khám | `AppointmentStore`, chỉ trong RAM; mất khi tiến trình dừng | SQLite trên backend, giữ sau khi khởi động lại |
| Tài khoản | Lưu từng thiết bị bằng SharedPreferences; mật khẩu local chưa băm | Đăng ký/đăng nhập tại backend, băm mật khẩu với scrypt và salt riêng |
| Phiên đăng nhập | Trên từng thiết bị | Token ngẫu nhiên hạn 24 giờ; server chỉ lưu hash, đăng xuất thu hồi token |
| Bác sĩ xác nhận | Chỉ thay đổi trong app đang mở | Đúng bác sĩ được phân công sửa lịch; điện thoại đọc lại từ cùng server |
| Check-in, số thứ tự, lộ trình và đơn thuốc | Mô phỏng trong tiến trình local | SQLite dùng chung; bác sĩ gọi khám, chỉ định CLS, lưu đơn; bệnh nhân báo tiến độ |
| Thanh toán và nhận thuốc của lộ trình | Local | Lưu cờ thanh toán **mô phỏng** và xác nhận nhận thuốc trên server; không chuyển tiền |
| Gia đình, hồ sơ cá nhân, tiền khám, tư vấn, thanh toán, sinh hiệu... | Local/demo tùy chức năng | Vẫn local trong bản demo shared này; chưa đồng bộ các chức năng này |

Shared là chế độ mới riêng, không thay backend AWS hoặc `backend/server.js` cũ.
Không tự chuyển dữ liệu local sang shared. Lịch cũ đã mất khỏi RAM không thể khôi phục từ backend.
Backend shared có catalog ba bác sĩ: Linh (Tim mạch), Đức (Nhi), Lan (Da liễu).
SQLite đặt tại `backend/data/shared-demo.db` (được gitignore), có WAL và khóa unique khung giờ.
Một server/volume dùng cho bản demo. Cần sao lưu file DB đúng cách; không xóa volume khi nâng cấp.

## 1. Chạy backend và web bác sĩ trên máy Mac

Yêu cầu Node.js **24** (SQLite có sẵn); backend này không cần cài npm dependencies.
Tất cả lệnh sau chạy từ thư mục có `pubspec.yaml`.

```sh
bash tool/run_shared_demo.sh server
```

Mở **http://localhost:3000/doctor** trên máy tính. Giữ terminal backend hoạt động.

| Vai trò | Email | Mật khẩu demo |
| --- | --- | --- |
| Bác sĩ Linh – Tim mạch | doctor.linh@hospital.com | Doctor@123 |
| Bác sĩ Đức – Nhi | doctor.duc@hospital.com | Doctor@123 |
| Bác sĩ Lan – Da liễu | doctor.lan@hospital.com | Doctor@123 |
| Bệnh nhân An | patient.an@hospital.com | Patient@123 |

Chỉ `DEMO_MODE=1` mới tạo các tài khoản mẫu. Dùng dữ liệu giả cho bản demo này.
Bệnh nhân có thể đăng ký tài khoản mới trong app; form không thể tự nâng quyền bác sĩ.
Trang bác sĩ chỉ hiện lịch của bác sĩ đăng nhập, cập nhật mỗi 5 giây khi tab còn mở.
Token web giữ trong sessionStorage của tab; app giữ token demo trong SharedPreferences,
không lưu mật khẩu server trên thiết bị. Bản demo chưa có email xác thực, khôi phục mật khẩu,
quản trị tài khoản, push notification hoặc lưu token bằng kho bảo mật của hệ điều hành.

## 2. Điện thoại Android qua USB (không cần cùng Wi-Fi)

Bật USB debugging, kết nối và chấp nhận máy tính trên điện thoại.

```sh
flutter devices
bash tool/run_shared_demo.sh android 0123456789ABCDEF
```

Thay ID bằng thiết bị thực tế. Script chạy `adb reverse tcp:3000 tcp:3000` và
Flutter với `config/shared.demo.json`. Điện thoại truy cập `127.0.0.1:3000` qua USB.
Chỉ bản **debug** cho phép HTTP; bản release giữ yêu cầu HTTPS. Script cài bằng
`adb install -r` trước, dừng nếu khác chữ ký và không tự gỡ bản cũ/xóa dữ liệu.
Chạy `flutter run` không truyền cấu hình vẫn vào local và **không đồng bộ**.

## 3. Demo hai chiều

1. Trên web đăng nhập bác sĩ Linh, chọn bộ lọc **Chờ xác nhận**.
2. Trên app điện thoại đăng nhập bệnh nhân An (hoặc đăng ký tài khoản mới).
3. Vào Bác sĩ → **BS. Trần Thảo Linh** → Đặt lịch, chọn ngày/giờ tương lai và lý do khám.
4. App ghi nhận **Chờ xác nhận**. Web nhận lịch trong khoảng 5 giây.
5. Bác sĩ bấm **Xác nhận lịch**, nhập ghi chú nếu cần.
6. Mở tab **Lịch khám** trên app; danh sách tự cập nhật mỗi 5 giây khi đang hiển thị.
7. Dừng/mở lại backend, đăng nhập lại nếu cần: lịch và trạng thái vẫn còn trong SQLite.

## Lộ trình bốn bước và kê đơn (bản cập nhật)

Tải lại web bác sĩ sau khi cập nhật backend. Bác sĩ chỉ thao tác được trên các
ca được phân công cho tài khoản đang đăng nhập; không tự chuyển sang khoa khác.

1. **Tiếp đón:** bệnh nhân mở Thẻ tiếp đón → Mô phỏng Quét Check-in Ngay. API
   chỉ nhận lịch `confirmed`, cấp STT theo bác sĩ/ngày khám và gán phòng.
   Bấm lại không sinh thêm STT; không dùng mã của người khác để check-in.
   Bác sĩ cũng có nút Tiếp đón bệnh nhân trên web cho ca của mình.
2. **Khám chuyên khoa:** web chọn ca đã tiếp đón → Gọi vào khám. Thẻ trên điện
   thoại hiện lời gọi và phòng khám trong khoảng 5 giây, không cần thoát màn hình.
3. **Cận lâm sàng nếu có:** bác sĩ nhập chỉ định; bệnh nhân thấy nội dung ở
   bước 3, bấm Tôi đã thực hiện cận lâm sàng. Đây chỉ là báo tiến độ của bệnh nhân,
   không tạo kết quả xét nghiệm giả. Bác sĩ nhập ghi nhận và xác nhận đã kiểm tra
   kết quả trước khi lên đơn. Nếu không chỉ định CLS, có thể lên đơn ngay sau gọi khám.
4. **Đơn thuốc và nhận thuốc:** bác sĩ chọn Lên đơn thuốc & hoàn tất khám, nhập
   kết luận, từng dòng thuốc/liều/cách dùng/thời gian và lời dặn, rồi Lưu và gửi bệnh nhân.
   Nội dung do bác sĩ nhập; hệ thống không tự kê đơn hoặc mặc định thuốc.
   Điện thoại hiển thị đơn ở bước 4 và chi tiết lịch khám, không bị khóa bởi hóa
   đơn local cũ. Bệnh nhân bấm Mô phỏng thanh toán (không chuyển tiền), rồi
   Xác nhận tôi đã nhận thuốc; web bác sĩ nhận lại trạng thái hoàn tất.

Chỉ đánh dấu hoàn tất bước 4 khi bệnh nhân xác nhận nhận thuốc. Không suy ra
đã có kết quả CLS hoặc đã nhận thuốc chỉ vì bác sĩ hoàn tất khám. Trạng thái và
đơn thuốc vẫn được giữ khi đóng/mở lại server. Đây là mô phỏng quy trình, chưa
kết nối LIS, thu ngân hoặc cấp phát thuốc thực tế. Các hóa đơn VietQR cũ nằm ngoài
luồng lộ trình shared và chưa được đồng bộ. Demo cho phép check-in lịch đã xác
nhận của ngày khác để trình diễn; STT vẫn tách theo ngày hẹn.

Các API mới: `POST /appointments/{id}/checkin` và
`POST /appointments/{id}/journey` (call, order_lab, report_lab, review_lab,
prescribe, simulate_payment, receive_medicines). Server kiểm tra người sở hữu,
vai trò và thứ tự bước. `simulate_payment` chỉ bật khi `DEMO_MODE=1`.

Kiểm chứng bản cập nhật: 22 kiểm thử Flutter liên quan và 2 kiểm thử luồng API
đều đạt, bao gồm thứ tự các bước, phân quyền, check-in lặp, giữ dữ liệu qua lần
khởi động lại, nhận đơn và xác nhận nhận thuốc trên màn hình rộng 360 logical pixels.
Bản mới đã cài đè giữ dữ liệu trên NX669J. Backend đang chạy đã nhận các ca ở
`prescribed` và `finished`, xác nhận tương tác hai chiều đã được ghi vào SQLite.

Không có thông báo nền/push; khi mất mạng app không báo đặt lịch thành công giả.
Màn hình chi tiết đang mở có thể cần quay về danh sách để nhận trạng thái mới.
Trang chủ tải lịch khi mở lại; tự cập nhật 5 giây áp dụng cho **danh sách lịch**.
Đặt lịch dùng danh tính từ server và luôn khởi tạo pending, không nhận trạng thái xác nhận từ client.
Demo shared hiện đặt cho chủ tài khoản; chưa hỗ trợ đồng bộ lịch đặt hộ người thân.

## 4. Cùng mạng Wi-Fi

Chạy backend nhận kết nối LAN:

```sh
HOST=0.0.0.0 bash tool/run_shared_demo.sh server
```

Tạo `config/shared.local.json` từ `config/shared.demo.json`, thay `API_BASE_URL` bằng
`http://<IP-LAN-cua-Mac>:3000`. Chạy:

```sh
flutter run -d <device-id> --dart-define-from-file=config/shared.local.json
```

Điện thoại và máy Mac phải cùng mạng; cho phép kết nối Node nếu macOS hỏi.
Không dùng `localhost` của điện thoại cho địa chỉ Mac khi không có adb reverse.
Web bác sĩ mở `http://<IP-LAN-cua-Mac>:3000/doctor`. HTTP LAN chỉ phục vụ dữ liệu demo.
Flutter web nếu cần có thể chạy `bash tool/run_shared_demo.sh web`, rồi mở port 8080;
trang bác sĩ riêng tại port 3000 không cần biên dịch Flutter web.

## 5. Chuẩn bị VPS (chưa triển khai thực tế)

Đã chuẩn bị Docker Compose + Caddy để chạy **demo** bằng HTTPS, một API container
và một volume SQLite. Chưa mua VPS, chưa tạo tài nguyên hoặc tên miền.
Cần VPS Linux có Docker Compose, DNS tên miền trỏ đúng IP, mở TCP 80/443.

Sao chép `backend/` lên VPS; từ thư mục `backend/shared/`:

```sh
HOSPITAL_DOMAIN=demo.ten-mien-cua-ban.vn docker compose up -d --build
```

Mở `https://demo.ten-mien-cua-ban.vn/doctor`. Chỉ proxy công khai 80/443;
API port 3000 ở mạng nội bộ Docker. Compose đang bật tài khoản mẫu và chỉ dành cho demo.
Để dùng server này cho dữ liệu thật cần hoàn thiện quản trị tài khoản, đổi/khôi phục mật khẩu,
bảo vệ phiên trên thiết bị, sao lưu, giám sát và đánh giá quyền truy cập các tính năng mở rộng.

Tạo `config/shared.local.json` theo `config/shared.vps.example.json`, thay URL thật rồi build:

```sh
flutter build apk --release --dart-define-from-file=config/shared.local.json
```

APK local cũ không tự chuyển server. Không bật ALLOW_INSECURE_HTTP với VPS.
Khi thay image, giữ volume `hospital-data`; không chạy `docker compose down -v` nếu cần giữ dữ liệu.
Backup SQLite phải dùng SQLite backup API hoặc dừng API trước khi sao chép toàn bộ dữ liệu;
không copy riêng file `.db` đang có WAL để coi là một backup đầy đủ.

## 6. Kiểm thử

```sh
npm run test:shared --prefix backend
flutter test test/shared_backend_test.dart test/aws_backend_test.dart \
  test/appointment_ui_test.dart test/doctor_dashboard_test.dart
flutter test test/visit_journey_test.dart test/reception_checkin_test.dart \
  test/hospital_navigation_test.dart
flutter analyze
```

Kiểm thử API tạo database tạm, đặt lịch từ một client, bác sĩ xác nhận từ client khác,
đọc lại từ bệnh nhân, kiểm tra người khác không xem/sửa được, tranh chấp khung giờ,
token đăng xuất và đóng/mở lại server vẫn giữ trạng thái. Đây là kiểm thử local;
kết nối VPS cần kiểm tra riêng khi có máy chủ.

Kết quả kiểm tra lúc chuẩn bị: kiểm thử API shared và 20 kiểm thử Flutter cho
auth/booking/AWS/doctor/workflow đều đạt. Docker Compose xác thực cấu hình thành công.
Kiểm thử cũ `TC22 completed appointment renders medical record and prescription`
chưa đạt vì giao diện hiện khóa đơn thuốc trước thanh toán; đã tái hiện cùng lỗi
với file màn hình từ Git HEAD trước thay đổi. `flutter analyze` còn một thông tin
`use_build_context_synchronously` có sẵn ở màn hình nhắc thuốc, không có lỗi mới
trong các file bổ sung. Build/test Flutter được chạy từ bản sao `/private/tmp/`
vì cache trong Desktop bị `Operation timed out`.

Đã cài và chạy cấu hình shared trên điện thoại Android NX669J qua USB/adb reverse;
đã quan sát lịch người dùng đặt từ điện thoại xuất hiện và được xác nhận trên web
bác sĩ. Một lịch giả có nhãn `[DEMO]` cũng được xác nhận qua giao diện Safari,
sau đó đọc lại từ API bệnh nhân để kiểm tra trạng thái `confirmed` và ghi chú.
Backend demo vẫn cần chạy trên Mac; kết nối USB phải được giữ khi dùng địa chỉ
`127.0.0.1:3000` trong cấu hình demo.
