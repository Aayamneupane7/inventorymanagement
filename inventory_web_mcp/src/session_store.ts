import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";

interface Session {
  sid: string;
  user: string;
}

export class SessionStore {
  private readonly key: Buffer;
  private readonly revoked = new Map<string, number>();

  constructor(secret: string, private readonly ttlSeconds: number) {
    this.key = createHash("sha256").update(secret).digest();
  }

  create(session: Session): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, iv);
    const payload = Buffer.from(JSON.stringify({ ...session, expiresAt: Date.now() + this.ttlSeconds * 1000 }));
    const encrypted = Buffer.concat([cipher.update(payload), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), encrypted]).toString("base64url");
  }

  get(token: string): Session | undefined {
    try {
      this.removeExpiredRevocations();
      if (this.revoked.has(token)) return undefined;
      const encoded = Buffer.from(token, "base64url");
      const decipher = createDecipheriv("aes-256-gcm", this.key, encoded.subarray(0, 12));
      decipher.setAuthTag(encoded.subarray(12, 28));
      const value = JSON.parse(Buffer.concat([decipher.update(encoded.subarray(28)), decipher.final()]).toString()) as Session & { expiresAt: number };
      return value.expiresAt > Date.now() ? { sid: value.sid, user: value.user } : undefined;
    } catch {
      return undefined;
    }
  }

  revoke(token: string): void {
    this.revoked.set(token, Date.now() + this.ttlSeconds * 1000);
    this.removeExpiredRevocations();
  }

  private removeExpiredRevocations(): void {
    const now = Date.now();
    for (const [token, expiresAt] of this.revoked) {
      if (expiresAt <= now) this.revoked.delete(token);
    }
  }
}
