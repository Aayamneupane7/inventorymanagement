import { afterEach, describe, expect, it, vi } from "vitest";

import { ErpnextClient } from "./erpnext_client.js";

describe("ErpnextClient.list", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("retrieves every ERPNext page instead of the default first page", async () => {
    const firstPage = Array.from({ length: 500 }, (_, index) => ({ name: `ITEM-${index}` }));
    const fetch = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ data: firstPage }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ data: [{ name: "ITEM-500" }] }), { status: 200 }));
    vi.stubGlobal("fetch", fetch);

    const client = new ErpnextClient("http://erpnext.test", "sid");
    await expect(client.list("Item", ["name"])).resolves.toHaveLength(501);
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(String(fetch.mock.calls[0][0])).toContain("limit_start=0");
    expect(String(fetch.mock.calls[1][0])).toContain("limit_start=500");
  });
});
