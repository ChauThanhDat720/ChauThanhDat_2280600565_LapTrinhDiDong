import { DynamoStore } from './store.js';
import { Attachments } from './attachments.js';
import { HospitalService } from './service.js';
import { createHandler } from './app.js';

const service = new HospitalService(new DynamoStore(process.env.HOSPITAL_TABLE), new Attachments(process.env.ATTACHMENTS_BUCKET));
export const handler = createHandler(service);
