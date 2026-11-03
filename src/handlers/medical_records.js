import * as repository from '../repositories/sqlite_appointment_repository.js';
import { error, handle, json } from '../utils/http.js';

export const handler = async (event) =>
  handle(async () => {
    const method = event.requestContext?.http?.method ?? event.httpMethod;
    const path = event.path || '';
    const id = event.pathParameters?.id;

    if (method !== 'GET') {
      return error(405, 'Phương thức không được hỗ trợ.');
    }

    if (!id) {
      return error(400, 'Thiếu mã hồ sơ bệnh án hoặc lịch khám.');
    }

    const record = await repository.getMedicalRecord(id);
    if (!record) {
      return error(404, 'Không tìm thấy hồ sơ bệnh án hoặc ca khám chưa hoàn tất.');
    }

    const isLabResults =
      event.pathParameters?.action === 'lab-results' ||
      path.endsWith('/lab-results');

    if (isLabResults) {
      const isPediatric = (record.department || '').toLowerCase().includes('nhi');
      const metrics = isPediatric
        ? [
            {
              id: 'M-01',
              name: 'Bạch cầu (WBC)',
              category: 'Huyết học tế bào',
              value: 12.8,
              unit: 'G/L',
              referenceRange: '4.0 - 10.0',
              status: 'high',
              clinicalInterpretation:
                'Bạch cầu tăng nhẹ (Phản ứng viêm/nhiễm khuẩn)',
            },
            {
              id: 'M-02',
              name: 'Hồng cầu (RBC)',
              category: 'Huyết học tế bào',
              value: 4.4,
              unit: 'T/L',
              referenceRange: '3.8 - 5.5',
              status: 'normal',
              clinicalInterpretation: 'Trong giới hạn bình thường',
            },
            {
              id: 'M-03',
              name: 'Huyết sắc tố (Hemoglobin Hb)',
              category: 'Huyết học tế bào',
              value: 110.0,
              unit: 'g/L',
              referenceRange: '115 - 150',
              status: 'low',
              clinicalInterpretation: 'Thiếu máu mức độ nhẹ',
            },
            {
              id: 'M-04',
              name: 'Tiểu cầu (PLT)',
              category: 'Huyết học tế bào',
              value: 285.0,
              unit: 'G/L',
              referenceRange: '150 - 450',
              status: 'normal',
              clinicalInterpretation: 'Bình thường',
            },
            {
              id: 'M-05',
              name: 'Định lượng CRP huyết thanh',
              category: 'Miễn dịch & Sinh hóa',
              value: 18.5,
              unit: 'mg/L',
              referenceRange: '< 5.0',
              status: 'high',
              clinicalInterpretation: 'Phản ứng viêm cấp tính',
            },
          ]
        : [
            {
              id: 'M-01',
              name: 'Glucose máu lúc đói',
              category: 'Sinh hóa máu',
              value: 7.2,
              unit: 'mmol/L',
              referenceRange: '3.9 - 6.4',
              status: 'high',
              clinicalInterpretation:
                'Tăng đường huyết lúc đói nhẹ, theo dõi dung nạp đường',
            },
            {
              id: 'M-02',
              name: 'Men gan ALT (GPT)',
              category: 'Sinh hóa máu',
              value: 65.0,
              unit: 'U/L',
              referenceRange: '< 40.0',
              status: 'high',
              clinicalInterpretation:
                'Tăng men gan nhẹ (nghĩ do chuyển hóa hoặc dùng thuốc)',
            },
            {
              id: 'M-03',
              name: 'Creatinine huyết thanh',
              category: 'Sinh hóa máu',
              value: 76.0,
              unit: 'umol/L',
              referenceRange: '53.0 - 106.0',
              status: 'normal',
              clinicalInterpretation:
                'Chức năng lọc cầu thận tốt (eGFR > 90 mL/min)',
            },
            {
              id: 'M-04',
              name: 'Bạch cầu tổng số (WBC)',
              category: 'Huyết học tế bào',
              value: 6.8,
              unit: 'G/L',
              referenceRange: '4.0 - 10.0',
              status: 'normal',
              clinicalInterpretation:
                'Số lượng bạch cầu trong giới hạn bình thường',
            },
            {
              id: 'M-05',
              name: 'Huyết sắc tố (Hemoglobin Hb)',
              category: 'Huyết học tế bào',
              value: 105.0,
              unit: 'g/L',
              referenceRange: '120.0 - 165.0',
              status: 'low',
              clinicalInterpretation:
                'Thiếu máu đẳng sắc mức độ nhẹ (cần bổ sung vi chất)',
            },
            {
              id: 'M-06',
              name: 'Cholesterol toàn phần',
              category: 'Bilan Lipid máu',
              value: 5.8,
              unit: 'mmol/L',
              referenceRange: '< 5.2',
              status: 'high',
              clinicalInterpretation: 'Rối loạn lipid máu nhẹ',
            },
            {
              id: 'M-07',
              name: 'Acid Uric máu',
              category: 'Sinh hóa máu',
              value: 320.0,
              unit: 'umol/L',
              referenceRange: '200.0 - 420.0',
              status: 'normal',
              clinicalInterpretation: 'Bình thường, nguy cơ Gút thấp',
            },
          ];

      const imagingList = [
        {
          id: 'IMG-01',
          modality: 'ECG',
          title: 'Điện tâm đồ ECG 12 chuyển đạo kỹ thuật số',
          description: 'Đo dẫn truyền điện học và nhịp tim bề mặt',
          findings:
            'Nhịp xoang đều tần số 78 chu kỳ/phút, trục trung gian. Sóng P và đoạn PR bình thường (0.16s). Phức bộ QRS thanh mảnh (0.08s). Không thấy biến đổi ST-T thiếu máu cục bộ cơ tim cấp tính.',
          capturedDate: `${record.examinationDate ? record.examinationDate.slice(0, 10) : 'Hôm nay'} lúc 09:10`,
          performingDoctor: 'BS. CĐHA Đỗ Quốc Bảo',
          svgPathType: 'ecg_strip',
        },
        {
          id: 'IMG-02',
          modality: 'X-Ray',
          title: 'Chụp X-quang Ngực thẳng Tim Phổi Số hóa (CXR)',
          description: 'Đánh giá lồng ngực, bóng tim và nhu mô phổi',
          findings:
            'Chỉ số tim - ngực (CTR) = 0.48 (trong giới hạn bình thường < 0.50). Quai động mạch chủ mềm mại. Không thấy dày dính hay tổn thương đông đặc phế nang 2 bên.',
          capturedDate: `${record.examinationDate ? record.examinationDate.slice(0, 10) : 'Hôm nay'} lúc 09:25`,
          performingDoctor: 'BS. CĐHA Nguyễn Hải Đăng',
          svgPathType: 'chest_xray',
        },
        {
          id: 'IMG-03',
          modality: 'Ultrasound',
          title: 'Siêu âm Tim Doppler màu Chuyên sâu',
          description:
            'Đánh giá cấu trúc buồng tim, chức năng tâm thu và van tim',
          findings:
            'Kích thước các buồng tim bình thường: LVEDd 46mm, LA 32mm. Chức năng tâm thu thất trái bảo tồn tốt, phân suất tống máu EF = 62%. Hở van 2 lá sinh lý 1/4 nhẹ, không tăng áp lực động mạch phổi (PAPs = 24 mmHg).',
          capturedDate: `${record.examinationDate ? record.examinationDate.slice(0, 10) : 'Hôm nay'} lúc 09:40`,
          performingDoctor: 'ThS.BS. Đinh Trọng Hưng',
          svgPathType: 'echocardiogram',
        },
      ];

      return json(200, {
        id: `LAB-${record.recordId || record.appointmentId || id}`,
        appointmentId: record.appointmentId || id,
        patientId: record.patientId,
        patientName: record.patientName,
        doctorName: record.doctorName,
        department: record.department,
        sampleDate: `${record.examinationDate ? record.examinationDate.slice(0, 10) : 'Hôm nay'} 08:45`,
        reportDate: `${record.examinationDate ? record.examinationDate.slice(0, 10) : 'Hôm nay'} 10:15`,
        diagnostician:
          'BS. CKII Nguyễn Hải Đăng (Trưởng khoa Cận lâm sàng & CĐHA)',
        generalConclusion: isPediatric
          ? 'Hội chứng viêm đường hô hấp (WBC & CRP tăng nhẹ). Thiếu máu nhẹ dạng dinh dưỡng.'
          : 'Tăng đường huyết lúc đói & Men gan tăng nhẹ (theo dõi chuyển hóa). Rối loạn lipid máu nhẹ. Chưa ghi nhận bất thường trên X-quang tim phổi và Điện tâm đồ ECG.',
        metrics,
        imagingList,
      });
    }

    const acceptHeader = event.headers?.['accept'] || event.headers?.['Accept'] || '';
    const isHtml = path.endsWith('/view') || acceptHeader.includes('text/html');

    if (isHtml) {
      const html = `<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Xác thực Hồ sơ Bệnh án & Đơn thuốc - Smart Hospital</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: #f0f4f8; margin: 0; padding: 24px; color: #1e293b; }
    .card { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); overflow: hidden; border: 1px solid #e2e8f0; }
    .header { background: #0f172a; color: #ffffff; padding: 24px; text-align: center; }
    .header h1 { margin: 0 0 6px 0; font-size: 20px; letter-spacing: 0.5px; }
    .header p { margin: 0; font-size: 13px; color: #94a3b8; }
    .badge { display: inline-flex; align-items: center; gap: 6px; background: #dcfce7; color: #15803d; padding: 6px 14px; border-radius: 999px; font-size: 13px; font-weight: 600; margin-top: 14px; }
    .content { padding: 24px; }
    .section-title { font-size: 14px; font-weight: 700; color: #0284c7; text-transform: uppercase; margin-top: 20px; margin-bottom: 8px; border-bottom: 2px solid #e0f2fe; padding-bottom: 4px; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; font-size: 14px; }
    .label { color: #64748b; font-size: 12px; margin-bottom: 2px; }
    .value { font-weight: 600; color: #0f172a; }
    .diagnosis-box { background: #eff6ff; border-left: 4px solid #2563eb; padding: 12px; border-radius: 4px; font-size: 14px; margin-top: 8px; }
    .prescription-box { background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 14px; white-space: pre-line; font-family: monospace; font-size: 13.5px; color: #1e293b; line-height: 1.6; }
    .stamp-container { display: flex; justify-content: space-between; align-items: flex-end; margin-top: 28px; padding-top: 16px; border-top: 1px dashed #cbd5e1; }
    .stamp { border: 2px solid #dc2626; color: #dc2626; padding: 8px 16px; border-radius: 6px; font-weight: 800; font-size: 13px; transform: rotate(-3deg); text-align: center; }
    .signature-hash { font-size: 10px; color: #94a3b8; word-break: break-all; margin-top: 18px; font-family: monospace; }
    .print-btn { display: block; width: 100%; text-align: center; background: #0284c7; color: #ffffff; padding: 12px; border-radius: 8px; font-weight: 600; text-decoration: none; margin-top: 20px; cursor: pointer; border: none; font-size: 14px; }
    .print-btn:hover { background: #0369a1; }
    @media print { .print-btn { display: none; } body { background: white; padding: 0; } .card { box-shadow: none; border: none; } }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>BỆNH VIỆN ĐA KHOA QUỐC TẾ SMART HOSPITAL</h1>
      <p>Hệ thống Xác thực Chứng từ Y tế & Đơn thuốc Điện tử</p>
      <div class="badge">✓ CHỨNG TỪ ĐÃ XÁC THỰC HỢP LỆ</div>
    </div>
    <div class="content">
      <div class="section-title">Thông tin Bệnh nhân & Ca khám</div>
      <div class="grid">
        <div><div class="label">Bệnh nhân</div><div class="value">${record.patientName}</div></div>
        <div><div class="label">Mã hồ sơ y tế</div><div class="value">${record.patientId}</div></div>
        <div><div class="label">Mã ca khám</div><div class="value">${record.recordId}</div></div>
        <div><div class="label">Ngày giờ khám</div><div class="value">${record.examinationDate.slice(0, 10)} (${record.time})</div></div>
        <div><div class="label">Bác sĩ phụ trách</div><div class="value">${record.doctorName}</div></div>
        <div><div class="label">Chuyên khoa</div><div class="value">${record.department} - ${record.specialty}</div></div>
      </div>

      <div class="section-title">Kết quả Chẩn đoán Lâm sàng</div>
      <div class="diagnosis-box">
        <strong>Chẩn đoán xác định:</strong> ${record.diagnosis}
      </div>

      <div class="section-title">Chỉ định Dùng thuốc (Đơn thuốc điện tử)</div>
      <div class="prescription-box">${record.prescription}</div>

      ${record.doctorNote ? `<div style="margin-top:10px; font-size:13px; color:#b45309;"><strong>Lời dặn bác sĩ:</strong> <em>${record.doctorNote}</em></div>` : ''}

      <div class="stamp-container">
        <div>
          <div style="font-size: 11px; color: #64748b;">Giấy phép hoạt động: ${record.licenseNumber}</div>
          <div style="font-size: 11px; color: #64748b;">Thời gian cấp: ${record.issuedAt}</div>
        </div>
        <div class="stamp">
          <div>ĐÃ KÝ ĐIỆN TỬ</div>
          <div style="font-size: 11px; margin-top: 2px;">${record.doctorName}</div>
        </div>
      </div>

      <div class="signature-hash">
        Digital Signature (SHA-256): ${record.digitalSignature}
      </div>

      <button class="print-btn" onclick="window.print()">In hoặc Lưu PDF Phiếu khám</button>
    </div>
  </div>
</body>
</html>`;

      return {
        statusCode: 200,
        headers: { 'content-type': 'text/html; charset=utf-8' },
        body: html,
      };
    }

    return json(200, record);
  });
