import { doctors } from '../repositories/catalog_repository.js';
import { error, json } from '../utils/http.js';

export const handler = async (event) => {
  const id = event.pathParameters?.id;
  if (!id) return json(200, { items: doctors });
  const doctor = doctors.find((item) => item.id === id);
  return doctor ? json(200, doctor) : error(404, 'Không tìm thấy bác sĩ.');
};
