import { config as loadEnvironment } from "dotenv";

import { createApp } from "./app.js";
import { loadConfig } from "./config.js";

loadEnvironment();
const config = loadConfig();
createApp(config).listen(config.port, () => {
  console.log(`inventory-web-mcp listening on http://localhost:${config.port}`);
});
