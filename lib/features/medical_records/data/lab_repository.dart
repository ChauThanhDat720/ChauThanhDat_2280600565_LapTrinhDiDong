import '../../../core/network/api_client.dart';
import '../../appointments/domain/appointment.dart';
import '../domain/lab_result.dart';

abstract interface class LabRepository {
  Future<LabReport?> getLabReportForAppointment(String appointmentId);
  Future<LabReport> generateLabReportForAppointment(Appointment appointment);
}

class LocalLabRepository implements LabRepository {
  const LocalLabRepository();

  static final Map<String, LabReport> _memoryCache = {};

  @override
  Future<LabReport?> getLabReportForAppointment(String appointmentId) async {
    if (_memoryCache.containsKey(appointmentId)) {
      return _memoryCache[appointmentId];
    }
    // If not found in cache, check if appointment exists in AppointmentStore
    final apt = AppointmentStore.instance.appointments
        .where((a) => a.id == appointmentId)
        .firstOrNull;

    if (apt != null) {
      final report = _buildDefaultReport(apt);
      _memoryCache[appointmentId] = report;
      return report;
    }

    // Fallback default sample report
    final defaultApt = Appointment(
      id: appointmentId,
      patientId: 'patient-demo',
      patientName: 'Bệnh nhân',
      doctorId: 'dr-linh',
      doctorName: 'BS. Trần Thảo Linh',
      specialty: 'Tim mạch',
      department: 'Tim mạch',
      date: DateTime.now(),
      time: '08:30',
      reason: 'Khám định kỳ',
      status: AppointmentStatus.completed,
    );
    final report = _buildDefaultReport(defaultApt);
    _memoryCache[appointmentId] = report;
    return report;
  }

  @override
  Future<LabReport> generateLabReportForAppointment(Appointment appointment) async {
    final report = _buildDefaultReport(appointment);
    _memoryCache[appointment.id] = report;
    return report;
  }

