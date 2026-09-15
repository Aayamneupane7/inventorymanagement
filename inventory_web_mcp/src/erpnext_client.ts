export class ErpnextClient {
  constructor(private readonly baseUrl: string, private readonly sid: string) {}

  async list<T>(doctype: string, fields: string[]): Promise<T[]> {
    const pageLength = 500;
    const values: T[] = [];
    for (let start = 0; ; start += pageLength) {
      const query = new URLSearchParams({
        fields: JSON.stringify(fields),
        limit_start: String(start),
        limit_page_length: String(pageLength),
      });
      const response = await this.request<{ data: T[] }>(
        `/api/resource/${encodeURIComponent(doctype)}?${query}`,
      );
      values.push(...response.data);
      if (response.data.length < pageLength) return values;
    }
  }

  async create<T>(doctype: string, value: Record<string, unknown>): Promise<T> {
    const response = await fetch(`${this.baseUrl}/api/resource/${encodeURIComponent(doctype)}`, {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json", Cookie: `sid=${this.sid}` },
      body: JSON.stringify(value),
    });
    if (!response.ok) throw new Error(`ERPNext request failed (${response.status})`);
    return ((await response.json()) as { data: T }).data;
  }

  async get<T>(doctype: string, name: string): Promise<T> {
    const response = await this.request<{ data: T }>(
      `/api/resource/${encodeURIComponent(doctype)}/${encodeURIComponent(name)}`,
    );
    return response.data;
  }

  async call<T>(method: string, params: Record<string, string>): Promise<T> {
    const query = new URLSearchParams(params);
    const response = await this.request<{ message: T }>(`/api/method/${method}?${query}`);
    return response.message;
  }

  async callPost<T>(method: string, body: Record<string, unknown>): Promise<T> {
    const response = await fetch(`${this.baseUrl}/api/method/${method}`, {
      method: 'POST',
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json', Cookie: `sid=${this.sid}`},
      body: JSON.stringify(body),
    });
    if (!response.ok) throw new Error(`ERPNext request failed (${response.status})`);
    return ((await response.json()) as {message: T}).message;
  }

  private async request<T>(path: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      headers: { Accept: "application/json", Cookie: `sid=${this.sid}` },
    });
    if (!response.ok) {
      throw new Error(`ERPNext request failed (${response.status})`);
    }
    return response.json() as Promise<T>;
  }
}

export async function loginToErpnext(
  baseUrl: string,
  username: string,
  password: string,
): Promise<{ sid: string; user: string }> {
  let response: Response;
  try {
    response = await fetch(`${baseUrl}/api/method/login`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ usr: username, pwd: password }),
    });
  } catch {
    throw new Error(`ERPNext is unavailable at ${baseUrl}`);
  }
  if (!response.ok) {
    throw new Error("Invalid ERPNext username or password");
  }
  const cookie = response.headers.get("set-cookie") ?? "";
  const sid = /(?:^|,)\s*sid=([^;]+)/.exec(cookie)?.[1];
  if (!sid) {
    throw new Error("ERPNext did not return a session cookie");
  }
  const client = new ErpnextClient(baseUrl, sid);
  const user = await client.call<string>("frappe.auth.get_logged_user", {});
  return { sid, user };
}
