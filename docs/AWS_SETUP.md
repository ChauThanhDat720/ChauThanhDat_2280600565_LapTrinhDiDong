# Thiết lập AWS cho Smart Hospital

Source đã có backend local `backend/server.js` (SQLite, dữ liệu demo) và backend
AWS riêng tại `backend/aws/`. `backend/template.yaml` hiện triển khai Cognito,
API Gateway REST, Lambda Node.js 24, DynamoDB và S3 private. Chưa có tài nguyên
AWS hoặc endpoint thật nào được tạo trong lần chuẩn bị source này.

## 1. Phạm vi đã kết nối

| Chức năng | API AWS |
| --- | --- |
| Đăng ký, xác nhận email, đăng nhập, quên mật khẩu | Amazon Cognito qua Amplify Flutter |
| Khoa / bác sĩ | `GET /departments`, `/doctors`, `/doctors/{id}` |
| Lịch khám / khung giờ | `/appointments`, `/doctors/{id}/availability` |
| Luồng bác sĩ / tiếp nhận / đánh giá | `/doctors/me/appointments`, `/appointments/{id}/{action}` |
| Hồ sơ bệnh nhân | `GET/POST/PATCH /patients/me` |
| Hồ sơ gia đình / mặc định | `/family/members`, `/family/members/{id}`, `/family/members/{id}/default` |
| Tiền khám | `GET/POST /appointments/{id}/intake` |
| Tư vấn hậu khám | `/teleconsultations/appointment/{id}`, `/teleconsultations/sessions/{id}` |
| Tin nhắn / đọc / đóng / tải ảnh | `/teleconsultations/sessions/{id}/{messages,read,close,attachments}` |

Các công cụ trên thiết bị vẫn chạy local. Thanh toán mô phỏng, từ điển thuốc,
sổ tiêm chủng, sinh hiệu, nhắc thuốc và kết quả xét nghiệm mẫu chưa được chuyển
sang backend AWS trong cấu hình này. Các endpoint mô phỏng đó không được công
khai qua stack AWS. Admin UI hiện vẫn là khung giao diện.

## 2. Công cụ và đăng nhập AWS

Cài AWS CLI v2, AWS SAM CLI, Node.js 24 và Flutter theo tài liệu chính thức.
Cấu hình một AWS CLI profile có quyền triển khai CloudFormation, IAM, Lambda,
Cognito, API Gateway, DynamoDB, S3 và CloudWatch. Dùng SSO nếu tài khoản hỗ trợ:

```sh
aws configure sso --profile smart-hospital
aws sso login --profile smart-hospital
aws sts get-caller-identity --profile smart-hospital
```

Các lệnh bên dưới được chạy từ thư mục dự án có `pubspec.yaml`.
Không đưa access key, secret key, mật khẩu hoặc JWT vào source/Flutter.

## 3. Kiểm tra và build backend

```sh
npm ci --prefix backend/aws --ignore-scripts
npm test --prefix backend/aws
cd backend
sam validate --lint --region ap-southeast-1
sam build
```

`CodeUri` chỉ chứa `backend/aws/`, không đóng gói SQLite/native dependency của
máy chủ local. SDK được khóa phiên bản trong `backend/aws/package-lock.json`.
Có thể dùng `sam build --use-container` nếu máy không có Node.js 24.

## 4. Triển khai

Bước này tạo tài nguyên trong tài khoản AWS và có thể phát sinh phí theo mức sử
dụng, gồm cả lưu trữ/PITR/logs. Xem change set trước khi xác nhận:

```sh
# Đang đứng trong backend/
sam deploy --guided --profile smart-hospital --region ap-southeast-1
```

Chọn stack `smart-hospital-dev`; chấp nhận tạo IAM role khi SAM yêu cầu.
`AllowedOrigin` là origin web thật (ví dụ `https://hospital.example.com`);
Android/iOS native không cần Origin header. Với Flutter web local, chạy một
cổng cố định phù hợp `AllowedOrigin=http://localhost:5173`.

Outputs gồm `ApiBaseUrl`, `AwsRegion`, `CognitoUserPoolId`,
`CognitoAppClientId`, `HospitalTableName` và `AttachmentsBucketName`.

## 5. Xuất cấu hình cho Flutter

Sau khi stack triển khai thành công, quay về thư mục dự án:

```sh
cd ..
python3 tool/configure_aws.py --stack-name smart-hospital-dev \
  --region ap-southeast-1 --profile smart-hospital
```

Lệnh chỉ đọc outputs và tạo `config/aws.local.json` (đã được gitignore).
Hoặc tải JSON kết quả `describe-stacks` rồi dùng:

```sh
python3 tool/configure_aws.py --outputs config/aws.outputs.json
```

Nếu cập nhật stack và muốn ghi đè cấu hình cũ, thêm `--force`.
`config/aws.example.json` chỉ minh họa tên trường, không phải thông tin kết nối
thật. Chỉ bật `BACKEND_MODE=aws` với đủ API URL HTTPS, Region, User Pool ID và
App Client ID. Cognito app client được tạo **không có client secret**.

```sh
flutter pub get
bash tool/run_aws.sh run -d <device-id>
# Tạo APK đã cấu hình AWS:
bash tool/run_aws.sh apk
```

