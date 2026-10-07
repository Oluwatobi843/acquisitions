import { config as loadDotenv } from 'dotenv';
import { existsSync } from 'node:fs';
import path from 'node:path';

const nodeEnv = process.env.NODE_ENV || 'development';

// Load the environment-specific file first, then fall back to `.env`.
// Both use override:false, so real process environment variables
// (Docker, CI, systemd) always win over files on disk.
const candidates = [`.env.${nodeEnv}`, '.env'];

for (const file of candidates) {
  const resolved = path.resolve(process.cwd(), file);

  if (existsSync(resolved)) {
    loadDotenv({ path: resolved, override: false });
  }
}

export default nodeEnv;
