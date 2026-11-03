import { departments } from '../repositories/catalog_repository.js';
import { json } from '../utils/http.js';

export const list = async () => json(200, { items: departments });