Để chạy lại demo local: `flutter run` (không truyền file cấu hình AWS).
APK đã xuất trước lần thiết lập AWS này vẫn là bản local; cần build APK mới với
cấu hình thật sau khi triển khai stack.

## 6. Tài khoản bệnh nhân và bác sĩ

Bệnh nhân đăng ký trong ứng dụng, xác nhận email rồi đăng nhập. Trigger Cognito
chỉ thêm nhóm `patients` sau xác nhận đăng ký; không nâng quyền qua form đăng ký.
Bệnh nhân mới vào Cá nhân để hoàn thiện hồ sơ, sau đó đặt lịch từ danh sách bác sĩ.

Tài khoản bác sĩ được quản trị viên tạo/cấp quyền. Sau khi tài khoản đã có trong
User Pool, gán nhóm và mã bác sĩ trùng với catalog `backend/aws/src/catalog.js`:

```sh
aws cognito-idp admin-add-user-to-group --profile smart-hospital \
  --region ap-southeast-1 --user-pool-id <UserPoolId> \
  --username <doctor-email> --group-name doctors
aws cognito-idp admin-update-user-attributes --profile smart-hospital \
  --region ap-southeast-1 --user-pool-id <UserPoolId> \
  --username <doctor-email> --user-attributes Name=custom:doctorId,Value=dr-linh
```

Nếu tài khoản đó từng tự đăng ký như bệnh nhân và cần chỉ giữ vai trò bác sĩ,
quản trị viên có thể dùng `admin-remove-user-from-group --group-name patients`.
Đăng xuất/đăng nhập lại sau khi đổi nhóm để nhận token mới. App client không có
quyền tự sửa `custom:doctorId`. Các nút đăng nhập demo chỉ xuất hiện trong local mode.

## 7. Cách dữ liệu được lưu và bảo vệ quyền truy cập

API Gateway xác thực Cognito **ID token** của REST authorizer; Lambda kiểm tra
App Client ID, nhóm và ownership. Flutter dùng `fetchAuthSession()` để lấy token
hiện tại thay vì hard-code token. Header `x-role` của server demo không được dùng
trong AWS handler. Bệnh nhân chỉ lấy dữ liệu từ `sub` đã được authorizer xác thực;
bác sĩ chỉ sửa lịch và tư vấn được phân công.

DynamoDB dùng `pk/sk`, hai GSI cho danh sách bệnh nhân/bác sĩ, cùng transaction
và điều kiện version để tránh ghi đè. Đặt lịch khóa khung giờ trong cùng transaction;
hủy lịch giải phóng khóa. `Idempotency-Key` được giới hạn theo tài khoản.
Danh sách qua GSI có eventual consistency; vừa ghi có thể cần tải lại sau vài giây.

Hồ sơ gia đình lưu theo tài khoản; chat lưu tin nhắn thành các item riêng. Phiên
hậu khám hết hạn sau 7 ngày kể từ `completedAt`, không gia hạn mỗi lần mở lại.
Trợ lý tự động vẫn là hướng dẫn theo kịch bản; không tích hợp Bedrock hay mô hình
AI có phí. Cloud chat tự tải lại mỗi 15 giây khi màn hình còn mở, không phải push notification.

Ảnh tối đa 1 MB tải bằng URL S3 PUT có hạn 5 phút, ràng buộc kích thước/MIME và
prefix của người gửi/phiên. Tin nhắn chỉ lưu object key, không nhét ảnh base64 vào
DynamoDB. URL xem ảnh có hạn 15 phút và được cấp mới khi tải lại hội thoại.
Bucket không public; không có AWS credentials trong APK. Dữ liệu không tự di chuyển
từ demo local lên cloud.

DynamoDB, S3 và User Pool được đặt `Retain`: `sam delete` không tự xóa dữ liệu
người dùng trong các tài nguyên này. Khi ngừng dùng, kiểm tra/tải dữ liệu cần giữ
rồi quản lý/xóa các tài nguyên retained trong tài khoản AWS; phí lưu trữ có thể
còn tiếp tục cho đến khi tài nguyên được xóa.

## 8. Kiểm tra sau triển khai

```sh
curl -f https://<api-id>.execute-api.ap-southeast-1.amazonaws.com/v1/health
curl -i https://<api-id>.execute-api.ap-southeast-1.amazonaws.com/v1/patients/me
```

Health phải trả `status: ok`; hồ sơ không có token phải bị từ chối 401.
Kiểm tra trên app: đăng ký/xác nhận email, lưu hồ sơ, đặt lịch, bác sĩ xác nhận/
hoàn tất khám, sửa người thân, mở chat hậu khám và tải ảnh. Dùng tài khoản thứ hai
để xác nhận không thể đọc lịch, gia đình hoặc phiên chat của tài khoản thứ nhất.
Các kiểm thử local không thay thế xác nhận IAM, Cognito email delivery và mạng
trên một stack thật.

Tài liệu đối chiếu: [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html),
[Cognito REST authorizer](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-accessing-resources-api-gateway-and-lambda.html),
[Amplify Flutter session](https://docs.amplify.aws/flutter/frontend/auth/manage-user-sessions/),
[DynamoDB transactions](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis-iam.html),
[Lambda Node.js](https://docs.aws.amazon.com/lambda/latest/dg/lambda-nodejs.html).
