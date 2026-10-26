import * as repository from '../repositories/sqlite_medicine_repository.js';
import { error, handle, json } from '../utils/http.js';

export const handler = async (event) =>
  handle(async () => {
    const method = event.requestContext?.http?.method ?? event.httpMethod;
    const path = event.path || '';
    const id = event.pathParameters?.id;
    const query = event.queryStringParameters || {};

    if (method !== 'GET') {
      return error(405, 'Phương thức không được hỗ trợ.');
    }

    // 1. GET /medicines/categories
    if (path.endsWith('/categories')) {
      const categories = await repository.getCategories();
      return json(200, { items: categories });
    }

    // 2. GET /medicines/lookup?name=...
    if (path.endsWith('/lookup') || query.lookup) {
      const name = query.name || query.lookup || '';
      const found = await repository.lookupByName(name);
      return found
        ? json(200, found)
        : error(404, `Không tìm thấy thông tin dược phẩm cho từ khóa "${name}".`);
    }

    // 3. GET /medicines/:id
    if (id && id !== 'categories' && id !== 'lookup') {
      const medicine = await repository.getMedicineById(id);
      return medicine
        ? json(200, medicine)
        : error(404, `Không tìm thấy thuốc với mã ${id}.`);
    }

    // 4. GET /medicines?search=...&category=...
    const search = query.search || query.q || '';
    const category = query.category || '';
    const items = await repository.listMedicines({ search, category });
    return json(200, { items });
  });
