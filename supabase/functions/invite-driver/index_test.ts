import { allowedOrigin, corsAllowedHeaders, withCors } from './cors.ts'

Deno.test('CORS permite únicamente el origen Web Admin configurado', () => {
  const configured = 'https://admin.example.test,https://stage.example.test'
  const allowedRequest = new Request(
    'https://functions.example.test/invite-driver',
    {
      method: 'OPTIONS',
      headers: { origin: 'https://admin.example.test' },
    },
  )
  const allowed = withCors(
    allowedRequest,
    new Response(null, { status: 204 }),
    configured,
  )
  if (
    allowed.status !== 204 ||
    allowed.headers.get('access-control-allow-origin') !==
      'https://admin.example.test'
  ) {
    throw new Error('La preflight permitida debe devolver el origen exacto.')
  }
  for (const header of ['authorization', 'x-client-info', 'x-retry-count']) {
    if (!corsAllowedHeaders.includes(header)) {
      throw new Error(`Falta permitir el header ${header} del SDK.`)
    }
  }

  const denied = new Request(
    'https://functions.example.test/invite-driver',
    { headers: { origin: 'https://attacker.example.test' } },
  )
  if (allowedOrigin(denied, configured) !== null) {
    throw new Error('Un origen desconocido no debe pasar la allowlist.')
  }

  const desktop = new Request(
    'https://functions.example.test/invite-driver',
  )
  if (allowedOrigin(desktop, configured) !== null) {
    throw new Error('El cliente sin Origin no debe requerir allowlist Web.')
  }
})
