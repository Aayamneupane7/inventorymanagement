export interface Config {
  erpnextUrl: string;
  port: number;
  sessionSecret: string;
  sessionTtlSeconds: number;
}

export function loadConfig(env = process.env): Config {
  const erpnextUrl = env.ERPNEXT_URL?.trim().replace(/\/$/, "");
  if (!erpnextUrl) {
    throw new Error("ERPNEXT_URL is required");
  }
  const sessionSecret = env.SESSION_SECRET;
  if (!sessionSecret || sessionSecret.length < 32 || sessionSecret.includes("replace-this")) {
    throw new Error("SESSION_SECRET must be a unique value of at least 32 characters");
  }

  return {
    erpnextUrl,
    port: Number(env.PORT ?? "3101"),
    sessionSecret,
    sessionTtlSeconds: Number(env.SESSION_TTL_SECONDS ?? "28800"),
  };
}