  static LabReport _buildDefaultReport(Appointment apt) {
    final dept = apt.department.toLowerCase();

    // 1. Metrics list tailored to clinical context
    final List<LabTestMetric> metrics;
    final List<ImagingItem> images;
    final String conclusion;

    if (dept.contains('nhi')) {
      metrics = const [
        LabTestMetric(
          id: 'M-01',
          name: 'Bạch cầu (WBC)',
          category: 'Huyết học tế bào',
          value: 12.8,
          unit: 'G/L',
          referenceRange: '4.0 - 10.0',
          status: LabMetricStatus.high,
          clinicalInterpretation: 'Bạch cầu tăng nhẹ (Phản ứng viêm/nhiễm khuẩn)',
        ),
        LabTestMetric(
          id: 'M-02',
          name: 'Hồng cầu (RBC)',
          category: 'Huyết học tế bào',
          value: 4.4,
          unit: 'T/L',
          referenceRange: '3.8 - 5.5',
          status: LabMetricStatus.normal,
          clinicalInterpretation: 'Trong giới hạn bình thường',
        ),
        LabTestMetric(
          id: 'M-03',
          name: 'Huyết sắc tố (Hemoglobin Hb)',
          category: 'Huyết học tế bào',
          value: 110.0,
          unit: 'g/L',
          referenceRange: '115 - 150',
          status: LabMetricStatus.low,
          clinicalInterpretation: 'Thiếu máu mức độ nhẹ',
        ),
        LabTestMetric(
          id: 'M-04',
          name: 'Tiểu cầu (PLT)',
          category: 'Huyết học tế bào',
          value: 285.0,
          unit: 'G/L',
          referenceRange: '150 - 450',
          status: LabMetricStatus.normal,
          clinicalInterpretation: 'Bình thường',
        ),
        LabTestMetric(
          id: 'M-05',
          name: 'Định lượng CRP huyết thanh',
          category: 'Miễn dịch & Sinh hóa',
          value: 18.5,
          unit: 'mg/L',
          referenceRange: '< 5.0',
          status: LabMetricStatus.high,
          clinicalInterpretation: 'Phản ứng viêm cấp tính',
        ),
      ];

      images = [
        ImagingItem(
          id: 'IMG-01',
          modality: 'X-Ray',
          title: 'Chụp X-quang Ngực thẳng Nhi khoa',
          description: 'Khảo sát nhu mô phổi và bóng tim ở trẻ em',
          findings: 'Phế trường hai bên sáng đều, rốn phổi đậm nhẹ dạng viêm phế quản, không thấy nốt mờ thâm nhiễm hay tràn dịch màng phổi.',
          capturedDate: '${apt.dateLabel} lúc 09:15',
          performingDoctor: 'BS. CĐHA Hoàng Minh Quân',
          svgPathType: 'chest_xray',
        ),
        ImagingItem(
          id: 'IMG-02',
          modality: 'Ultrasound',
          title: 'Siêu âm Ổ bụng Tổng quát',
          description: 'Khảo sát gan, lách, tụy, thận, bàng quang và hạch mạc treo',
          findings: 'Các tạng đặc trong ổ bụng cấu trúc âm đồng nhất, kích thước bình thường. Không thấy hạch mạc treo phì đại, không có dịch tự do.',
          capturedDate: '${apt.dateLabel} lúc 09:30',
          performingDoctor: 'BS. CĐHA Lê Thu Hà',
          svgPathType: 'echocardiogram',
        ),
      ];

      conclusion = 'Hội chứng viêm đường hô hấp (WBC & CRP tăng nhẹ). Thiếu máu nhẹ dạng dinh dưỡng. X-quang ghi nhận hình ảnh dày phế quản.';
    } else {
      // Cardiology, General Medicine, Dermatology, etc.
      metrics = const [
        LabTestMetric(
          id: 'M-01',
          name: 'Glucose máu lúc đói',
          category: 'Sinh hóa máu',
          value: 7.2,
          unit: 'mmol/L',
          referenceRange: '3.9 - 6.4',
          status: LabMetricStatus.high,
          clinicalInterpretation: 'Tăng đường huyết lúc đói nhẹ, theo dõi dung nạp đường',
        ),
        LabTestMetric(
          id: 'M-02',
          name: 'Men gan ALT (GPT)',
          category: 'Sinh hóa máu',
          value: 65.0,
          unit: 'U/L',
          referenceRange: '< 40.0',
          status: LabMetricStatus.high,
          clinicalInterpretation: 'Tăng men gan nhẹ (nghĩ do chuyển hóa hoặc dùng thuốc)',
        ),
        LabTestMetric(
          id: 'M-03',
          name: 'Creatinine huyết thanh',
          category: 'Sinh hóa máu',
          value: 76.0,
          unit: 'umol/L',
          referenceRange: '53.0 - 106.0',
          status: LabMetricStatus.normal,
          clinicalInterpretation: 'Chức năng lọc cầu thận tốt (eGFR > 90 mL/min)',
        ),
        LabTestMetric(
          id: 'M-04',
          name: 'Bạch cầu tổng số (WBC)',
          category: 'Huyết học tế bào',
          value: 6.8,
          unit: 'G/L',
          referenceRange: '4.0 - 10.0',
          status: LabMetricStatus.normal,
          clinicalInterpretation: 'Số lượng bạch cầu trong giới hạn bình thường',
        ),
        LabTestMetric(
          id: 'M-05',
          name: 'Huyết sắc tố (Hemoglobin Hb)',
          category: 'Huyết học tế bào',
          value: 105.0,
          unit: 'g/L',
          referenceRange: '120.0 - 165.0',
          status: LabMetricStatus.low,
          clinicalInterpretation: 'Thiếu máu đẳng sắc mức độ nhẹ (cần bổ sung vi chất)',
        ),
        LabTestMetric(
          id: 'M-06',
          name: 'Cholesterol toàn phần',
          category: 'Bilan Lipid máu',
          value: 5.8,
          unit: 'mmol/L',
          referenceRange: '< 5.2',
          status: LabMetricStatus.high,
          clinicalInterpretation: 'Rối loạn lipid máu nhẹ',
        ),
        LabTestMetric(
          id: 'M-07',
          name: 'Acid Uric máu',
          category: 'Sinh hóa máu',
          value: 320.0,
          unit: 'umol/L',
          referenceRange: '200.0 - 420.0',
          status: LabMetricStatus.normal,
          clinicalInterpretation: 'Bình thường, nguy cơ Gút thấp',
        ),
      ];

      images = [
        ImagingItem(
          id: 'IMG-01',
          modality: 'ECG',
          title: 'Điện tâm đồ ECG 12 chuyển đạo kỹ thuật số',
          description: 'Đo dẫn truyền điện học và nhịp tim bề mặt',
          findings: 'Nhịp xoang đều tần số 78 chu kỳ/phút, trục trung gian. Sóng P và đoạn PR bình thường (0.16s). Phức bộ QRS thanh mảnh (0.08s). Không thấy biến đổi ST-T thiếu máu cục bộ cơ tim cấp tính.',
          capturedDate: '${apt.dateLabel} lúc 09:10',
          performingDoctor: 'BS. CĐHA Đỗ Quốc Bảo',
          svgPathType: 'ecg_strip',
        ),
        ImagingItem(
          id: 'IMG-02',
          modality: 'X-Ray',
          title: 'Chụp X-quang Ngực thẳng Tim Phổi Số hóa (CXR)',
          description: 'Đánh giá lồng ngực, bóng tim và nhu mô phổi',
          findings: 'Chỉ số tim - ngực (CTR) = 0.48 (trong giới hạn bình thường < 0.50). Quai động mạch chủ mềm mại. Không thấy dày dính hay tổn thương đông đặc phế nang 2 bên.',
          capturedDate: '${apt.dateLabel} lúc 09:25',
          performingDoctor: 'BS. CĐHA Nguyễn Hải Đăng',
          svgPathType: 'chest_xray',
        ),
        ImagingItem(
          id: 'IMG-03',
          modality: 'Ultrasound',
          title: 'Siêu âm Tim Doppler màu Chuyên sâu',
          description: 'Đánh giá cấu trúc buồng tim, chức năng tâm thu và van tim',
          findings: 'Kích thước các buồng tim bình thường: LVEDd 46mm, LA 32mm. Chức năng tâm thu thất trái bảo tồn tốt, phân suất tống máu EF = 62%. Hở van 2 lá sinh lý 1/4 nhẹ, không tăng áp lực động mạch phổi (PAPs = 24 mmHg).',
          capturedDate: '${apt.dateLabel} lúc 09:40',
          performingDoctor: 'ThS.BS. Đinh Trọng Hưng',
          svgPathType: 'echocardiogram',
        ),
      ];

      conclusion = 'Tăng đường huyết lúc đói & Men gan tăng nhẹ (theo dõi chuyển hóa). Rối loạn lipid máu nhẹ. Chưa ghi nhận bất thường trên X-quang tim phổi và Điện tâm đồ ECG.';
    }

    return LabReport(
      id: 'LAB-${apt.id}',
      appointmentId: apt.id,
      patientId: apt.patientId,
      patientName: apt.patientName,
      doctorName: apt.doctorName,
      department: apt.department,
      sampleDate: '${apt.dateLabel} 08:45',
      reportDate: '${apt.dateLabel} 10:15',
      diagnostician: 'BS. CKII Nguyễn Hải Đăng (Trưởng khoa Cận lâm sàng & CĐHA)',
      generalConclusion: conclusion,
      metrics: metrics,
      imagingList: images,
    );
  }
}

class RemoteLabRepository implements LabRepository {
  const RemoteLabRepository([this._client]);

  final ApiClient? _client;

  @override
  Future<LabReport?> getLabReportForAppointment(String appointmentId) async {
    try {
      if (_client != null) {
        final res = await _client.get('/medical-records/$appointmentId/lab-results');
        if (res is Map<String, dynamic>) {
          return LabReport.fromJson(res);
        }
      }
    } catch (_) {
      // Fallback to local calculation if network unavailable
    }
    const local = LocalLabRepository();
    return local.getLabReportForAppointment(appointmentId);
  }

  @override
  Future<LabReport> generateLabReportForAppointment(Appointment appointment) async {
    const local = LocalLabRepository();
    return local.generateLabReportForAppointment(appointment);
  }
}
