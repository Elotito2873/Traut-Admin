import { withSupabase } from 'npm:@supabase/server@1.9.2'
import { allowedOrigin, withCors } from './cors.ts'

type InviteBody = {
  email?: unknown
  full_name?: unknown
  license_number?: unknown
}

function response(status: number, payload: Record<string, unknown>) {
  return Response.json(payload, { status })
}

function driverRedirectUrl(): string | null {
  const value = Deno.env.get('DRIVER_INVITE_REDIRECT_URL')?.trim()
  if (!value) return null
  try {
    const url = new URL(value)
    const localDevelopment =
      url.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(url.hostname)
    return url.protocol === 'https:' || localDevelopment ? url.toString() : null
  } catch {
    return null
  }
}

const authenticatedFetch = withSupabase({ auth: 'user', cors: 'disabled' }, async (req, ctx) => {
  if (req.method !== 'POST') return response(405, { message: 'Método no permitido.' })

  const claims = ctx.userClaims as { id?: string; sub?: string } | undefined
  const adminId = claims?.id ?? claims?.sub
  if (!adminId) return response(401, { message: 'Sesión no válida.' })

  const aal = (ctx.jwtClaims as { aal?: string } | undefined)?.aal
  if (aal !== 'aal2') {
    return response(403, {
      message: 'Verifica el segundo factor antes de invitar conductores.',
    })
  }

  const { data: profile, error: profileError } = await ctx.supabase
    .from('profiles')
    .select('role')
    .eq('id', adminId)
    .maybeSingle()

  if (profileError || profile?.role !== 'admin') {
    return response(403, { message: 'Se requieren permisos administrativos.' })
  }

  const redirectTo = driverRedirectUrl()
  if (!redirectTo) {
    return response(500, {
      message:
        'La función no tiene una DRIVER_INVITE_REDIRECT_URL válida configurada.',
    })
  }

  let body: InviteBody
  try {
    const declaredLength = Number(req.headers.get('content-length') ?? '0')
    if (declaredLength > 4096) return response(413, { message: 'Solicitud demasiado grande.' })
    const raw = await req.text()
    if (raw.length > 4096) return response(413, { message: 'Solicitud demasiado grande.' })
    const parsed: unknown = JSON.parse(raw)
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return response(400, { message: 'Solicitud JSON no válida.' })
    }
    body = parsed as InviteBody
  } catch {
    return response(400, { message: 'Solicitud JSON no válida.' })
  }

  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : ''
  const fullName = typeof body.full_name === 'string' ? body.full_name.trim() : ''
  const license =
    typeof body.license_number === 'string' && body.license_number.trim()
      ? body.license_number.trim()
      : null

  if (
    email.length > 254 ||
    fullName.length < 2 || fullName.length > 120 ||
    (license?.length ?? 0) > 80 ||
    !email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  ) {
    return response(422, { message: 'Nombre o correo no válidos.' })
  }

  const { data: existingProfile, error: existingProfileError } = await ctx.supabaseAdmin
    .from('profiles')
    .select('id,role')
    .eq('email', email)
    .maybeSingle()

  if (existingProfileError) {
    return response(500, { message: 'No fue posible validar el correo.' })
  }

  if (existingProfile) {
    const { data: existingDriver, error: driverLookupError } = await ctx.supabaseAdmin
      .from('drivers')
      .select('id')
      .eq('profile_id', existingProfile.id)
      .maybeSingle()

    if (driverLookupError) {
      return response(500, { message: 'No fue posible validar al conductor.' })
    }
    if (existingDriver) {
      return response(409, { message: 'Ese correo ya pertenece a un conductor.' })
    }
    if (existingProfile.role !== 'driver') {
      return response(409, {
        message:
          'Ese correo ya tiene una cuenta con otro rol. Requiere una conversión administrativa explícita.',
      })
    }

    const { data: repairedDriver, error: repairError } = await ctx.supabaseAdmin
      .from('drivers')
      .insert({
        profile_id: existingProfile.id,
        license_number: license,
        status: 'active',
      })
      .select('id')
      .single()

    if (repairError || !repairedDriver) {
      return response(500, { message: 'No fue posible completar al conductor existente.' })
    }

    const { error: repairAuditError } = await ctx.supabaseAdmin.from('audit_logs').insert({
      admin_user_id: adminId,
      action: 'repair_driver_profile',
      entity_type: 'drivers',
      entity_id: repairedDriver.id,
      metadata: { source: 'edge_function' },
    })
    if (repairAuditError) {
      await ctx.supabaseAdmin.from('drivers').delete().eq('id', repairedDriver.id)
      return response(500, {
        message: 'La operación no pudo auditarse y fue revertida.',
      })
    }
    return response(200, {
      ok: true,
      invited: false,
      message: 'Conductor existente completado; no se envió una nueva invitación.',
    })
  }

  const { data: invite, error: inviteError } =
    await ctx.supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName },
      redirectTo,
    })

  if (inviteError || !invite.user) {
    return response(409, {
      message:
        'No fue posible crear la invitación; el correo puede estar registrado o invitado.',
    })
  }

  const userId = invite.user.id
  const { error: profileWriteError } = await ctx.supabaseAdmin
    .from('profiles')
    .upsert(
      { id: userId, email, full_name: fullName, role: 'driver' },
      { onConflict: 'id' },
    )

  if (profileWriteError) {
    await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
    return response(500, { message: 'No fue posible preparar el perfil.' })
  }

  // PostgreSQL genera drivers.id solo en INSERT. profile_id es la identidad
  // estable y nunca se reemplaza el UUID de un conductor existente.
  const { data: driver, error: driverError } = await ctx.supabaseAdmin
    .from('drivers')
    .insert({ profile_id: userId, license_number: license, status: 'active' })
    .select('id')
    .single()

  if (driverError || !driver) {
    await ctx.supabaseAdmin.from('profiles').delete().eq('id', userId)
    await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
    return response(500, { message: 'No fue posible preparar al conductor.' })
  }

  const { error: auditError } = await ctx.supabaseAdmin.from('audit_logs').insert({
    admin_user_id: adminId,
    action: 'invite_driver',
    entity_type: 'drivers',
    entity_id: driver.id,
    metadata: { source: 'edge_function' },
  })

  if (auditError) {
    await ctx.supabaseAdmin.from('drivers').delete().eq('id', driver.id)
    await ctx.supabaseAdmin.from('profiles').delete().eq('id', userId)
    await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
    return response(500, { message: 'La invitación no pudo auditarse y fue revertida.' })
  }

  return response(201, {
    ok: true,
    invited: true,
    message: 'Invitación enviada al conductor.',
  })
})

export default {
  async fetch(req: Request) {
    const configuredOrigins = Deno.env.get('ADMIN_ALLOWED_ORIGINS') ?? ''
    if (req.headers.has('origin') && !allowedOrigin(req, configuredOrigins)) {
      return response(403, { message: 'Origen no autorizado.' })
    }
    // El preflight no tiene JWT y debe resolverse antes del middleware Auth.
    if (req.method === 'OPTIONS') {
      return withCors(
        req,
        new Response(null, { status: 204 }),
        configuredOrigins,
      )
    }
    return withCors(req, await authenticatedFetch(req), configuredOrigins)
  },
}
