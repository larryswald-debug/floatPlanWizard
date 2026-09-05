// Execute this function through MCP Playwright browser_evaluate on localhost:8500.
// Every run owns its opaque fixture key; no user-supplied recipient or user ID.
async () => {
  const base = '/fpw/tests/inactive-member-recovery-sender-command.cfm?confirm=RUN_RECOVERY_SENDER_COMMAND';
  const results = [];
  for (const action of ['prepare', 'prepareRetry']) {
    const prepared = await (await fetch(base + '&action=' + action)).json();
    if (!prepared.OK) throw new Error('Fixture preparation failed');
    const key = prepared.RUNKEY;
    let cleanup;
    try {
      // Distinct URLs prevent browser coalescing of otherwise identical GETs.
      const runs = await Promise.all([1, 2].map(async worker => {
        const response = await fetch(base + '&action=run&runKey=' + key + '&worker=' + worker);
        if (response.status !== 200) throw new Error('Concurrent request failed');
        return response.json();
      }));
      const state = await (await fetch(base + '&action=inspect&runKey=' + key)).json();
      const expectedAttempts = action === 'prepareRetry' ? 2 : 1;
      if (runs.reduce((sum, run) => sum + run.sent, 0) !== 1 || state.STATE !== 'SENT'
        || state.COUNTS.SUBMITTED !== 1 || state.COUNTS.LEDGER !== 1
        || state.ATTEMPTCOUNT !== expectedAttempts || state.COUNTS.ATTEMPTED !== expectedAttempts) {
        throw new Error('Concurrent claim/retry did not submit exactly once');
      }
      results.push({ action, runs, state });
    } finally {
      cleanup = await (await fetch(base + '&action=cleanup&runKey=' + key)).json();
      if (!cleanup.OK || cleanup.REMAINING.USERS !== 0 || cleanup.REMAINING.EVENTS !== 0
        || cleanup.REMAINING.LEDGER !== 0) throw new Error('Fixture cleanup failed');
      if (results.length) results[results.length - 1].cleanup = cleanup;
    }
  }
  return results;
};
