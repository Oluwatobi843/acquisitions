import express from 'express';
import logger from '#config/logger';

const app = express();

app.get('/', (req, res) => {
  logger.info('Hello from Acquisitions!');

  res.status(200).send('Hello from Acquisition!');
});

export default app;
