import './src/config/env.js';

import { neonConfig } from '@neondatabase/serverless';

// drizzle-kit drives migrations through the same serverless driver, so
// migrations have to be pointed at the Neon Local container in development.
if (process.env.NEON_LOCAL === 'true') {
  neonConfig.fetchEndpoint =
    process.env.NEON_FETCH_ENDPOINT || 'http://neon-local:5432/sql';
  neonConfig.useSecureWebSocket = false;
  neonConfig.poolQueryViaFetch = true;
}

export default {
  schema: './src/models/*.js',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL,
  },
};
