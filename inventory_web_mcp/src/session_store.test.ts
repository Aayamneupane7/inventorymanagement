import { describe, expect, it } from "vitest";

import { SessionStore } from "./session_store.js";

describe("SessionStore", () => {
  it("rejects a token immediately after logout revokes it", () => {
    const sessions = new SessionStore("a-unique-session-secret-that-is-long-enough", 3600);
    const token = sessions.create({ sid: "erpnext-session", user: "Administrator" });

    expect(sessions.get(token)?.user).toBe("Administrator");
    sessions.revoke(token);
    expect(sessions.get(token)).toBeUndefined();
  });
});
