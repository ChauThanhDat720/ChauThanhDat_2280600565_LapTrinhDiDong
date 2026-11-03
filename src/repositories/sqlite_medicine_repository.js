import * as db from '../database/db.js';

const toDomain = (row) => {
  if (!row) return undefined;
  return {
    id: row.id,
    name: row.name,
    brandNames: row.brand_names,
    activeIngredient: row.active_ingredient,
    category: row.category,
    dosageForm: row.dosage_form,
    indications: row.indications,
    dosageInstructions: row.dosage_instructions,
    sideEffects: row.side_effects,
    contraindications: row.contraindications,
    precautions: row.precautions || undefined,
    createdAt: row.created_at,
  };
};

export const listMedicines = async ({ search = '', category = '' } = {}) => {
  let sql = 'SELECT * FROM medicines WHERE 1=1';
  const params = [];

  if (category && category.trim() && category !== 'Tất cả') {
    sql += ' AND category = ?';
    params.push(category.trim());
  }

  if (search && search.trim()) {
    const s = `%${search.trim().toLowerCase()}%`;
    sql += ' AND (LOWER(name) LIKE ? OR LOWER(brand_names) LIKE ? OR LOWER(active_ingredient) LIKE ? OR LOWER(indications) LIKE ?)';
    params.push(s, s, s, s);
  }

  sql += ' ORDER BY name ASC';
  const rows = await db.all(sql, params);
  return rows.map(toDomain);
};

export const getMedicineById = async (id) => {
  const row = await db.get('SELECT * FROM medicines WHERE id = ?', [id]);
  return toDomain(row);
};

export const getCategories = async () => {
  const rows = await db.all('SELECT DISTINCT category FROM medicines ORDER BY category ASC');
  return rows.map((r) => r.category);
};

export const lookupByName = async (rawName) => {
  if (!rawName || !rawName.trim()) return undefined;

  // Extract core word tokens, e.g. "Panadol 500mg" -> "Panadol"
  const cleaned = rawName.trim().toLowerCase();
  const tokens = cleaned.split(/[\s,;xX\d\-\(\)]+/).filter((t) => t.length >= 3);

  // 1. Exact match on name
  let row = await db.get('SELECT * FROM medicines WHERE LOWER(name) = ?', [cleaned]);
  if (row) return toDomain(row);

  // 2. Exact match in brand_names
  row = await db.get('SELECT * FROM medicines WHERE LOWER(brand_names) LIKE ?', [`%${cleaned}%`]);
  if (row) return toDomain(row);

  // 3. Token-based matching
  for (const token of tokens) {
    row = await db.get(
      'SELECT * FROM medicines WHERE LOWER(name) LIKE ? OR LOWER(brand_names) LIKE ? OR LOWER(active_ingredient) LIKE ? LIMIT 1',
      [`%${token}%`, `%${token}%`, `%${token}%`],
    );
    if (row) return toDomain(row);
  }

  return undefined;
};
