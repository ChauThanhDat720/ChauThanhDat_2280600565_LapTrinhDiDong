import { randomUUID } from 'node:crypto';

const appointments = new Map();

export const listByPatient = (patientId) => [...appointments.values()]
  .filter((item) => item.patientId === patientId)
  .sort((left, right) => left.scheduledAt.localeCompare(right.scheduledAt));

export const create = (patientId, input) => {
  const appointment = {
    id: randomUUID(),
    patientId,
    ...input,
    status: 'pending',
    createdAt: new Date().toISOString(),
  };
  appointments.set(appointment.id, appointment);
  return appointment;
};

// Ownership filtering is deliberate: callers cannot observe another patient's
// appointment as existing, and cannot cancel it.
export const getForPatient = (patientId, appointmentId) => {
  const item = appointments.get(appointmentId);
  return item?.patientId === patientId ? item : undefined;
};

export const cancelForPatient = (patientId, appointmentId) => {
  const item = getForPatient(patientId, appointmentId);
  if (!item) return undefined;
  const updated = { ...item, status: 'cancelled', updatedAt: new Date().toISOString() };
  appointments.set(appointmentId, updated);
  return updated;
};

export const resetAppointments = () => appointments.clear();
