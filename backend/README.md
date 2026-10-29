# Smart Hospital backend

- `shared/`: backend demo đồng bộ đặt lịch (Node.js 24, SQLite tích hợp sẵn, không cần `npm ci`). Chạy `npm run start:demo`, mở `http://localhost:3000/doctor`. Kiểm thử: `npm run test:shared`. Xem [hướng dẫn demo và VPS](../docs/SHARED_DEMO.md).

- `server.js`, `src/`: máy chủ Node/SQLite demo local. Chạy `npm ci`, `npm test`, `npm start`.
- `aws/`: backend AWS độc lập, dùng AWS SDK v3, DynamoDB và S3; không dùng SQLite.
- `template.yaml`: SAM stack Cognito, API Gateway REST, Lambda, DynamoDB và S3.
- `samconfig.toml`: cấu hình build/deploy mặc định, bật xác nhận change set.

Xem [hướng dẫn AWS](../docs/AWS_SETUP.md) cho phạm vi endpoint, công cụ,
đăng nhập profile, build/deploy, tạo cấu hình Flutter và kiểm tra sau triển khai.
Chưa có tài nguyên AWS hoặc URL API thực tế được tạo trong source này.

```sh
npm ci --prefix aws --ignore-scripts
npm test --prefix aws
sam validate --lint --region ap-southeast-1
sam build
# Chỉ chạy khi đã chọn đúng tài khoản/profile; lệnh tạo tài nguyên AWS:
sam deploy --guided --profile smart-hospital --region ap-southeast-1
```

API AWS không import các handler local có cơ chế giả lập JWT/role, không công
khai endpoint thanh toán giả lập hoặc hồ sơ xét nghiệm mẫu. Chỉ nguồn
`aws/` được đóng gói cho Lambda.
