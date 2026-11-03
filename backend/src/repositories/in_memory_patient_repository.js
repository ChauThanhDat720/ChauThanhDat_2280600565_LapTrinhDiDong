const patients = new Map();
let failure;

export const getPatient = (patientId) => { if (failure) throw failure; return patients.get(patientId); };

export const putPatient = (patientId, profile) => {
  if (failure) throw failure;
  const current = patients.get(patientId) ?? {};
  const next = { ...current, ...profile, cognitoUserId: patientId, updatedAt: new Date().toISOString() };
  patients.set(patientId, next);
  return next;
};

export const resetPatients = () => { patients.clear(); failure = undefined; };
export const failPatientStore = () => { failure = new Error('Mock DynamoDB failure'); };
