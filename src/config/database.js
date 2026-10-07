import './env.js';

import { neon, neonConfig } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';

const { DATABASE_URL, NEON_LOCAL, NEON_FETCH_ENDPOINT } = process.env;

if (!DATABASE_URL) {
  throw new Error(
    'DATABASE_URL is not set. Provide it via .env.development, .env.production or the process environment.'
  );
}

// Neon Local is a Docker proxy in front of a Neon cloud branch. Its HTTP
// endpoint is served by the container itself, not by neon.tech, so the
// serverless driver has to be redirected when running against it.
if (NEON_LOCAL === 'true') {
  neonConfig.fetchEndpoint =
    NEON_FETCH_ENDPOINT || 'http://neon-local:5432/sql';
  neonConfig.useSecureWebSocket = false;
  neonConfig.poolQueryViaFetch = true;
}

const sql = neon(DATABASE_URL);

const db = drizzle(sql);

export { db, sql };
