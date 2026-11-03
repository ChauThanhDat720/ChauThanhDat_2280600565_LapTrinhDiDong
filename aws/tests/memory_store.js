import { WriteConflict } from '../src/store.js';
export class MemoryStore {
  items = new Map();
  key(pk, sk) { return JSON.stringify([pk, sk]); }
  async get(pk, sk) { return structuredClone(this.items.get(this.key(pk, sk)) ?? null); }
  async query(pk, prefix = '', index) {
    const pkField = index ? `${index}pk` : 'pk';
    const skField = index ? `${index}sk` : 'sk';
    return structuredClone([...this.items.values()].filter((r) => r[pkField] === pk && r[skField]?.startsWith(prefix))
      .sort((a, b) => a[skField].localeCompare(b[skField])));
  }
  async transact(operations) {
    for (const { put, remove, expected } of operations) {
      const key = put ?? remove;
      const old = this.items.get(this.key(key.pk, key.sk));
      if (expected == null ? !!old : old?.version !== expected) throw new WriteConflict();
    }
    for (const { put, remove } of operations) {
      if (put) this.items.set(this.key(put.pk, put.sk), structuredClone(put));
      else this.items.delete(this.key(remove.pk, remove.sk));
    }
  }
}
