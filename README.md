# Smart Hospital

Ứng dụng Flutter quản lý bệnh viện. App hiện chạy local-first: bác sĩ/khoa là
dữ liệu mẫu, lịch khám lưu trong bộ nhớ và hồ sơ cơ bản cache bằng
`SharedPreferences`. Không có thông tin AWS hoặc mật khẩu trong source.

## Phase 3 — kiến trúc backend

```text
Flutter -- HTTPS + JWT --> API Gateway --> Lambda --> DynamoDB
   |                                             |
   +-- Cognito (đăng nhập, token)                +--> S3 presigned URL
```

- Flutter lấy JWT từ Amazon Cognito trong phase tích hợp xác thực.
- API Gateway kiểm tra token qua Cognito authorizer trước khi gọi Lambda.
- Lambda lấy `sub` từ JWT, kiểm tra vai trò và ownership của từng bản ghi.
- Lambda chỉ trả URL S3 ký sẵn; Flutter không bao giờ có AWS access key/secret.
- OpenStreetMap, `flutter_map` và ML Kit vẫn chạy trên thiết bị.

`backend/` là AWS SAM blueprint local. Chưa có tài nguyên AWS nào được tạo hay
deploy bởi project này.

## API contracts

| Method | Path | Auth | Mục đích |
| --- | --- | --- | --- |
| GET | `/health` | No | `{ "status": "ok", "service": "smart-hospital-api" }` |
| GET | `/departments` | No | Danh sách khoa |
| GET | `/doctors` | No | Danh sách bác sĩ |
| GET | `/doctors/{id}` | No | Chi tiết bác sĩ |
| GET | `/appointments` | Patient JWT | Chỉ lịch của token hiện tại |
| POST | `/appointments` | Patient JWT | Tạo lịch cho token hiện tại |
| GET | `/appointments/{id}` | Patient JWT | Chỉ trả lịch thuộc token hiện tại |
| PATCH | `/appointments/{id}/cancel` | Patient JWT | Chỉ hủy lịch thuộc token hiện tại |
| GET | `/patients/me` | Patient JWT | Hồ sơ của token hiện tại |
| PATCH | `/patients/me` | Patient JWT | Cập nhật hồ sơ của token hiện tại |

## DynamoDB design (đề xuất, chưa tạo bảng)

| Entity | Khóa / thuộc tính chính | Quan hệ và truy vấn |
| --- | --- | --- |
| Patients | `PK=PATIENT#{cognitoSub}`, tên, liên hệ, DOB, `role` | `GET/PATCH /patients/me` bằng `sub` JWT |
| Doctors | `PK=DOCTOR#{doctorId}`, `departmentId`, chuyên khoa | GSI `departmentId` cho danh sách theo khoa |
| Departments | `PK=DEPARTMENT#{departmentId}`, tên, mô tả | Catalog public/cache |
| Appointments | `PK=PATIENT#{sub}`, `SK=APPOINTMENT#{scheduledAt}#{id}`, doctorId, status | Query lịch bệnh nhân; GSI `DOCTOR#{doctorId}` cho portal bác sĩ |
| MedicalRecords | `PK=PATIENT#{sub}`, `SK=RECORD#{createdAt}#{id}`, doctorId | Patient sở hữu hoặc doctor được cấp quyền |
| Prescriptions | `PK=PATIENT#{sub}`, `SK=PRESCRIPTION#{createdAt}#{id}`, recordId | Query theo bệnh nhân/record |

Mọi handler phải dùng `sub` từ JWT thay vì `patientId` do client gửi. Không ghi
PHI, token hay toa thuốc vào log. IAM Lambda chỉ cấp quyền table/index/prefix S3
cần dùng.

## Flutter API client và local mode

`lib/core/network/` có `ApiConfig`, `ApiClient`, `ApiException` với GET/POST/
PATCH, timeout, lỗi HTTP/network và `AccessTokenProvider` cho JWT trong phase
Cognito. API URL không hard-code trong màn hình:

```sh
flutter run --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=API_TIMEOUT_SECONDS=15
```

`HospitalRepositories` mặc định dùng `LocalDoctorRepository`,
`LocalAppointmentRepository`, `LocalPatientRepository`. Chỉ tạo remote repo
khi phase sau truyền `useRemote: true`, API URL hợp lệ và token provider. App
vẫn dùng được khi offline/chưa cấu hình AWS.

## Kiểm tra

```sh
flutter pub get
dart format lib test
flutter analyze

cd backend
npm test
npm run format:check
```

Nếu AWS SAM CLI được cài đặt sau khi hạ tầng được phê duyệt, có thể kiểm tra
template bằng `sam validate --template template.yaml`; chưa chạy `sam deploy`.
