import { json } from '../utils/http.js';

export const handler = async () => json(200, {
  status: 'ok',
  service: 'smart-hospital-api',
});
