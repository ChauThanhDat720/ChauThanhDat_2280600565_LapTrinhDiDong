export const json = (statusCode, body) => ({
  statusCode,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  },
  body: JSON.stringify(body),
});

export const error = (statusCode, message) => json(statusCode, { message });

export const parseJsonBody = (event) => {
  if (!event.body) return {};
  try {
    return JSON.parse(event.body);
  } catch {
    throw new HttpError(400, 'Nội dung JSON không hợp lệ.');
  }
};

export class HttpError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
  }
}

export const handle = async (action) => {
  try {
    return await action();
  } catch (exception) {
    if (exception instanceof HttpError) {
      return error(exception.statusCode, exception.message);
    }
    // Do not expose internal errors or protected health data in API responses.
    console.error('Unexpected request error', { name: exception?.name });
    return error(500, 'Không thể xử lý yêu cầu.');
  }
};
