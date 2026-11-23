// One small wrapper around fetch. If the server replies with an error
// (including messages raised by our SQL triggers/procedures), it is
// thrown as an Error so the UI can display it.
export async function api(url, { method = 'GET', body } = {}) {
  const res = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: method === 'GET' ? undefined : JSON.stringify(body || {}),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}
