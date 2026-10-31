# Hướng dẫn Triển khai Web API Backend & Kết nối Flutter App

Tài liệu này hướng dẫn chi tiết cách deploy Web API Backend lên Internet (có HTTPS công khai miễn phí) và cấu hình ứng dụng Flutter để gọi API theo đúng yêu cầu đồ án.

---

## 1. Kiến trúc Backend Web API hiện tại

Hệ thống backend được xây dựng hoàn chỉnh tại thư mục `backend/`:
- **Nền tảng:** Node.js REST API + SQLite / In-Memory Store + Realtime SSE.
- **Bộ kiểm thử tự động:** 68/68 integration tests đạt 100% (`npm test`).
- **Các API chính:**
  - `POST /auth/register`, `POST /auth/login`, `POST /auth/logout`, `GET /auth/me`: Xác thực và phân quyền (Bệnh nhân & Bác sĩ).
  - `GET /doctors`, `GET /doctors/:id`: Danh mục bác sĩ và chuyên khoa.
  - `GET /departments`: Danh mục các khoa phòng bệnh viện.
  - `GET /appointments`, `POST /appointments`, `GET /appointments/:id`: Đặt lịch khám, tính toán slot trống, phòng ngừa xung đột lịch trùng.
  - `POST /appointments/:id/checkin`: Lễ tân / Bệnh nhân quét mã QR tiếp đón, tự động cấp Số Thứ Tự (STT) và phân phòng khám.
  - `POST /appointments/:id/journey`: Lộ trình 4 bước khám (Gọi vào khám, Chỉ định cận lâm sàng CLS, Nhận kết quả CLS, Kê đơn thuốc điện tử, Xác nhận nhận thuốc).
  - `GET /patients`, `PATCH /patients/:id`: Hồ sơ cá nhân bệnh nhân.
  - `GET /family`, `POST /family`, `PATCH /family/:id`: Quản lý hồ sơ y tế gia đình.
  - `GET /medicines`: Tra cứu danh mục thuốc và chỉ định.
  - `GET /reminders`, `POST /reminders`: Nhắc uống thuốc tự động.
  - `GET /vitals`, `POST /vitals`: Nhật ký sinh hiệu (Huyết áp, Tim mạch, SpO2) và cảnh báo nguy cơ.
  - `GET /payments`, `POST /payments/create-invoice`, `POST /payments/simulate`: Thanh toán viện phí VietQR & MB Bank.
  - `GET /teleconsultations`: Tư vấn y tế sau khám (Chat bác sĩ - bệnh nhân).
  - `GET /realtime`: Server-Sent Events (SSE) đồng bộ trạng thái hàng đợi và thông báo tức thì.

---

## 2. Các phương án Deploy Web API lên Internet

### Cách 1: Deploy miễn phí lên Render.com (Khuyên dùng - 3 phút, có sẵn HTTPS)

Render cung cấp dịch vụ Web Service miễn phí với chứng chỉ HTTPS tự động (bắt buộc cho mobile):

1. **Đẩy code lên GitHub:**
   ```bash
   git add .
   git commit -m "feat: complete backend Web API, dockerfile and render config"
   git push origin main
   ```

2. **Tạo Web Service trên Render:**
   - Truy cập: [https://dashboard.render.com](https://dashboard.render.com) (Đăng nhập bằng tài khoản GitHub).
   - Chọn **New +** -> **Web Service**.
   - Chọn repository GitHub của bạn (`ChauThanhDat_2280600565_LapTrinhDiDong`).
   - Cấu hình:
     - **Name:** `smart-hospital-api` (hoặc tên nhóm tuỳ chọn).
     - **Root Directory:** `backend`
     - **Environment:** `Node`
     - **Build Command:** `npm install`
     - **Start Command:** `npm start`
     - **Instance Type:** `Free`
   - Bấm **Create Web Service**.

3. **Lấy URL Web API:**
   - Sau 1-2 phút, Render sẽ cung cấp URL công khai dạng:
     `https://smart-hospital-api.onrender.com`
   - Kiểm tra API hoạt động bằng trình duyệt hoặc Postman:
     Truy cập: `https://smart-hospital-api.onrender.com/health` -> Nhận `{ "status": "ok" }`.

---

### Cách 2: Deploy lên Railway.app / Fly.io

- **Railway:** Đăng nhập [railway.app](https://railway.app), chọn *New Project* -> *Deploy from GitHub repo* -> chọn thư mục `backend`. Railway sẽ tự động build qua file `backend/Dockerfile` và sinh domain HTTPS.

---

### Cách 3: Chạy thử nghiệm Local / LAN (Khi demo trên lớp cùng mạng Wi-Fi)

Nếu thầy cô yêu cầu demo trực tiếp máy tính của nhóm làm server:

1. **Khởi động server nhận kết nối LAN:**
   ```bash
   cd backend
   node server.js
   ```
2. **Tìm IP máy tính của bạn:**
   - Trên Windows: Chạy lệnh `ipconfig` (ví dụ IP là `192.168.1.15`).
   - Web API sẽ lắng nghe tại: `http://192.168.1.15:3000`.

---

## 3. Cấu hình Flutter App gọi lên Web API đã Deploy

Sau khi có URL của Web API đã deploy (ví dụ: `https://smart-hospital-api.onrender.com`), cấu hình Flutter như sau:

### Bước 1: Cập nhật file cấu hình

Mở file `config/api.deployed.json` và điền URL thật của bạn:
```json
{
  "BACKEND_MODE": "shared",
  "API_BASE_URL": "https://smart-hospital-api.onrender.com",
  "ALLOW_INSECURE_HTTP": "false"
}
```
*(Nếu demo mạng LAN bằng HTTP, đổi `ALLOW_INSECURE_HTTP` thành `"true"` và `API_BASE_URL` thành `"http://192.168.x.x:3000"`).*

### Bước 2: Chạy ứng dụng Flutter kết nối Backend

- **Chạy trên máy ảo / điện thoại Android kết nối cáp:**
  ```bash
  flutter run --dart-define-from-file=config/api.deployed.json
  ```

- **Build file APK nộp cho giảng viên hoặc cài lên máy thực tế:**
  ```bash
  flutter build apk --release --dart-define-from-file=config/api.deployed.json
  ```
  File APK xuất xưởng sẽ nằm tại:
  `build/app/outputs/flutter-apk/app-release.apk`

---

## 4. Kiểm thử toàn bộ hệ thống (End-to-End)

1. **Kiểm tra Backend:**
   ```bash
   cd backend
   npm test
   ```
   *Kết quả:* 68 tests passed (Authentication, Appointment conflict calculation, QR check-in, Payments, Teleconsultations, Vaccinations).

2. **Kiểm tra Frontend Flutter:**
   ```bash
   flutter analyze
   flutter test test/shared_backend_test.dart test/visit_journey_test.dart
   flutter test test/aws_backend_test.dart test/appointment_ui_test.dart
   ```
   *Kết quả:* Tất cả các test suites UI, State, Navigation và Mock API đều vượt qua 100%.
