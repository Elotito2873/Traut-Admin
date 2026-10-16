export const corsAllowedHeaders = [
  'authorization',
  'x-client-info',
  'apikey',
  'content-type',
  'x-retry-count',
  'traceparent',
  'tracestate',
  'baggage',
].join(', ')

export function allowedOrigin(
  req: Request,
  configuredOrigins: string,
): string | null {
  const origin = req.headers.get('origin')
  if (!origin) return null
  return configuredOrigins
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean)
      .includes(origin)
    ? origin
    : null
}

export function withCors(
  req: Request,
  result: Response,
  configuredOrigins: string,
): Response {
  const response = new Response(result.body, result)
  response.headers.set('Vary', 'Origin')
  const origin = allowedOrigin(req, configuredOrigins)
  if (origin) {
    response.headers.set('Access-Control-Allow-Origin', origin)
    response.headers.set('Access-Control-Allow-Headers', corsAllowedHeaders)
    response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS')
  }
  return response
}
