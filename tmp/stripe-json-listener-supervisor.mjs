import fs from 'node:fs';
import https from 'node:https';
import { spawn } from 'node:child_process';

const repoRoot = '/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw';
const configPath = `${repoRoot}/_fpw_private/stripe-config.json`;
const statusPath = `${repoRoot}/tmp/stripe-json-listener.status.json`;
const logPath = `${repoRoot}/tmp/stripe-json-listener.log`;
const forwardTo = 'http://localhost:8500/fpw/api/v1/stripeWebhook.cfc?method=handle';

function redact(text) {
  return String(text)
    .replace(/whsec_[A-Za-z0-9_-]+/g, '[REDACTED_WHSEC]')
    .replace(/sk_(test|live)_[A-Za-z0-9_-]+/g, '[REDACTED_SK]');
}

function writeLog(text) {
  fs.appendFileSync(logPath, redact(text));
}

function writeStatus(status) {
  fs.writeFileSync(statusPath, JSON.stringify(status, null, 2) + '\n');
}

function readConfig() {
  return JSON.parse(fs.readFileSync(configPath, 'utf8'));
}

function getStripeAccount(secretKey) {
  return new Promise((resolve) => {
    const req = https.request({
      method: 'GET',
      hostname: 'api.stripe.com',
      path: '/v1/account',
      headers: { Authorization: `Bearer ${secretKey}` }
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        let body = {};
        try {
          body = JSON.parse(data);
        } catch (_err) {
          body = {};
        }
        resolve({
          ok: res.statusCode >= 200 && res.statusCode < 300,
          account: body.id || null,
          livemode: body.livemode === true
        });
      });
    });
    req.on('error', (err) => resolve({ ok: false, error: err.message }));
    req.end();
  });
}

const config = readConfig();
const secretKey = String(config.FPW_STRIPE_SECRET_KEY || '');
const account = await getStripeAccount(secretKey);
console.log(`FPW Stripe JSON listener starting for account ${account.account || 'unknown'} (${account.livemode ? 'live' : 'test'} mode).`);

writeStatus({
  ready: false,
  supervisorPid: process.pid,
  stripePid: null,
  account: account.account,
  livemode: account.livemode,
  forwardTo
});

const child = spawn('/opt/homebrew/bin/stripe', ['listen', '--forward-to', forwardTo], {
  env: { ...process.env, STRIPE_API_KEY: secretKey },
  stdio: ['ignore', 'pipe', 'pipe']
});

writeStatus({
  ready: false,
  supervisorPid: process.pid,
  stripePid: child.pid,
  account: account.account,
  livemode: account.livemode,
  forwardTo
});

let updatedWebhookSecret = false;

function handleOutput(chunk) {
  const text = chunk.toString();
  writeLog(text);
  const match = text.match(/whsec_[A-Za-z0-9_-]+/);
  if (match && !updatedWebhookSecret) {
    const currentConfig = readConfig();
    currentConfig.FPW_STRIPE_WEBHOOK_SECRET = match[0];
    fs.writeFileSync(configPath, JSON.stringify(currentConfig, null, 2) + '\n');
    updatedWebhookSecret = true;
    console.log('FPW Stripe JSON listener is ready. Webhook secret was updated in the ignored local JSON file.');
    writeStatus({
      ready: true,
      supervisorPid: process.pid,
      stripePid: child.pid,
      account: account.account,
      livemode: account.livemode,
      forwardTo,
      webhookSecretUpdated: true
    });
  }
}

child.stdout.on('data', handleOutput);
child.stderr.on('data', handleOutput);

child.on('exit', (code, signal) => {
  writeStatus({
    ready: false,
    supervisorPid: process.pid,
    stripePid: child.pid,
    account: account.account,
    livemode: account.livemode,
    forwardTo,
    exited: true,
    code,
    signal
  });
  process.exit(code || 0);
});

process.on('SIGTERM', () => child.kill('SIGTERM'));
process.on('SIGINT', () => child.kill('SIGINT'));
