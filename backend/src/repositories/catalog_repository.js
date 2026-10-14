export const departments = [
  { id: 'cardiology', name: 'Tim mạch', description: 'Chăm sóc tim và hệ tim mạch.' },
  { id: 'pediatrics', name: 'Nhi khoa', description: 'Chăm sóc sức khỏe trẻ em.' },
  { id: 'dermatology', name: 'Da liễu', description: 'Chăm sóc da, tóc và móng.' },
];

export const doctors = [
  { id: 'dr-linh', name: 'BS. Trần Thảo Linh', departmentId: 'cardiology', department: 'Tim mạch', specialty: 'Bác sĩ tim mạch', experience: '12 năm kinh nghiệm' },
  { id: 'dr-duc', name: 'BS. Nguyễn Đức Minh', departmentId: 'pediatrics', department: 'Nhi khoa', specialty: 'Bác sĩ nhi khoa', experience: '9 năm kinh nghiệm' },
  { id: 'dr-lan', name: 'BS. Phạm Ngọc Lan', departmentId: 'dermatology', department: 'Da liễu', specialty: 'Bác sĩ da liễu', experience: '10 năm kinh nghiệm' },
];
