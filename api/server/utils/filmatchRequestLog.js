/**
 * Filmatch operations logging (SAM10 WS-B).
 *
 * Writes ONE structured JSON line to stdout for every chat answer:
 *   question, how long it took, whether it succeeded, and which version answered.
 *
 * stdout is shipped to CloudWatch Logs by the Docker `awslogs` driver, where metric
 * filters (see deploy/aws/cloudformation/filmatch-app.yaml) turn these lines into the
 * Filmatch/App metrics: Requests, AnswersFailed, EmptyAnswers, ResponseTimeMs.
 *
 * Deliberately NOT logged: user id, email, name, IP. Questions are invented test
 * data for this project (see the system card), and are truncated.
 */

const MAX_QUESTION_CHARS = 500;
const version = (process.env.BUILD_COMMIT || 'dev').slice(0, 12);

/** Count visible answer characters from either `text` or agent `content` parts. */
function answerLength(response) {
  if (!response) {
    return 0;
  }
  if (typeof response.text === 'string' && response.text.trim().length > 0) {
    return response.text.trim().length;
  }
  if (Array.isArray(response.content)) {
    return response.content.reduce((sum, part) => {
      const value = typeof part?.text === 'string' ? part.text : part?.text?.value;
      return sum + (typeof value === 'string' ? value.trim().length : 0);
    }, 0);
  }
  return 0;
}

/**
 * @param {object} params
 * @param {import('express').Request} params.req
 * @param {number} params.startedAt - Date.now() when generation started
 * @param {'success'|'failed'|'aborted'} params.outcome
 * @param {object} [params.response] - final response message, on success
 * @param {Error} [params.error]
 */
function logFilmatchChat({ req, startedAt, outcome, response, error }) {
  try {
    const question = typeof req?.body?.text === 'string' ? req.body.text : '';
    const answerChars = answerLength(response);
    const finalOutcome = outcome === 'success' && answerChars === 0 ? 'empty' : outcome;
    const endpointOption = req?.body?.endpointOption ?? {};
    const line = {
      event: 'filmatch_chat',
      ts: new Date().toISOString(),
      outcome: finalOutcome,
      success: finalOutcome === 'success' ? 1 : 0,
      failed: finalOutcome === 'failed' ? 1 : 0,
      empty: finalOutcome === 'empty' ? 1 : 0,
      durationMs: Math.max(0, Date.now() - (startedAt || Date.now())),
      question: question.slice(0, MAX_QUESTION_CHARS),
      questionChars: question.length,
      answerChars,
      endpoint: endpointOption.endpoint ?? req?.body?.endpoint ?? null,
      model: endpointOption.model_parameters?.model ?? req?.body?.model ?? null,
      spec: req?.body?.spec ?? endpointOption.spec ?? null,
      version,
      error: error ? String(error.message || error).slice(0, 300) : undefined,
    };
    process.stdout.write(JSON.stringify(line) + '\n');
  } catch {
    // Logging must never break a chat turn.
  }
}

module.exports = { logFilmatchChat };
