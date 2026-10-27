// Public hospital catalog. Replace these entries with the hospital's approved catalog.
export const departments = [
  { id: 'cardiology', name: 'Tim mạch', description: 'Khám chuyên khoa tim mạch.' },
  { id: 'pediatrics', name: 'Nhi khoa', description: 'Khám chuyên khoa nhi.' },
  { id: 'dermatology', name: 'Da liễu', description: 'Khám chuyên khoa da liễu.' },
];
export const doctors = [
  { id: 'dr-linh', name: 'BS. Trần Thảo Linh', departmentId: 'cardiology', department: 'Tim mạch', specialty: 'Bác sĩ tim mạch', experience: '12 năm kinh nghiệm' },
  { id: 'dr-duc', name: 'BS. Nguyễn Đức Minh', departmentId: 'pediatrics', department: 'Nhi khoa', specialty: 'Bác sĩ nhi khoa', experience: '9 năm kinh nghiệm' },
  { id: 'dr-lan', name: 'BS. Phạm Ngọc Lan', departmentId: 'dermatology', department: 'Da liễu', specialty: 'Bác sĩ da liễu', experience: '10 năm kinh nghiệm' },
];
