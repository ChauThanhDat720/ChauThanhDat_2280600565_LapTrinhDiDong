# Smart Hospital

Ứng dụng Flutter quản lý bệnh viện với ba chế độ:

- **Local** (mặc định): dữ liệu demo và các chức năng trên thiết bị.
- **Shared**: điện thoại bệnh nhân và web bác sĩ dùng chung API + SQLite; đặt lịch, check-in, lộ trình bốn bước và đơn thuốc. Chạy demo không cần VPS: [hướng dẫn](docs/SHARED_DEMO.md).
- **AWS**: Cognito + API Gateway REST + Lambda Node.js 24 + DynamoDB + S3 private.

Source đã có API; cấu hình AWS được chuẩn bị tại `backend/template.yaml` và
`backend/aws/`. Chưa tạo tài nguyên cloud hay endpoint thật. Không có AWS access
key, secret key, mật khẩu hoặc token được đưa vào source.

## Thiết lập AWS

Hướng dẫn đầy đủ: [docs/AWS_SETUP.md](docs/AWS_SETUP.md).

```text
Flutter -- Cognito ID token --> API Gateway --> Lambda --> DynamoDB
   |                                            |
   +-- Cognito đăng nhập                        +--> S3 URL ký sẵn cho ảnh
```

AWS mode đã nối các luồng đăng nhập/đăng ký, bác sĩ, đặt lịch, tiếp nhận, hồ sơ
bệnh nhân, gia đình, tiền khám và tư vấn hậu khám. Công cụ thiết bị, thanh toán
mô phỏng, tiêm chủng, sinh hiệu, nhắc thuốc và kết quả xét nghiệm mẫu còn ở local.

Sau khi triển khai stack, xuất public IDs và API URL thành file cấu hình:

```sh
python3 tool/configure_aws.py --stack-name smart-hospital-dev \
  --region ap-southeast-1 --profile smart-hospital
bash tool/run_aws.sh run
```

`config/aws.example.json` chỉ là mẫu. `config/aws.local.json` được gitignore.
Để tạo APK kết nối AWS thật, chạy `bash tool/run_aws.sh apk` sau khi đã có cấu
hình thật. APK local đã xuất trước đó không tự đổi sang AWS.

## Chạy local và kiểm tra

```sh
flutter pub get
flutter run
flutter analyze
flutter test

# AWS API unit tests, không gọi cloud:
npm ci --prefix backend/aws --ignore-scripts
npm test --prefix backend/aws

# Backend SQLite demo (không deploy server này lên Lambda):
cd backend
npm ci
npm test
npm start
```

Backend AWS được đóng gói riêng nên không phụ thuộc SQLite. API yêu cầu quyền
bệnh nhân/bác sĩ từ token, không dùng header giả lập role của server local.
Xem hướng dẫn AWS để validate/build SAM, triển khai, gán tài khoản bác sĩ và xuất
cấu hình Flutter.

## Hồ sơ gia đình và tư vấn hậu khám trong local mode

- Hồ sơ gia đình được lưu trên thiết bị bằng `SharedPreferences`, theo tài khoản
  email local (hoặc vùng dữ liệu demo khi chưa đăng nhập). Thêm, sửa, xóa và chọn
  hồ sơ mặc định đều được lưu; các màn hình đọc lại cùng dữ liệu. Chỉ báo thành
  công sau khi ghi xong. Khi sửa người đang xem, thanh chọn hồ sơ cập nhật ngay.
- Phiên hậu khám lưu tin nhắn, ảnh đính kèm, trạng thái đóng, thời hạn và lựa chọn
  bật/tắt phản hồi tự động. Đóng rồi mở ứng dụng không khởi tạo lại lịch sử hoặc
  gia hạn phiên đã lưu. Tin của bệnh nhân vẫn được đánh dấu chờ bác sĩ xem dù
  trợ lý đã trả lời.
- Trợ lý hậu khám hiện hoạt động offline theo nhóm câu hỏi, có nhãn riêng với bác
  sĩ. Hỗ trợ hỏi đơn thuốc đã lưu, quên liều, triệu chứng, tái khám và ghi yêu cầu
  bác sĩ. Đây chưa phải mô hình AI qua API hay kênh gửi thông báo đến bác sĩ từ xa.
  AWS backend cũng có trợ lý theo kịch bản và lưu chat trên DynamoDB; xem hướng dẫn AWS.
- Đính kèm ảnh thật từ thư viện/camera, tối đa 1 MB sau thu nhỏ. Ảnh được lưu cùng
  hội thoại trên thiết bị; trợ lý không suy luận chẩn đoán từ ảnh. Khi gửi lỗi,
  bản nháp còn nguyên để thử lại và nút gửi ngăn thao tác gửi lặp.

Nội dung hỗ trợ thuốc tham khảo [NHS SPS](https://www.sps.nhs.uk/articles/advising-on-missed-or-delayed-doses-of-medicines/)
và [Surrey and Sussex Healthcare NHS Trust](https://www.surreyandsussex.nhs.uk/our-services/pharmacy).
Trợ lý không tự kê đơn hoặc thay đổi liều; các câu hỏi cần đánh giá điều trị được
hướng dẫn liên hệ bác sĩ/dược sĩ, dấu hiệu nghiêm trọng được ưu tiên hướng dẫn cấp cứu.

Kiểm thử hồi quy:

```sh
flutter test test/family_feature_test.dart test/teleconsultation_test.dart \
  test/family_post_care_regression_test.dart
flutter analyze
```

Nếu hệ thống báo lỗi đọc file build `Operation timed out` trong Desktop, có thể
sao chép mã nguồn sang một thư mục local khác, bỏ qua `build/`, `.dart_tool/` và
các thư mục `.gradle/`, rồi chạy `flutter pub get` để tạo lại cache build.
